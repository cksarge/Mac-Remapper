import Foundation
import CoreGraphics
import Quartz

/// Owns the single system-wide CGEventTap used to intercept key events.
///
/// The tap callback is a C function pointer, so it can't capture Swift state directly.
/// The `refcon` passed to `tapCreate` is an unretained pointer to this instance, which
/// the callback reconstructs to dispatch into `handle(event:type:)`.
final class EventTapManager {
    /// Return the event unchanged (passthrough), a replacement event, or nil to swallow it.
    var onKeyEvent: ((CGEvent, CGEventType) -> CGEvent?)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private static let eventMask: CGEventMask =
        (1 << CGEventType.keyDown.rawValue) |
        (1 << CGEventType.keyUp.rawValue) |
        (1 << CGEventType.flagsChanged.rawValue)

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: Self.eventMask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handle(event: event, type: type)
            },
            userInfo: refcon
        ) else {
            return false
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
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

    var isRunning: Bool { eventTap != nil }

    private func handle(event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
        // The system disables the tap if our callback is too slow, or the user
        // manually disables input monitoring; re-enable immediately either way.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard let handler = onKeyEvent else {
            return Unmanaged.passUnretained(event)
        }

        guard let result = handler(event, type) else {
            return nil
        }
        return Unmanaged.passUnretained(result)
    }
}
