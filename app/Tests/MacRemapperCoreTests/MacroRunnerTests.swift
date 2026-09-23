import Testing
import Foundation
@testable import MacRemapperCore

/// Records what a macro does instead of posting events. Work "run concurrently" runs inline,
/// so results are deterministic; `cancelAfter` cancels the run after that many recorded events.
private final class RecordingPerformer: MacroPerformer {
    var events: [String] = []
    var cancelAfter: Int?

    private func record(_ event: String, _ token: MacroRunToken?) {
        events.append(event)
        if let cancelAfter, events.count >= cancelAfter { token?.cancel() }
    }

    private var currentToken: MacroRunToken?

    func press(_ combo: KeyCombo) { record("key \(combo.keyCode)", currentToken) }
    func click(_ click: MouseClick) { record("click \(click.button.rawValue) x\(click.clickCount)", currentToken) }
    func type(_ text: String, token: MacroRunToken) { currentToken = token; record("type \(text)", token) }
    func runShortcut(_ shortcut: ShortcutRun, token: MacroRunToken) { currentToken = token; record("shortcut \(shortcut.name)", token) }
    func sleep(milliseconds: Int, token: MacroRunToken) { currentToken = token; record("sleep \(milliseconds)", token) }
    func runConcurrently(_ work: @escaping () -> Void) { work() }

    /// Runs the macro to completion, with every event able to see the run's token.
    func run(_ steps: [MacroStep]) {
        var finished = false
        let token = MacroRunner.start(steps, performer: self) { finished = true }
        currentToken = token
        #expect(finished)
    }
}

struct MacroRunnerTests {
    private let a = KeyCombo(keyCode: 0)
    private let b = KeyCombo(keyCode: 11)

    private func repeatStep(_ configure: (inout RepeatConfig) -> Void) -> MacroStep {
        var config = RepeatConfig()
        configure(&config)
        return MacroStep(action: .repeatSteps(config))
    }

    @Test func stepsRunInOrder() {
        let performer = RecordingPerformer()
        performer.run([.keystroke(a), MacroStep(action: .typeText("Hi")), .delay(milliseconds: 250), .keystroke(b)])
        #expect(performer.events == ["key 0", "type Hi", "sleep 250", "key 11"])
    }

    @Test func repeatLastStepsRunsBlockAgainWithSafetyPause() {
        let performer = RecordingPerformer()
        performer.run([.keystroke(a), .keystroke(b), repeatStep { $0.previousStepCount = 1; $0.count = 2 }])
        // The block runs normally once, then 2 more times, each after the 10 ms safety pause.
        #expect(performer.events == ["key 0", "key 11", "sleep 10", "key 11", "sleep 10", "key 11"])
    }

    @Test func positiveDelayInBlockSkipsSafetyPause() {
        let performer = RecordingPerformer()
        performer.run([.keystroke(a), .delay(milliseconds: 5), repeatStep { $0.previousStepCount = 2; $0.count = 1 }])
        #expect(performer.events == ["key 0", "sleep 5", "key 0", "sleep 5"])
    }

    @Test func repeatBetweenMarkersMatchesUserExample() {
        let performer = RecordingPerformer()
        performer.cancelAfter = 12
        performer.run([
            MacroStep(action: .marker("start")),
            .keystroke(a),
            MacroStep(action: .typeText("Hello")),
            MacroStep(action: .marker("end")),
            MacroStep(action: .typeText("Begin")),
            repeatStep {
                $0.scope = .betweenMarkers
                $0.fromMarker = "start"
                $0.toMarker = "end"
                $0.isForever = true
                $0.continuesWhileRepeating = true
            }
        ])
        #expect(Array(performer.events.prefix(9)) == [
            "key 0", "type Hello", "type Begin",
            "sleep 10", "key 0", "type Hello",
            "sleep 10", "key 0", "type Hello"
        ])
        #expect(performer.events.count == 12) // stopped by cancellation, not by running out
    }

    @Test func autoclickerRepeatsUntilStopped() {
        var click = MouseClick()
        click.button = .left
        let performer = RecordingPerformer()
        performer.cancelAfter = 7
        performer.run([MacroStep(action: .click(click)), repeatStep { $0.previousStepCount = 1; $0.isForever = true }])
        #expect(performer.events == ["click left x1", "sleep 10", "click left x1", "sleep 10", "click left x1", "sleep 10", "click left x1"])
    }

    @Test func previousStepCountSkipsMarkers() {
        let steps: [MacroStep] = [.keystroke(a), MacroStep(action: .marker("m")), .keystroke(b),
                                  repeatStep { $0.previousStepCount = 2 }]
        #expect(MacroRunner.repeatRange(forStepAt: 3, in: steps) == 0..<3)
    }

    @Test func invalidRangesAreReported() {
        let insideOwnRange: [MacroStep] = [
            MacroStep(action: .marker("s")),
            repeatStep { $0.scope = .betweenMarkers; $0.fromMarker = "s"; $0.toMarker = "e" },
            MacroStep(action: .marker("e"))
        ]
        #expect(MacroRunner.repeatRange(forStepAt: 1, in: insideOwnRange) == nil)
        #expect(MacroRunner.repeatProblem(forStepAt: 1, in: insideOwnRange) != nil)

        let missingMarker: [MacroStep] = [repeatStep { $0.scope = .betweenMarkers; $0.fromMarker = "x"; $0.toMarker = "y" }]
        #expect(MacroRunner.repeatProblem(forStepAt: 0, in: missingMarker) == "No marker named “x”.")

        let nothingBefore: [MacroStep] = [repeatStep { $0.previousStepCount = 1 }]
        #expect(MacroRunner.repeatRange(forStepAt: 0, in: nothingBefore) == nil)
    }

    @Test func infiniteRepeatWithoutStopKeyAlwaysStopsOnRetrigger() {
        let forever: [MacroStep] = [.keystroke(a), repeatStep { $0.isForever = true }]
        var mapping = Mapping(trigger: b, action: .macro(steps: forever),
                              macroOptions: MacroOptions(retriggerBehavior: .ignore))
        #expect(mapping.effectiveRetriggerBehavior == .stop)

        mapping.macroOptions.stopKey = KeyCombo(keyCode: 53)
        #expect(mapping.effectiveRetriggerBehavior == .ignore)
    }

    @Test func newStepTypesRoundTripThroughJSON() throws {
        var click = MouseClick()
        click.button = .right
        click.clickCount = 2
        click.usesFixedPosition = true
        click.x = 120
        click.y = 45.5
        click.returnsCursor = true
        var shortcut = ShortcutRun()
        shortcut.name = "Morning"
        shortcut.waitsUntilFinished = false
        let steps: [MacroStep] = [
            MacroStep(action: .click(click)),
            MacroStep(action: .typeText("Hello 👋")),
            MacroStep(action: .marker("start")),
            repeatStep { $0.isForever = true; $0.scope = .betweenMarkers; $0.fromMarker = "start"; $0.toMarker = "end" },
            MacroStep(action: .runShortcut(shortcut))
        ]
        let mapping = Mapping(trigger: a, action: .macro(steps: steps),
                              macroOptions: MacroOptions(retriggerBehavior: .restart, stopKey: KeyCombo(keyCode: 53)))
        let data = try JSONEncoder.macRemapper.encode(mapping)
        #expect(try JSONDecoder.macRemapper.decode(Mapping.self, from: data) == mapping)
    }

    @Test func mappingWithoutMacroOptionsDecodesWithDefaults() throws {
        let json = #"{"id":"6B4CC637-EF8C-49D9-A279-B38EA0A8F9EF","trigger":{"keyCode":0,"modifiers":0},"action":{"type":"macro","steps":[]},"isEnabled":true}"#
        let decoded = try JSONDecoder.macRemapper.decode(Mapping.self, from: json.data(using: .utf8)!)
        #expect(decoded.macroOptions == MacroOptions())
    }
}
