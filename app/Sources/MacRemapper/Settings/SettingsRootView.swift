import SwiftUI
import MacRemapperCore

struct SettingsRootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.accessibilityPermission.isTrusted {
                ProfileListView()
                    .environmentObject(appState.profileStore)
                    .environmentObject(appState.launchAtLogin)
            } else {
                OnboardingView()
                    .environmentObject(appState.accessibilityPermission)
            }
        }
        .frame(minWidth: 720, minHeight: 480)
        // Grouped forms draw text fields borderless by default, so they read as plain text.
        .textFieldStyle(.roundedBorder)
    }
}
