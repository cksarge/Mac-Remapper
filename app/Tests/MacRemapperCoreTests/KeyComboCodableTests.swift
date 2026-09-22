import Testing
@testable import MacRemapperCore

struct KeyComboCodableTests {
    @Test func keyComboRoundTrip() throws {
        let combo = KeyCombo(keyCode: 13, modifiers: [.command, .shift])
        let data = try JSONEncoder.macRemapper.encode(combo)
        let decoded = try JSONDecoder.macRemapper.decode(KeyCombo.self, from: data)
        #expect(combo == decoded)
    }

    @Test func mappingRemapRoundTrip() throws {
        let mapping = Mapping(
            trigger: KeyCombo(keyCode: 13, modifiers: []),
            action: .remap(output: KeyCombo(keyCode: 126, modifiers: []))
        )
        let data = try JSONEncoder.macRemapper.encode(mapping)
        let decoded = try JSONDecoder.macRemapper.decode(Mapping.self, from: data)
        #expect(mapping == decoded)
    }

    @Test func mappingMacroRoundTrip() throws {
        let steps = [
            MacroStep(combo: KeyCombo(keyCode: 21, modifiers: [.command, .shift]), delayAfterMs: 300),
            MacroStep(combo: KeyCombo(keyCode: 8, modifiers: [.command]), delayAfterMs: 0)
        ]
        let mapping = Mapping(trigger: KeyCombo(keyCode: 105, modifiers: []), action: .macro(steps: steps))
        let data = try JSONEncoder.macRemapper.encode(mapping)
        let decoded = try JSONDecoder.macRemapper.decode(Mapping.self, from: data)
        #expect(mapping == decoded)
    }

    @Test func profileScopeRoundTrip() throws {
        let scope = ProfileScope.apps(bundleIdentifiers: ["com.apple.dt.Xcode", "com.apple.Terminal"])
        let data = try JSONEncoder.macRemapper.encode(scope)
        let decoded = try JSONDecoder.macRemapper.decode(ProfileScope.self, from: data)
        #expect(scope == decoded)
    }

    @Test func profileDocumentRoundTrip() throws {
        let profile = Profile(
            name: "Gaming",
            scope: .apps(bundleIdentifiers: ["com.example.game"]),
            mappings: [
                Mapping(trigger: KeyCombo(keyCode: 13, modifiers: []), action: .remap(output: KeyCombo(keyCode: 126, modifiers: [])))
            ]
        )
        let document = ProfileDocument(profiles: [profile])
        let data = try JSONEncoder.macRemapper.encode(document)
        let decoded = try JSONDecoder.macRemapper.decode(ProfileDocument.self, from: data)
        #expect(document.profiles == decoded.profiles)
        #expect(document.schemaVersion == decoded.schemaVersion)
    }
}
