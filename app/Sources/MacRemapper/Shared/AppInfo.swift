import AppKit

/// Looks up an app's display name and icon from its bundle identifier.
enum AppInfo {
    static func url(for bundleIdentifier: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    static func displayName(for bundleIdentifier: String) -> String {
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first,
           let name = running.localizedName {
            return name
        }
        if let url = url(for: bundleIdentifier) {
            return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        }
        return bundleIdentifier
    }

    static func icon(for bundleIdentifier: String) -> NSImage? {
        url(for: bundleIdentifier).map { NSWorkspace.shared.icon(forFile: $0.path) }
    }
}
