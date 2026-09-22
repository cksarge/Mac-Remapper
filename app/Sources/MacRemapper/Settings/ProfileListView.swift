import SwiftUI
import MacRemapperCore

struct ProfileListView: View {
    @EnvironmentObject var profileStore: ProfileStore
    @State private var selectedProfileID: Profile.ID?

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedProfileID) {
                ForEach(profileStore.profiles) { profile in
                    HStack {
                        Toggle("", isOn: binding(for: profile).isEnabled)
                            .labelsHidden()
                        VStack(alignment: .leading) {
                            Text(profile.name)
                            Text(scopeLabel(profile))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(profile.id)
                }
                .onDelete { indexSet in
                    profileStore.profiles.remove(atOffsets: indexSet)
                }
            }
            .navigationTitle("Profiles")
            .toolbar {
                ToolbarItem {
                    Button {
                        addProfile()
                    } label: {
                        Label("Add Profile", systemImage: "plus")
                    }
                }
                ToolbarItem {
                    Button {
                        importProfile()
                    } label: {
                        Label("Import…", systemImage: "square.and.arrow.down")
                    }
                }
            }
        } detail: {
            if let selectedProfileID, let index = profileStore.profiles.firstIndex(where: { $0.id == selectedProfileID }) {
                ProfileDetailView(profile: binding(forIndex: index))
            } else {
                Text("Select a profile, or create a new one.")
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            if selectedProfileID == nil {
                selectedProfileID = profileStore.profiles.first?.id
            }
        }
    }

    private func scopeLabel(_ profile: Profile) -> String {
        switch profile.scope {
        case .global:
            return "Global"
        case .apps(let ids):
            return ids.isEmpty ? "No apps selected" : "\(ids.count) app\(ids.count == 1 ? "" : "s")"
        }
    }

    private func binding(for profile: Profile) -> Binding<Profile> {
        guard let index = profileStore.profiles.firstIndex(where: { $0.id == profile.id }) else {
            return .constant(profile)
        }
        return binding(forIndex: index)
    }

    private func binding(forIndex index: Int) -> Binding<Profile> {
        Binding(
            get: { profileStore.profiles[index] },
            set: { newValue in
                var updated = newValue
                updated.modifiedAt = Date()
                profileStore.profiles[index] = updated
            }
        )
    }

    private func addProfile() {
        let profile = Profile(name: "New Profile")
        profileStore.profiles.append(profile)
        selectedProfileID = profile.id
    }

    private func importProfile() {
        guard let imported = ImportExport.importProfile() else { return }
        profileStore.profiles.append(imported)
        selectedProfileID = imported.id
    }
}
