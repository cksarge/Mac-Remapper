import SwiftUI
import MacRemapperCore

@main
struct MacRemapperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopoverView()
                .environmentObject(appState)
        } label: {
            Image(systemName: appState.isRemappingEnabled ? "keyboard" : "keyboard.badge.ellipsis")
        }
        .menuBarExtraStyle(.window)

        Window("Mac Remapper Settings", id: "settings") {
            SettingsRootView()
                .environmentObject(appState)
        }
        .windowResizability(.contentSize)
    }
}

/// LSUIElement suppresses the Dock icon; the delegate exists so the event tap
/// and frontmost-app monitoring (already started by `AppState`'s init) are
/// guaranteed to be live as soon as the process launches, independent of
/// whether any SwiftUI window/scene has been shown yet.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
