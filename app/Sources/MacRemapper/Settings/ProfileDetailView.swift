import SwiftUI
import MacRemapperCore

struct ProfileDetailView: View {
    @Binding var profile: Profile
    @State private var selectedMappingID: Mapping.ID?

    private var isGlobal: Binding<Bool> {
        Binding(
            get: { profile.scope.isGlobal },
            set: { global in
                profile.scope = global ? .global : .apps(bundleIdentifiers: [])
            }
        )
    }

    private var appBundleIdentifiers: Binding<[String]> {
        Binding(
            get: {
                if case .apps(let ids) = profile.scope { return ids }
                return []
            },
            set: { profile.scope = .apps(bundleIdentifiers: $0) }
        )
    }

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Name", text: $profile.name)
                Toggle("Enabled", isOn: $profile.isEnabled)
                Picker("Applies to", selection: isGlobal) {
                    Text("Global (all apps)").tag(true)
                    Text("Specific apps").tag(false)
                }
                .pickerStyle(.segmented)

                if !isGlobal.wrappedValue {
                    AppPickerView(bundleIdentifiers: appBundleIdentifiers)
                }
            }

            Section("Mappings") {
                if profile.mappings.isEmpty {
                    Text("No mappings yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach($profile.mappings) { $mapping in
                    DisclosureGroup(mapping.trigger.keyCode == KeyCodeTable.unsetKeyCode ? "New Mapping" : mappingSummary(mapping)) {
                        MappingEditorView(mapping: $mapping)
                        Button(role: .destructive) {
                            profile.mappings.removeAll { $0.id == mapping.id }
                        } label: {
                            Label("Delete Mapping", systemImage: "trash")
                        }
                    }
                }

                Button {
                    profile.mappings.append(
                        Mapping(trigger: .unset, action: .remap(output: .unset))
                    )
                } label: {
                    Label("Add Mapping", systemImage: "plus")
                }
            }

            Section("Share") {
                Button("Export Profile…") {
                    ImportExport.exportProfile(profile)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(profile.name)
    }

    private func mappingSummary(_ mapping: Mapping) -> String {
        switch mapping.action {
        case .remap(let output):
            return "\(mapping.trigger.displayString) → \(output.displayString)"
        case .macro(let steps):
            return "\(mapping.trigger.displayString) → Macro (\(steps.count) step\(steps.count == 1 ? "" : "s"))"
        }
    }
}
