import SwiftUI
import AppKit
import Combine
import MacRemapperCore

/// Owns the Settings window. Opened from AppKit (the menu bar menu) rather than as a
/// SwiftUI `Window` scene, since the menu is a plain `NSMenu` with no SwiftUI environment.
///
/// While the window is open the app temporarily becomes a regular app (Dock icon, ⌘Tab),
/// so the window can't get lost behind other apps, e.g. after quitting System Settings.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let appState: AppState
    private var window: NSWindow?
    private var cancellables: Set<AnyCancellable> = []
    private var clickMonitor: Any?

    init(appState: AppState) {
        self.appState = appState
        super.init()

        // When Accessibility access is granted in System Settings, bring the window back in
        // front so the user sees it switch from onboarding to their profiles.
        appState.accessibilityPermission.$isTrusted
            .removeDuplicates()
            .dropFirst()
            .filter { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let window = self?.window, window.isVisible else { return }
                self?.bringToFront()
            }
            .store(in: &cancellables)

        // macOS only moves focus out of a text field when another field is clicked. Clicking
        // anywhere else in Settings should end editing too (which also commits typed values).
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            if let window = self?.window, event.window === window, !Self.isTextInput(at: event.locationInWindow, in: window) {
                window.makeFirstResponder(nil)
            }
            return event
        }
    }

    /// Whether the click lands in a text field (or its active editor), which should keep focus.
    private static func isTextInput(at point: NSPoint, in window: NSWindow) -> Bool {
        guard let root = window.contentView?.superview ?? window.contentView else { return false }
        var view = root.hitTest(point)
        while let current = view {
            if current is NSTextField || current is NSTextView { return true }
            view = current.superview
        }
        return false
    }

    func show() {
        if window == nil {
            let hostingController = NSHostingController(
                rootView: SettingsRootView().environmentObject(appState)
            )
            hostingController.sizingOptions = [.minSize]
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Mac Remapper Settings"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.setContentSize(NSSize(width: 820, height: 560))
            window.center()
            self.window = window
        }
        bringToFront()
    }

    private func bringToFront() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Back to a menu-bar-only app once Settings is closed.
        NSApp.setActivationPolicy(.accessory)
    }
}
