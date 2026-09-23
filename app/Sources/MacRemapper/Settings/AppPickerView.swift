import SwiftUI
import MacRemapperCore
import AppKit
import UniformTypeIdentifiers

struct PickedApp: Identifiable, Hashable {
    var id: String { bundleIdentifier }
    var bundleIdentifier: String
    var name: String
    var icon: NSImage?
}

/// Lets the user build the list of app bundle identifiers an app-scoped profile applies to.
/// Offers currently-running apps for quick selection, plus a file picker for any app on disk.
struct AppPickerView: View {
    @Binding var bundleIdentifiers: [String]

    @State private var runningApps: [PickedApp] = []
    @State private var isChoosingFromDisk = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if bundleIdentifiers.isEmpty {
                Text("No apps selected — add one below.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(bundleIdentifiers, id: \.self) { id in
                    HStack {
                        if let icon = AppInfo.icon(for: id) {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 18, height: 18)
                        }
                        Text(AppInfo.displayName(for: id))
                        Text(id)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            bundleIdentifiers.removeAll { $0 == id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                Menu("Add Running App…") {
                    ForEach(runningApps) { app in
                        Button(app.name) {
                            addBundleIdentifier(app.bundleIdentifier)
                        }
                    }
                }
                .onAppear(perform: refreshRunningApps)

                Button("Choose from Disk…") {
                    isChoosingFromDisk = true
                }
            }
        }
        // SwiftUI's importer presents reliably from this accessory (no Dock icon) app;
        // a manually run NSOpenPanel could open behind the Settings window or not at all.
        .fileImporter(isPresented: $isChoosingFromDisk, allowedContentTypes: [.application]) { result in
            guard case .success(let url) = result,
                  let bundleID = Bundle(url: url)?.bundleIdentifier else { return }
            addBundleIdentifier(bundleID)
        }
    }

    private func addBundleIdentifier(_ id: String) {
        guard !bundleIdentifiers.contains(id) else { return }
        bundleIdentifiers.append(id)
    }

    private func refreshRunningApps() {
        runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> PickedApp? in
                guard let bundleID = app.bundleIdentifier else { return nil }
                return PickedApp(bundleIdentifier: bundleID, name: app.localizedName ?? bundleID, icon: app.icon)
            }
            .sorted { $0.name < $1.name }
    }
}
