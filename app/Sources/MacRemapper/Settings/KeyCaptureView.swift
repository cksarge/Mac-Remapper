import SwiftUI
import MacRemapperCore
import CoreGraphics

/// A short-lived, standalone CGEventTap used only while the user is actively
/// recording a key in the UI. Separate from the app's main `EventTapManager`
/// so capture mode works independent of whether remapping is currently enabled,
/// and always swallows the captured event so it never leaks to the focused field.
private final class KeyCaptureSession {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    var onCapture: ((KeyCombo) -> Void)?
    var onCancel: (() -> Void)?
    /// Called when the user presses a key that can't be recorded (currently only Caps Lock).
    var onUnsupportedKey: (() -> Void)?
    /// Reports the modifiers currently held, for a live preview while recording.
    var onModifiersChanged: ((ModifierFlags) -> Void)?

    /// A non-modifier key (plus the modifiers held with it) that's down, awaiting release.
    private var pendingCombo: KeyCombo?
    /// A modifier pressed on its own; recorded by itself only if released with nothing else pressed.
    private var soloModifierKeyCode: UInt16?

    private static let capsLockKeyCode: UInt16 = 57

    private static let eventMask: CGEventMask =
        (1 << CGEventType.keyDown.rawValue) |
        (1 << CGEventType.keyUp.rawValue) |
        (1 << CGEventType.flagsChanged.rawValue)

    func start() {
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: Self.eventMask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let session = Unmanaged<KeyCaptureSession>.fromOpaque(refcon).takeUnretainedValue()
                return session.handle(event: event, type: type)
            },
            userInfo: refcon
        ) else {
            return
        }
        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    /// Records on release rather than press, so a combo like Cmd+C isn't cut short at "Cmd".
    private func handle(event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
        let keyCode = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
        let modifiers = ModifierFlags(cgEventFlags: event.flags)

        switch type {
        case .keyDown:
            if keyCode == 53 && modifiers.isEmpty { // Escape cancels capture without recording it
                onCancel?()
                return nil
            }
            if pendingCombo == nil { // ignore key auto-repeat
                pendingCombo = KeyCombo(keyCode: keyCode, modifiers: modifiers)
            }
            soloModifierKeyCode = nil
            return nil

        case .keyUp:
            guard let pending = pendingCombo else {
                // Release of a key pressed before recording began: let it through.
                return Unmanaged.passUnretained(event)
            }
            if pending.keyCode == keyCode {
                onCapture?(pending)
            }
            return nil

        case .flagsChanged where KeyCodeTable.isModifierKey(keyCode):
            onModifiersChanged?(modifiers)
            guard let mask = KeyCodeTable.modifierMask(for: keyCode) else { return nil }

            // macOS toggles Caps Lock in the keyboard driver before any event tap sees it,
            // so it can't be reliably remapped here; System Settings' Modifier Keys can.
            if keyCode == Self.capsLockKeyCode {
                onUnsupportedKey?()
                return Unmanaged.passUnretained(event)
            }

            if event.flags.contains(mask) {
                // A lone modifier is a candidate only if nothing else is held with it.
                let others = modifiers.subtracting(ModifierFlags(cgEventFlags: mask))
                soloModifierKeyCode = (pendingCombo == nil && others.isEmpty) ? keyCode : nil
            } else if soloModifierKeyCode == keyCode && pendingCombo == nil {
                onCapture?(KeyCombo(keyCode: keyCode, modifiers: []))
            }
            return nil

        default:
            return Unmanaged.passUnretained(event)
        }
    }
}

/// A button that captures the next physical keystroke and reports it as a `KeyCombo`.
struct KeyCaptureView: View {
    @Binding var combo: KeyCombo?
    var placeholder: String = "Click to set key"

    @State private var isCapturing = false
    @State private var session: KeyCaptureSession?
    @State private var heldModifiers: ModifierFlags = []
    @State private var pressedUnsupportedKey = false

    var body: some View {
        Button {
            if isCapturing {
                stopCapture()
            } else {
                startCapture()
            }
        } label: {
            Text(captureLabel)
                .frame(minWidth: 160)
                .foregroundStyle(isCapturing ? .secondary : .primary)
        }
        .buttonStyle(.bordered)
        .onDisappear { stopCapture() }
    }

    private func startCapture() {
        let newSession = KeyCaptureSession()
        newSession.onCapture = { captured in
            combo = captured
            stopCapture()
        }
        newSession.onCancel = {
            stopCapture()
        }
        newSession.onModifiersChanged = { heldModifiers = $0 }
        newSession.onUnsupportedKey = { pressedUnsupportedKey = true }
        session = newSession
        isCapturing = true
        newSession.start()
    }

    private func stopCapture() {
        session?.stop()
        session = nil
        isCapturing = false
        heldModifiers = []
        pressedUnsupportedKey = false
    }

    private var captureLabel: String {
        guard isCapturing else { return combo?.displayString ?? placeholder }
        if !heldModifiers.isEmpty { return "\(heldModifiers.displaySymbols)…" }
        return pressedUnsupportedKey ? "Caps Lock isn't supported — press another key" : "Press a key… (Esc to cancel)"
    }
}
