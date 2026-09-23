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
                .toggleStyle(MenuSwitchStyle())
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

/// A switch drawn in SwiftUI rather than the system `NSSwitch`. A menu's custom view never sits
/// in the key window, and the system switch draws its "on" state gray (the inactive-window look)
/// until it's clicked; this one always shows the accent color when on.
private struct MenuSwitchStyle: ToggleStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { configuration.isOn.toggle() }
        } label: {
            Capsule()
                .fill(configuration.isOn ? Color.accentColor : Color.secondary.opacity(0.35))
                .frame(width: 38, height: 22)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
                        .padding(2)
                }
                .opacity(isEnabled ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}
