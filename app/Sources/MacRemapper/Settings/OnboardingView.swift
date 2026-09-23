import SwiftUI
import MacRemapperCore

struct OnboardingView: View {
    @EnvironmentObject var accessibilityPermission: AccessibilityPermission
    @State private var checkedButStillDenied = false

    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

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
            .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                Button("Grant Access…") {
                    accessibilityPermission.requestPrompt()
                }
                .buttonStyle(.borderedProminent)

                Text("Click “Open System Settings” in the prompt that appears, then turn on “MacRemapper”. This window will update automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Check Again") {
                    accessibilityPermission.refresh()
                    checkedButStillDenied = !accessibilityPermission.isTrusted
                }
                .buttonStyle(.bordered)

                if checkedButStillDenied {
                    Text("Access still isn't granted. Make sure “MacRemapper” is switched on in System Settings.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Fallback for when macOS doesn't show the prompt (e.g. it was already denied once).
                Button("No prompt? Open System Settings manually") {
                    accessibilityPermission.openSystemSettings()
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        }
        .padding(40)
        .onAppear {
            accessibilityPermission.startPolling()
        }
    }
}
