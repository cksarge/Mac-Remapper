import SwiftUI
import MacRemapperCore

@main
struct MacRemapperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // The menu bar item and Settings window are managed in AppKit by AppDelegate.
        // SwiftUI requires at least one scene; a never-inserted menu bar extra is one it can't
        // show. (An empty `Settings` scene here would pop up as a blank second window when the
        // app is reactivated, e.g. via its Dock icon.) ⌘, is rerouted to the real Settings window.
        MenuBarExtra("Mac Remapper", isInserted: .constant(false)) {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    appDelegate.showSettings()
                }
                .keyboardShortcut(",")
            }
        }
    }
}

/// LSUIElement suppresses the Dock icon. The delegate owns the app state (which starts
/// the event tap and frontmost-app monitoring on creation), the menu bar item, and
/// the Settings window.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private lazy var settingsWindow = SettingsWindowController(appState: appState)
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItemController = StatusItemController(appState: appState) { [weak self] in
            self?.showSettings()
        }
    }

    func showSettings() {
        settingsWindow.show()
    }

    /// Clicking the Dock icon (shown while Settings is open) brings Settings back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }
}
