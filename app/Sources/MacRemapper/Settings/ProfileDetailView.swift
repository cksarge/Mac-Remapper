import SwiftUI
import MacRemapperCore

struct ProfileDetailView: View {
    @Binding var profile: Profile
    /// Every profile, in priority order, to detect mappings overridden by another one.
    var allProfiles: [Profile]
    @State private var expandedMappingIDs: Set<Mapping.ID> = []

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
                    DisclosureGroup(isExpanded: isExpanded(mapping.id)) {
                        MappingEditorView(mapping: $mapping)
                        Button(role: .destructive) {
                            profile.mappings.removeAll { $0.id == mapping.id }
                        } label: {
                            Label("Delete Mapping", systemImage: "trash")
                        }
                    } label: {
                        // Full-width hit area so clicking anywhere on the row toggles it, not just the chevron.
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mapping.trigger.keyCode == KeyCodeTable.unsetKeyCode ? "New Mapping" : mappingSummary(mapping))
                            if let warning = overrideWarning(for: mapping) {
                                Label(warning, systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation { isExpanded(mapping.id).wrappedValue.toggle() }
                        }
                    }
                }

                Button {
                    let mapping = Mapping(trigger: .unset, action: .remap(output: .unset))
                    profile.mappings.append(mapping)
                    expandedMappingIDs.insert(mapping.id)
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

    private func overrideWarning(for mapping: Mapping) -> String? {
        // allProfiles can lag the binding by an edit; use the live copy of this profile.
        let profiles = allProfiles.map { $0.id == profile.id ? profile : $0 }
        guard let winner = MappingPrecedence.overridingProfile(of: mapping, in: profile, among: profiles) else {
            return nil
        }
        if winner.id == profile.id {
            return "Never used: an earlier mapping in this profile has the same trigger."
        }
        return "Never used: “\(winner.name)” maps the same key and is higher in the list. Drag profiles in the sidebar to change priority."
    }

    private func isExpanded(_ id: Mapping.ID) -> Binding<Bool> {
        Binding(
            get: { expandedMappingIDs.contains(id) },
            set: { expanded in
                if expanded {
                    expandedMappingIDs.insert(id)
                } else {
                    expandedMappingIDs.remove(id)
                }
            }
        )
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
