import Foundation
import CoreGraphics

/// Synthesizes and posts CGEvents for resolved remaps and macros.
///
/// Remap output is built synchronously and returned directly to the tap callback.
/// Macro steps involve delays, so they must never block the tap callback thread —
/// they're dispatched to a private serial queue that paces itself with `asyncAfter`.
enum EventSynthesizer {
    private static let macroQueue = DispatchQueue(label: "com.macremapper.macro-queue")

    /// Builds the replacement CGEvent for a simple remap. Call this from the tap
    /// callback and return its result directly (or nil, if source creation fails,
    /// which swallows the original key rather than risking a malformed injected event).
    static func makeEvent(for combo: KeyCombo, keyDown: Bool) -> CGEvent? {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(combo.keyCode), keyDown: keyDown) else {
            return nil
        }
        event.flags = combo.modifiers.cgEventFlags
        return event
    }

    /// Fires a macro's steps in order on a background queue, posting a key-down/key-up
    /// pair for each step's combo and waiting `delayAfterMs` before the next one.
    static func runMacro(_ steps: [MacroStep]) {
        macroQueue.async {
            for step in steps {
                postKeystroke(step.combo)
                if step.delayAfterMs > 0 {
                    Thread.sleep(forTimeInterval: Double(step.delayAfterMs) / 1000.0)
                }
            }
        }
    }

    private static func postKeystroke(_ combo: KeyCombo) {
        guard let down = makeEvent(for: combo, keyDown: true),
              let up = makeEvent(for: combo, keyDown: false) else {
            return
        }
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }
}
