import SwiftUI
import MacRemapperCore
import AppKit

struct MenuBarPopoverView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Remapping Enabled", isOn: $appState.isRemappingEnabled)
                .toggleStyle(.switch)

            if !appState.accessibilityPermission.isTrusted {
                Label("Accessibility access needed", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Active Profiles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if appState.activeProfileNames.isEmpty {
                    Text("None")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(appState.activeProfileNames, id: \.self) { name in
                        Text(name)
                            .font(.callout)
                    }
                }
            }

            Divider()

            Button("Open Settings…") {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }

            Button("Quit Mac Remapper") {
                NSApp.terminate(nil)
            }
        }
        .padding(14)
        .frame(width: 240)
    }
}
