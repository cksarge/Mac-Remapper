// Lightweight smoke test for MacRemapperCore that avoids XCTest/swift-testing,
// since both rely on macro plugins that only ship inside full Xcode.app (not the
// standalone Command Line Tools). Run with `swift run CoreSmokeTest`.
//
// Tests/MacRemapperCoreTests holds the same coverage as a proper XCTest-less
// swift-testing suite — use `swift test` there once you have full Xcode installed.
// Keep both in sync if you add coverage for new Core behavior.
import Foundation
@testable import MacRemapperCore

var failures = 0

func check(_ condition: Bool, _ message: String) {
    if condition {
        print("PASS: \(message)")
    } else {
        print("FAIL: \(message)")
        failures += 1
    }
}

// MARK: - Codable round-trips

do {
    let combo = KeyCombo(keyCode: 13, modifiers: [.command, .shift])
    let data = try JSONEncoder.macRemapper.encode(combo)
    let decoded = try JSONDecoder.macRemapper.decode(KeyCombo.self, from: data)
    check(combo == decoded, "KeyCombo round-trips through JSON")
} catch {
    check(false, "KeyCombo round-trip threw: \(error)")
}

do {
    let mapping = Mapping(trigger: KeyCombo(keyCode: 13, modifiers: []), action: .remap(output: KeyCombo(keyCode: 126, modifiers: [])))
    let data = try JSONEncoder.macRemapper.encode(mapping)
    let decoded = try JSONDecoder.macRemapper.decode(Mapping.self, from: data)
    check(mapping == decoded, "Mapping (remap) round-trips through JSON")
} catch {
    check(false, "Mapping (remap) round-trip threw: \(error)")
}

do {
    let steps = [
        MacroStep(combo: KeyCombo(keyCode: 21, modifiers: [.command, .shift]), delayAfterMs: 300),
        MacroStep(combo: KeyCombo(keyCode: 8, modifiers: [.command]), delayAfterMs: 0)
    ]
    let mapping = Mapping(trigger: KeyCombo(keyCode: 105, modifiers: []), action: .macro(steps: steps))
    let data = try JSONEncoder.macRemapper.encode(mapping)
    let decoded = try JSONDecoder.macRemapper.decode(Mapping.self, from: data)
    check(mapping == decoded, "Mapping (macro) round-trips through JSON")
} catch {
    check(false, "Mapping (macro) round-trip threw: \(error)")
}

do {
    let profile = Profile(
        name: "Gaming",
        scope: .apps(bundleIdentifiers: ["com.example.game"]),
        mappings: [Mapping(trigger: KeyCombo(keyCode: 13, modifiers: []), action: .remap(output: KeyCombo(keyCode: 126, modifiers: [])))]
    )
    let document = ProfileDocument(profiles: [profile])
    let data = try JSONEncoder.macRemapper.encode(document)
    let decoded = try JSONDecoder.macRemapper.decode(ProfileDocument.self, from: data)
    check(document.profiles == decoded.profiles, "ProfileDocument round-trips through JSON")
} catch {
    check(false, "ProfileDocument round-trip threw: \(error)")
}

// MARK: - MappingEngine

let wKey = KeyCombo(keyCode: 13, modifiers: [])
let upArrow = KeyCombo(keyCode: 126, modifiers: [])
let f13 = KeyCombo(keyCode: 105, modifiers: [])

do {
    let engine = MappingEngine()
    engine.rebuild(profiles: [], frontmostBundleID: nil)
    if case .passthrough = engine.resolve(wKey) {
        check(true, "Passthrough when no mapping matches")
    } else {
        check(false, "Passthrough when no mapping matches")
    }
}

do {
    let profile = Profile(name: "Global", scope: .global, mappings: [Mapping(trigger: wKey, action: .remap(output: upArrow))])
    let engine = MappingEngine()
    engine.rebuild(profiles: [profile], frontmostBundleID: "com.apple.TextEdit")
    if case .remap(let output) = engine.resolve(wKey) {
        check(output == upArrow, "Global remap applies")
    } else {
        check(false, "Global remap applies")
    }
}

do {
    let globalProfile = Profile(name: "Global", scope: .global, mappings: [Mapping(trigger: wKey, action: .remap(output: upArrow))])
    let appProfile = Profile(
        name: "Game Profile",
        scope: .apps(bundleIdentifiers: ["com.example.game"]),
        mappings: [Mapping(trigger: wKey, action: .macro(steps: [MacroStep(combo: f13, delayAfterMs: 0)]))]
    )
    let engine = MappingEngine()

    engine.rebuild(profiles: [globalProfile, appProfile], frontmostBundleID: "com.example.game")
    if case .macro = engine.resolve(wKey) {
        check(true, "App-scoped macro wins while its app is frontmost")
    } else {
        check(false, "App-scoped macro wins while its app is frontmost")
    }

    engine.rebuild(profiles: [globalProfile, appProfile], frontmostBundleID: "com.apple.TextEdit")
    if case .remap(let output) = engine.resolve(wKey) {
        check(output == upArrow, "Global remap applies once app-scoped profile's app is no longer frontmost")
    } else {
        check(false, "Global remap applies once app-scoped profile's app is no longer frontmost")
    }
}

do {
    var profile = Profile(name: "Disabled", scope: .global, mappings: [Mapping(trigger: wKey, action: .remap(output: upArrow))])
    profile.isEnabled = false
    let engine = MappingEngine()
    engine.rebuild(profiles: [profile], frontmostBundleID: nil)
    if case .passthrough = engine.resolve(wKey) {
        check(true, "Disabled profile is ignored")
    } else {
        check(false, "Disabled profile is ignored")
    }
}

do {
    let mapping = Mapping(trigger: wKey, action: .remap(output: upArrow), isEnabled: false)
    let profile = Profile(name: "Global", scope: .global, mappings: [mapping])
    let engine = MappingEngine()
    engine.rebuild(profiles: [profile], frontmostBundleID: nil)
    if case .passthrough = engine.resolve(wKey) {
        check(true, "Disabled mapping is ignored")
    } else {
        check(false, "Disabled mapping is ignored")
    }
}

// MARK: - ProfileStore persistence

do {
    let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("MacRemapperSmokeTest-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let store = ProfileStore(directory: tempDirectory)
    check(store.profiles.isEmpty, "ProfileStore starts empty when no file exists")

    let profile = Profile(
        name: "Test Profile",
        scope: .global,
        mappings: [Mapping(trigger: wKey, action: .remap(output: upArrow))]
    )
    store.profiles = [profile]
    store.saveNow()

    let reloaded = ProfileStore(directory: tempDirectory)
    check(reloaded.profiles == [profile], "ProfileStore save/reload round-trips")
}

print("")
if failures == 0 {
    print("All checks passed.")
    exit(0)
} else {
    print("\(failures) check(s) failed.")
    exit(1)
}
