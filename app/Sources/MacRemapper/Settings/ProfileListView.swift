import SwiftUI
import MacRemapperCore

struct ProfileListView: View {
    @EnvironmentObject var profileStore: ProfileStore
    @EnvironmentObject var launchAtLogin: LaunchAtLoginManager
    @State private var selectedProfileID: Profile.ID?
    @State private var profilePendingDeletion: Profile?

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
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            profilePendingDeletion = profile
                        }
                    }
                }
                // Order is priority: when profiles map the same key, the higher one wins.
                .onMove { source, destination in
                    profileStore.profiles.move(fromOffsets: source, toOffset: destination)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    // Classic macOS "+ −" list controls, which work in any window
                    // (SwiftUI toolbars don't appear in an AppKit-hosted window on macOS 13).
                    HStack(spacing: 2) {
                        Button {
                            addProfile()
                        } label: {
                            Image(systemName: "plus")
                                .frame(width: 22, height: 20)
                        }
                        .help("Add Profile")

                        Button {
                            profilePendingDeletion = selectedProfile
                        } label: {
                            Image(systemName: "minus")
                                .frame(width: 22, height: 20)
                        }
                        .help("Delete Profile")
                        .disabled(selectedProfile == nil)

                        Spacer()

                        Button {
                            importProfile()
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                                .frame(width: 22, height: 20)
                        }
                        .help("Import Profile…")
                    }
                    .buttonStyle(.borderless)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    Divider()
                    Toggle("Launch at Login", isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
            }
            .onDeleteCommand {
                profilePendingDeletion = selectedProfile
            }
            .navigationTitle("Profiles")
            .confirmationDialog(
                "Delete “\(profilePendingDeletion?.name ?? "")”?",
                isPresented: Binding(
                    get: { profilePendingDeletion != nil },
                    set: { if !$0 { profilePendingDeletion = nil } }
                ),
                presenting: profilePendingDeletion
            ) { profile in
                Button("Delete", role: .destructive) {
                    deleteProfile(profile)
                }
            } message: { _ in
                Text("Its mappings will be removed. This can't be undone.")
            }
        } detail: {
            if let profile = selectedProfile {
                ProfileDetailView(profile: binding(for: profile), allProfiles: profileStore.profiles)
                    .id(profile.id)
            } else if profileStore.profiles.isEmpty {
                EmptyProfilesView(onCreate: addProfile)
            } else {
                Text("Select a profile.")
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            if selectedProfileID == nil {
                selectedProfileID = profileStore.profiles.first?.id
            }
        }
    }

    private var selectedProfile: Profile? {
        profileStore.profiles.first { $0.id == selectedProfileID }
    }

    private func deleteProfile(_ profile: Profile) {
        // Move the selection off the profile before removing it, so the detail view
        // never renders a profile that no longer exists.
        if selectedProfileID == profile.id {
            selectedProfileID = profileStore.profiles.first { $0.id != profile.id }?.id
        }
        profileStore.profiles.removeAll { $0.id == profile.id }
        profileStore.saveNow()
    }

    private func scopeLabel(_ profile: Profile) -> String {
        switch profile.scope {
        case .global:
            return "Global"
        case .apps(let ids):
            return ids.isEmpty ? "No apps selected" : "\(ids.count) app\(ids.count == 1 ? "" : "s")"
        }
    }

    /// Looks the profile up by ID on every access (never by a captured array index),
    /// so a binding still held by a view mid-deletion can't read past the array's end.
    private func binding(for profile: Profile) -> Binding<Profile> {
        let id = profile.id
        return Binding(
            get: { profileStore.profiles.first { $0.id == id } ?? profile },
            set: { newValue in
                guard let index = profileStore.profiles.firstIndex(where: { $0.id == id }) else { return }
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

/// Shown when there are no profiles yet: on first launch, or after deleting the last one.
private struct EmptyProfilesView: View {
    var onCreate: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("No Profiles Yet")
                .font(.title2)
                .bold()
            Text("A profile is a set of key remaps and macros, active everywhere or only in the apps you choose.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 340)
                .fixedSize(horizontal: false, vertical: true)
            Button("Create Profile", action: onCreate)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
