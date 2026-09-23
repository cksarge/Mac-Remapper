import Foundation

enum ResolvedAction {
    case passthrough
    case remap(KeyCombo)
    case macro(Mapping)
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

        // First match wins: app-scoped profiles before global ones, and within each group,
        // profiles higher in the list (and mappings earlier in a profile) take priority.
        // `MappingPrecedence` applies the same rule to warn about overridden mappings.
        let enabledProfiles = profiles.filter { $0.isEnabled }
        let appProfiles = enabledProfiles.filter { !$0.scope.isGlobal && $0.scope.matches(bundleIdentifier: frontmostBundleID) }
        let globalProfiles = enabledProfiles.filter { $0.scope.isGlobal }

        for profile in appProfiles + globalProfiles {
            for mapping in profile.mappings where mapping.isEnabled && table[mapping.trigger] == nil {
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
        case .macro:
            return .macro(mapping)
        }
    }
}

/// Finds mappings that never fire because another mapping takes priority for the same trigger,
/// using the same rule as `MappingEngine`: earlier profiles (and earlier mappings within a
/// profile) win among profiles that apply at the same time.
public enum MappingPrecedence {
    /// The profile containing a mapping that takes priority over `mapping` whenever both would
    /// apply, or nil if `mapping` is never overridden. Returns `profile` itself when an earlier
    /// mapping in the same profile uses the same trigger.
    public static func overridingProfile(of mapping: Mapping, in profile: Profile, among profiles: [Profile]) -> Profile? {
        guard profile.isEnabled, mapping.isEnabled, mapping.trigger.keyCode != KeyCodeTable.unsetKeyCode,
              let profileIndex = profiles.firstIndex(where: { $0.id == profile.id }) else {
            return nil
        }

        for other in profiles[..<profileIndex] where other.isEnabled && appliesTogether(other.scope, profile.scope) {
            if other.mappings.contains(where: { $0.isEnabled && $0.trigger == mapping.trigger }) {
                return other
            }
        }

        if let mappingIndex = profile.mappings.firstIndex(where: { $0.id == mapping.id }),
           profile.mappings[..<mappingIndex].contains(where: { $0.isEnabled && $0.trigger == mapping.trigger }) {
            return profile
        }
        return nil
    }

    /// Whether two scopes can be active at once *and* compete at the same priority level.
    /// (Global vs. app-scoped isn't a conflict: the app-scoped one wins by design.)
    private static func appliesTogether(_ a: ProfileScope, _ b: ProfileScope) -> Bool {
        switch (a, b) {
        case (.global, .global):
            return true
        case (.apps(let first), .apps(let second)):
            return !Set(first).isDisjoint(with: second)
        default:
            return false
        }
    }
}
