import Foundation
import AppKit
import UniformTypeIdentifiers

/// Exports/imports a single profile as a standalone JSON file for sharing between users.
public enum ImportExport {
    /// Both panels start here (instead of wherever a panel was last used, often Applications),
    /// so Import opens right where Export saved.
    private static var defaultDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    public static func exportProfile(_ profile: Profile) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(profile.name).json"
        panel.directoryURL = defaultDirectory
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let data = try? JSONEncoder.macRemapper.encode(profile) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Imports a profile from a user-chosen file, regenerating its ID and every
    /// mapping/macro-step ID to avoid colliding with anything already in the store.
    public static func importProfile() -> Profile? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.directoryURL = defaultDirectory
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard var profile = try? JSONDecoder.macRemapper.decode(Profile.self, from: data) else { return nil }

        profile.id = UUID()
        profile.mappings = profile.mappings.map { mapping in
            var mapping = mapping
            mapping.id = UUID()
            if case .macro(let steps) = mapping.action {
                let freshSteps = steps.map { step -> MacroStep in
                    var step = step
                    step.id = UUID()
                    return step
                }
                mapping.action = .macro(steps: freshSteps)
            }
            return mapping
        }
        profile.createdAt = Date()
        profile.modifiedAt = Date()
        return profile
    }
}
