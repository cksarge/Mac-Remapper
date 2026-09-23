import SwiftUI
import AppKit
import MacRemapperCore

/// The custom header at the top of the menu bar menu: app icon, name, live status,
/// and a switch to turn remapping on or off without closing the menu.
struct MenuHeaderView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text("Mac Remapper")
                    .font(.system(size: 14, weight: .bold))
                HStack(spacing: 5) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                    Text(statusText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 20)

            Toggle("Remapping Enabled", isOn: $appState.isRemappingEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .disabled(!isTrusted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(width: 290)
    }

    private var isTrusted: Bool {
        appState.accessibilityPermission.isTrusted
    }

    private var statusText: String {
        if !isTrusted { return "Needs Accessibility access" }
        if !appState.isRemappingEnabled { return "Paused" }
        let activeCount = appState.profileStatuses.filter(\.isActive).count
        return "On · \(activeCount) active"
    }

    private var statusColor: Color {
        if !isTrusted { return .orange }
        return appState.isRemappingEnabled ? .green : .secondary
    }
}
