import Foundation
import ApplicationServices
import AppKit
import Combine

/// Tracks whether this process is trusted for Accessibility (required for a global
/// CGEventTap), and polls so the UI updates the moment the user flips the System
/// Settings toggle, without requiring an app restart.
public final class AccessibilityPermission: ObservableObject {
    @Published public private(set) var isTrusted: Bool

    private var pollTimer: Timer?

    init() {
        isTrusted = AXIsProcessTrusted()
    }

    /// Triggers the system's native "wants to control your computer" prompt once,
    /// which also adds this app to the Accessibility list (initially unchecked).
    public func requestPrompt() {
        let options: [String: Any] = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        startPolling()
    }

    public func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        startPolling()
    }

    public func refresh() {
        isTrusted = AXIsProcessTrusted()
    }

    public func startPolling() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let trusted = AXIsProcessTrusted()
            if trusted != self.isTrusted {
                self.isTrusted = trusted
            }
            if trusted {
                self.stopPolling()
            }
        }
    }

    public func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
