import SwiftUI
import MacRemapperCore

struct OnboardingView: View {
    @EnvironmentObject var accessibilityPermission: AccessibilityPermission

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "keyboard.badge.ellipsis")
                .font(.system(size: 48))
                .foregroundStyle(.accent)

            Text("Accessibility Access Required")
                .font(.title2)
                .bold()

            Text("""
            Mac Remapper needs Accessibility access to intercept and remap keystrokes system-wide. \
            Your keystrokes are processed locally and never leave your Mac.
            """)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .frame(maxWidth: 360)

            VStack(spacing: 10) {
                Button("Open System Settings…") {
                    accessibilityPermission.requestPrompt()
                    accessibilityPermission.openSystemSettings()
                }
                .buttonStyle(.borderedProminent)

                Text("Enable “MacRemapper” in Privacy & Security → Accessibility, then this window will update automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
        }
        .padding(40)
        .onAppear {
            accessibilityPermission.startPolling()
        }
    }
}
