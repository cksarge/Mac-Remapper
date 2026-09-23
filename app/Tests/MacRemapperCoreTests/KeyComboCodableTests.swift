import Testing
import Foundation
@testable import MacRemapperCore

struct KeyComboCodableTests {
    @Test func implicitFnIsStrippedFromArrowAndFunctionKeys() {
        #expect(KeyCombo(keyCode: 126, modifiers: [.function, .shift]).modifiers == [.shift])
        #expect(KeyCombo(keyCode: 122, modifiers: [.function]).modifiers == [])
        #expect(KeyCombo(keyCode: 13, modifiers: [.function]).modifiers == [.function])
    }

    @Test func legacyMacroStepDecodes() throws {
        let json = #"{"type":"macro","steps":[{"id":"6B4CC637-EF8C-49D9-A279-B38EA0A8F9EF","combo":{"keyCode":8,"modifiers":1},"delayAfterMs":300}]}"#.data(using: .utf8)!
        let decoded = try JSONDecoder.macRemapper.decode(MappingAction.self, from: json)
        let expectedID = UUID(uuidString: "6B4CC637-EF8C-49D9-A279-B38EA0A8F9EF")!
        guard case .macro(let steps) = decoded else { Issue.record("Expected a macro"); return }
        #expect(steps.count == 2)
        #expect(steps.first?.action == .delay(milliseconds: 300, unit: .milliseconds))
        #expect(steps.last == MacroStep(id: expectedID, action: .keystroke(KeyCombo(keyCode: 8, modifiers: [.command]))))
    }

    @Test func legacyImplicitFnIsRepairedOnDecode() throws {
        let json = #"{"keyCode":126,"modifiers":16}"#.data(using: .utf8)!
        let decoded = try JSONDecoder.macRemapper.decode(KeyCombo.self, from: json)
        #expect(decoded == KeyCombo(keyCode: 126, modifiers: []))
    }

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
        let steps: [MacroStep] = [
            .keystroke(KeyCombo(keyCode: 21, modifiers: [.command, .shift])),
            .delay(milliseconds: 1500, unit: .seconds),
            .keystroke(KeyCombo(keyCode: 8, modifiers: [.command]))
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
