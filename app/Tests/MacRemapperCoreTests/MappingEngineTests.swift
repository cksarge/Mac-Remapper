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
            mappings: [Mapping(trigger: wKey, action: .macro(steps: [MacroStep(combo: f13, delayAfterMs: 0)]))]
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
}
