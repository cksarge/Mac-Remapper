import SwiftUI
import MacRemapperCore

struct SettingsRootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.accessibilityPermission.isTrusted {
                TabView {
                    ProfileListView()
                        .environmentObject(appState.profileStore)
                        .tabItem { Label("Profiles", systemImage: "keyboard") }

                    GeneralSettingsView()
                        .environmentObject(appState.launchAtLogin)
                        .tabItem { Label("General", systemImage: "gearshape") }
                }
            } else {
                OnboardingView()
                    .environmentObject(appState.accessibilityPermission)
            }
        }
        .frame(minWidth: 720, minHeight: 480)
    }
}

private struct GeneralSettingsView: View {
    @EnvironmentObject var launchAtLogin: LaunchAtLoginManager

    var body: some View {
        Form {
            Toggle("Launch at Login", isOn: Binding(
                get: { launchAtLogin.isEnabled },
                set: { launchAtLogin.setEnabled($0) }
            ))
        }
        .formStyle(.grouped)
        .padding()
    }
}
