import Testing
@testable import MacRemapperCore

struct MappingEngineTests {
    private let wKey = KeyCombo(keyCode: 13, modifiers: [])
    private let upArrow = KeyCombo(keyCode: 126, modifiers: [])
    private let f13 = KeyCombo(keyCode: 105, modifiers: [])

    @Test func passthroughWhenNoMappingMatches() {
        let engine = MappingEngine()
        engine.rebuild(profiles: [], frontmostBundleID: nil)
        guard case .passthrough = engine.resolve(wKey) else {
            Issue.record("Expected passthrough")
            return
        }
    }

    @Test func globalRemapApplies() {
        let profile = Profile(
            name: "Global",
            scope: .global,
            mappings: [Mapping(trigger: wKey, action: .remap(output: upArrow))]
        )
        let engine = MappingEngine()
        engine.rebuild(profiles: [profile], frontmostBundleID: "com.apple.TextEdit")

        guard case .remap(let output) = engine.resolve(wKey) else {
            Issue.record("Expected remap")
            return
        }
        #expect(output == upArrow)
    }

    @Test func appScopedProfileTakesPrecedenceOverGlobal() {
        let globalProfile = Profile(
            name: "Global",
            scope: .global,
            mappings: [Mapping(trigger: wKey, action: .remap(output: upArrow))]
        )
        let appProfile = Profile(
            name: "Game Profile",
            scope: .apps(bundleIdentifiers: ["com.example.game"]),
            mappings: [Mapping(trigger: wKey, action: .macro(steps: [.keystroke(f13)]))]
        )
        let engine = MappingEngine()

        engine.rebuild(profiles: [globalProfile, appProfile], frontmostBundleID: "com.example.game")
        guard case .macro = engine.resolve(wKey) else {
            Issue.record("Expected app-scoped macro to win while game is frontmost")
            return
        }

        engine.rebuild(profiles: [globalProfile, appProfile], frontmostBundleID: "com.apple.TextEdit")
        guard case .remap(let output) = engine.resolve(wKey) else {
            Issue.record("Expected global remap to apply once game is no longer frontmost")
            return
        }
        #expect(output == upArrow)
    }

    @Test func disabledProfileIsIgnored() {
        var profile = Profile(
            name: "Disabled",
            scope: .global,
            mappings: [Mapping(trigger: wKey, action: .remap(output: upArrow))]
        )
        profile.isEnabled = false
        let engine = MappingEngine()
        engine.rebuild(profiles: [profile], frontmostBundleID: nil)

        guard case .passthrough = engine.resolve(wKey) else {
            Issue.record("Expected passthrough for disabled profile")
            return
        }
    }

    @Test func disabledMappingIsIgnored() {
        let mapping = Mapping(trigger: wKey, action: .remap(output: upArrow), isEnabled: false)
        let profile = Profile(name: "Global", scope: .global, mappings: [mapping])
        let engine = MappingEngine()
        engine.rebuild(profiles: [profile], frontmostBundleID: nil)

        guard case .passthrough = engine.resolve(wKey) else {
            Issue.record("Expected passthrough for disabled mapping")
            return
        }
    }

    @Test func higherProfileWinsBetweenConflictingGlobals() {
        let downArrow = KeyCombo(keyCode: 125, modifiers: [])
        let first = Profile(name: "First", scope: .global,
                            mappings: [Mapping(trigger: wKey, action: .remap(output: upArrow))])
        let second = Profile(name: "Second", scope: .global,
                             mappings: [Mapping(trigger: wKey, action: .remap(output: downArrow))])
        let engine = MappingEngine()
        engine.rebuild(profiles: [first, second], frontmostBundleID: nil)
        guard case .remap(let output) = engine.resolve(wKey) else {
            Issue.record("Expected remap")
            return
        }
        #expect(output == upArrow)
        #expect(MappingPrecedence.overridingProfile(of: second.mappings[0], in: second, among: [first, second])?.id == first.id)
        #expect(MappingPrecedence.overridingProfile(of: first.mappings[0], in: first, among: [first, second]) == nil)
    }

    @Test func appScopedOverGlobalIsNotReportedAsConflict() {
        let global = Profile(name: "Global", scope: .global,
                             mappings: [Mapping(trigger: wKey, action: .remap(output: upArrow))])
        let app = Profile(name: "Game", scope: .apps(bundleIdentifiers: ["com.example.game"]),
                          mappings: [Mapping(trigger: wKey, action: .macro(steps: [.keystroke(f13)]))])
        #expect(MappingPrecedence.overridingProfile(of: global.mappings[0], in: global, among: [app, global]) == nil)
        #expect(MappingPrecedence.overridingProfile(of: app.mappings[0], in: app, among: [global, app]) == nil)
    }

    @Test func duplicateTriggerWithinProfileIsReported() {
        let profile = Profile(name: "Dupes", scope: .global, mappings: [
            Mapping(trigger: wKey, action: .remap(output: upArrow)),
            Mapping(trigger: wKey, action: .remap(output: f13))
        ])
        #expect(MappingPrecedence.overridingProfile(of: profile.mappings[1], in: profile, among: [profile])?.id == profile.id)
        #expect(MappingPrecedence.overridingProfile(of: profile.mappings[0], in: profile, among: [profile]) == nil)
    }
}
