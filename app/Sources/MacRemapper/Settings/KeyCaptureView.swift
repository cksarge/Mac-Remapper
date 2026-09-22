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

    private static let eventMask: CGEventMask =
        (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

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

    private func handle(event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
        let keyCode = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))

        if type == .keyDown {
            if keyCode == 53 { // Escape cancels capture without recording it
                onCancel?()
                return nil
            }
            let combo = KeyCombo(keyCode: keyCode, modifiers: ModifierFlags(cgEventFlags: event.flags))
            onCapture?(combo)
            return nil
        }

        if type == .flagsChanged, KeyCodeTable.isModifierKey(keyCode) {
            // Only fire on the press half of a modifier key's flagsChanged pair.
            if let mask = KeyCodeTable.modifierMask(for: keyCode), event.flags.contains(mask) {
                onCapture?(KeyCombo(keyCode: keyCode, modifiers: []))
            }
            return nil
        }

        return Unmanaged.passUnretained(event)
    }
}

/// A button that captures the next physical keystroke and reports it as a `KeyCombo`.
struct KeyCaptureView: View {
    @Binding var combo: KeyCombo?
    var placeholder: String = "Click to set key"

    @State private var isCapturing = false
    @State private var session: KeyCaptureSession?

    var body: some View {
        Button {
            if isCapturing {
                stopCapture()
            } else {
                startCapture()
            }
        } label: {
            Text(isCapturing ? "Press a key… (Esc to cancel)" : (combo?.displayString ?? placeholder))
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
        session = newSession
        isCapturing = true
        newSession.start()
    }

    private func stopCapture() {
        session?.stop()
        session = nil
        isCapturing = false
    }
}
