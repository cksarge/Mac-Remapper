import Foundation

enum ResolvedAction {
    case passthrough
    case remap(KeyCombo)
    case macro([MacroStep])
}

/// Resolves an incoming key combo, given the current frontmost app, into an action.
///
/// Rebuilding the active lookup table is O(profiles), so it's done only when the
/// profile set or the frontmost app changes (`rebuild(profiles:frontmostBundleID:)`),
/// not on every keystroke — the hot path (`resolve`) is a single dictionary lookup.
final class MappingEngine {
    private var activeMappings: [KeyCombo: Mapping] = [:]

    func rebuild(profiles: [Profile], frontmostBundleID: String?) {
        var table: [KeyCombo: Mapping] = [:]

        // Global profiles first, so app-scoped profiles processed after them
        // overwrite conflicting triggers and take precedence.
        let enabledProfiles = profiles.filter { $0.isEnabled }
        let globalProfiles = enabledProfiles.filter { $0.scope.isGlobal }
        let appProfiles = enabledProfiles.filter { !$0.scope.isGlobal && $0.scope.matches(bundleIdentifier: frontmostBundleID) }

        for profile in globalProfiles {
            for mapping in profile.mappings where mapping.isEnabled {
                table[mapping.trigger] = mapping
            }
        }
        for profile in appProfiles {
            for mapping in profile.mappings where mapping.isEnabled {
                table[mapping.trigger] = mapping
            }
        }

        activeMappings = table
    }

    func resolve(_ combo: KeyCombo) -> ResolvedAction {
        guard let mapping = activeMappings[combo] else {
            return .passthrough
        }
        switch mapping.action {
        case .remap(let output):
            return .remap(output)
        case .macro(let steps):
            return .macro(steps)
        }
    }
}
