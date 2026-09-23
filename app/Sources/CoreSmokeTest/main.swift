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
    let steps: [MacroStep] = [
        .keystroke(KeyCombo(keyCode: 21, modifiers: [.command, .shift])),
        .delay(milliseconds: 1500, unit: .seconds),
        .keystroke(KeyCombo(keyCode: 8, modifiers: [.command]))
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

check(KeyCombo(keyCode: 126, modifiers: [.function, .shift]).modifiers == [.shift], "Implicit fn is stripped from arrow keys")
check(KeyCombo(keyCode: 13, modifiers: [.function]).modifiers == [.function], "Real fn is kept on ordinary keys")
do {
    let json = #"{"keyCode":126,"modifiers":16}"#.data(using: .utf8)!
    let decoded = try JSONDecoder.macRemapper.decode(KeyCombo.self, from: json)
    check(decoded == KeyCombo(keyCode: 126, modifiers: []), "Legacy implicit fn is repaired on decode")
} catch {
    check(false, "Legacy KeyCombo decode threw: \(error)")
}

do {
    let json = #"{"type":"macro","steps":[{"id":"6B4CC637-EF8C-49D9-A279-B38EA0A8F9EF","combo":{"keyCode":8,"modifiers":1},"delayAfterMs":300}]}"#.data(using: .utf8)!
    let decoded = try JSONDecoder.macRemapper.decode(MappingAction.self, from: json)
    let expectedID = UUID(uuidString: "6B4CC637-EF8C-49D9-A279-B38EA0A8F9EF")!
    let expected: [MacroStep] = [
        MacroStep(id: UUID(), action: .delay(milliseconds: 300, unit: .milliseconds)),
        MacroStep(id: expectedID, action: .keystroke(KeyCombo(keyCode: 8, modifiers: [.command])))
    ]
    if case .macro(let steps) = decoded, steps.count == 2 {
        check(steps[0].action == expected[0].action && steps[1] == expected[1], "Legacy macro step expands into delay + keystroke")
    } else {
        check(false, "Legacy macro step expands into delay + keystroke")
    }
} catch {
    check(false, "Legacy MacroStep decode threw: \(error)")
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
        mappings: [Mapping(trigger: wKey, action: .macro(steps: [.keystroke(f13)]))]
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

do {
    let downArrow = KeyCombo(keyCode: 125, modifiers: [])
    let first = Profile(name: "First", scope: .global, mappings: [Mapping(trigger: wKey, action: .remap(output: upArrow))])
    let second = Profile(name: "Second", scope: .global, mappings: [Mapping(trigger: wKey, action: .remap(output: downArrow))])
    let engine = MappingEngine()
    engine.rebuild(profiles: [first, second], frontmostBundleID: nil)
    if case .remap(let output) = engine.resolve(wKey) {
        check(output == upArrow, "Higher profile wins between conflicting globals")
    } else {
        check(false, "Higher profile wins between conflicting globals")
    }
    check(MappingPrecedence.overridingProfile(of: second.mappings[0], in: second, among: [first, second])?.id == first.id,
          "Overridden global mapping is reported")
    let app = Profile(name: "Game", scope: .apps(bundleIdentifiers: ["com.example.game"]), mappings: [Mapping(trigger: wKey, action: .macro(steps: [.keystroke(f13)]))])
    check(MappingPrecedence.overridingProfile(of: first.mappings[0], in: first, among: [app, first]) == nil,
          "App-scoped over global is not reported as a conflict")
}

// MARK: - MacroRunner

/// Records macro side effects instead of posting events; concurrent work runs inline.
final class RecordingPerformer: MacroPerformer {
    var events: [String] = []
    var cancelAfter: Int?
    private var token: MacroRunToken?
    private func record(_ event: String) {
        events.append(event)
        if let cancelAfter, events.count >= cancelAfter { token?.cancel() }
    }
    func press(_ combo: KeyCombo) { record("key \(combo.keyCode)") }
    func click(_ click: MouseClick) { record("click") }
    func type(_ text: String, token: MacroRunToken) { self.token = token; record("type \(text)") }
    func runShortcut(_ shortcut: ShortcutRun, token: MacroRunToken) { self.token = token; record("shortcut") }
    func scroll(_ scroll: ScrollAction) { record("scroll \(scroll.direction.rawValue) \(scroll.pixels)") }
    func openURL(_ url: URL) { record("open \(url.absoluteString)") }
    func sleep(milliseconds: Int, token: MacroRunToken) { self.token = token; record("sleep \(milliseconds)") }
    func runConcurrently(_ work: @escaping () -> Void) { work() }
}

do {
    var twice = RepeatConfig()
    twice.count = 2
    let performer = RecordingPerformer()
    MacroRunner.start([.keystroke(wKey), MacroStep(action: .repeatSteps(twice))], performer: performer)
    check(performer.events == ["key 13", "sleep 10", "key 13", "sleep 10", "key 13"],
          "Repeat re-runs the last step with the 10 ms safety pause")

    var forever = RepeatConfig()
    forever.isForever = true
    let clicker = RecordingPerformer()
    clicker.cancelAfter = 5
    MacroRunner.start([MacroStep(action: .click(MouseClick())), MacroStep(action: .repeatSteps(forever))], performer: clicker)
    check(clicker.events == ["click", "sleep 10", "click", "sleep 10", "click"], "Autoclicker repeats until stopped")

    var scroll = ScrollAction()
    scroll.direction = .up
    scroll.pixels = 240
    let web = RecordingPerformer()
    MacroRunner.start([MacroStep(action: .scroll(scroll)), MacroStep(action: .openURL("example.com"))], performer: web)
    check(web.events == ["scroll up 240", "open https://example.com"], "Scroll and open-webpage steps run")
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
