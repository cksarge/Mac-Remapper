import Foundation
import AppKit

/// Tracks the bundle identifier of the currently frontmost application.
///
/// `frontmostBundleID` is read from the event tap's callback (not the main run loop's
/// SwiftUI update cycle), so it's a plain, lock-free property updated only from the
/// main thread's NSWorkspace notification handler — safe to read because the tap
/// callback itself also runs on the main run loop (see `EventTapManager`).
final class FrontmostAppMonitor {
    private(set) var frontmostBundleID: String?

    /// Invoked on the main run loop whenever the frontmost app's bundle ID changes.
    var onChange: ((String?) -> Void)?

    private var observer: NSObjectProtocol?

    init() {
        frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            // Opening our own menu bar popover or Settings window activates this app; keep
            // tracking the app the user came from so its profiles stay active and visible.
            guard app?.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
            self.frontmostBundleID = app?.bundleIdentifier
            self.onChange?(self.frontmostBundleID)
        }
    }

    deinit {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}
