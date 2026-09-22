import Foundation
import ServiceManagement

/// Thin wrapper over `SMAppService.mainApp`. No separate helper-tool target is
/// needed since the app already runs agent-style (LSUIElement) and can register
/// its own main bundle to relaunch at login.
public final class LaunchAtLoginManager: ObservableObject {
    @Published public private(set) var isEnabled: Bool

    init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    public func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            isEnabled = SMAppService.mainApp.status == .enabled
        } catch {
            refresh()
        }
    }

    public func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}
