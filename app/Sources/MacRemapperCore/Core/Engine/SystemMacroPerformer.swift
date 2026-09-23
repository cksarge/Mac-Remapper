import Foundation
import CoreGraphics

/// Posts real keyboard/mouse events and runs shortcuts on behalf of running macros.
///
/// Every keyboard event it creates is tagged with `syntheticEventMarker`, so the app's own
/// event tap lets them straight through: a macro's output never triggers other mappings,
/// and a macro that types its own trigger key can't restart itself.
final class SystemMacroPerformer: MacroPerformer {
    static let syntheticEventMarker: Int64 = 0x4D52_4D50 // "MRMP"

    /// Gap between typed characters; some apps drop keystrokes delivered faster than this.
    private static let typingIntervalMs = 4

    static func isSynthetic(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == syntheticEventMarker
    }

    func press(_ combo: KeyCombo) {
        let source = CGEventSource(stateID: .hidSystemState)
        for keyDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(combo.keyCode), keyDown: keyDown) else { return }
            // Explicit flags, so modifiers still physically held from the trigger don't leak in.
            event.flags = combo.cgEventFlags
            post(event)
        }
    }

    func type(_ text: String, token: MacroRunToken) {
        let source = CGEventSource(stateID: .hidSystemState)
        for character in text {
            if token.isCancelled { return }
            let utf16 = Array(String(character).utf16)
            for keyDown in [true, false] {
                guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: keyDown) else { return }
                event.flags = []
                event.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
                post(event)
            }
            Thread.sleep(forTimeInterval: Double(Self.typingIntervalMs) / 1000)
        }
    }

    func click(_ click: MouseClick) {
        let originalLocation = CGEvent(source: nil)?.location ?? .zero
        let target = click.usesFixedPosition ? CGPoint(x: click.x, y: click.y) : originalLocation
        if click.usesFixedPosition {
            postMouse(.mouseMoved, at: target, button: .left)
        }

        let (downType, upType, cgButton) = Self.eventTypes(for: click.button)
        for clickNumber in 1...max(1, min(click.clickCount, 2)) {
            for type in [downType, upType] {
                postMouse(type, at: target, button: cgButton, clickState: clickNumber)
            }
        }

        if click.usesFixedPosition && click.returnsCursor {
            postMouse(.mouseMoved, at: originalLocation, button: .left)
        }
    }

    func runShortcut(_ shortcut: ShortcutRun, token: MacroRunToken) {
        let name = shortcut.name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", name]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return
        }
        guard shortcut.waitsUntilFinished else { return }
        while process.isRunning {
            if token.isCancelled {
                process.terminate()
                return
            }
            Thread.sleep(forTimeInterval: 0.02)
        }
    }

    func sleep(milliseconds: Int, token: MacroRunToken) {
        // Sleep in short slices so a stop takes effect promptly even during long delays.
        let deadline = Date().addingTimeInterval(Double(milliseconds) / 1000)
        while !token.isCancelled {
            let remaining = deadline.timeIntervalSinceNow
            if remaining <= 0 { return }
            Thread.sleep(forTimeInterval: min(remaining, 0.01))
        }
    }

    func runConcurrently(_ work: @escaping () -> Void) {
        // A dedicated thread per run: macros block on sleeps, which would starve a shared queue.
        Thread.detachNewThread(work)
    }

    // MARK: - Posting

    private func post(_ event: CGEvent) {
        event.setIntegerValueField(.eventSourceUserData, value: Self.syntheticEventMarker)
        event.post(tap: .cgSessionEventTap)
    }

    private func postMouse(_ type: CGEventType, at point: CGPoint, button: CGMouseButton, clickState: Int = 1) {
        guard let event = CGEvent(mouseEventSource: CGEventSource(stateID: .hidSystemState),
                                  mouseType: type, mouseCursorPosition: point, mouseButton: button) else { return }
        event.setIntegerValueField(.mouseEventClickState, value: Int64(clickState))
        event.setIntegerValueField(.eventSourceUserData, value: Self.syntheticEventMarker)
        event.post(tap: .cghidEventTap)
    }

    private static func eventTypes(for button: MouseButton) -> (down: CGEventType, up: CGEventType, button: CGMouseButton) {
        switch button {
        case .left: return (.leftMouseDown, .leftMouseUp, .left)
        case .right: return (.rightMouseDown, .rightMouseUp, .right)
        case .middle: return (.otherMouseDown, .otherMouseUp, .center)
        }
    }
}
