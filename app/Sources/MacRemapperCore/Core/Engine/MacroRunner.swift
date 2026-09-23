import Foundation

/// Carries out a macro's side effects. `SystemMacroPerformer` posts real events;
/// tests substitute a recording performer.
public protocol MacroPerformer: AnyObject {
    func press(_ combo: KeyCombo)
    func click(_ click: MouseClick)
    func type(_ text: String, token: MacroRunToken)
    func runShortcut(_ shortcut: ShortcutRun, token: MacroRunToken)
    /// Waits, returning early if the token is cancelled.
    func sleep(milliseconds: Int, token: MacroRunToken)
    /// Runs work off the caller's thread (a macro run, or a repeat that continues in the background).
    func runConcurrently(_ work: @escaping () -> Void)
}

/// Cancellation and completion tracking for one run of a macro, shared by every thread that
/// run spawns (repeats that continue in the background), so stopping it stops all of them.
public final class MacroRunToken {
    private let lock = NSLock()
    private var cancelled = false
    private var activeWork = 0
    private let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    public var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    public func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    func beginWork() {
        lock.lock()
        activeWork += 1
        lock.unlock()
    }

    /// Calls `onFinish` once the last piece of work for this run ends.
    func endWork() {
        lock.lock()
        activeWork -= 1
        let finished = activeWork == 0
        lock.unlock()
        if finished { onFinish() }
    }
}

public enum MacroRunner {
    /// Pause between repeats when the repeated steps contain no delay above 0,
    /// so a tight repeat (e.g. an autoclicker) can't flood the system.
    public static let minimumRepeatIntervalMs = 10
    /// Guards against repeats whose ranges contain each other recursing forever.
    static let maxRepeatNesting = 16

    /// Starts running `steps` in the background. `onFinish` is called (on a background thread)
    /// when the run and everything it spawned has ended, whether it completed or was cancelled.
    @discardableResult
    public static func start(_ steps: [MacroStep], performer: MacroPerformer,
                             onFinish: @escaping () -> Void = {}) -> MacroRunToken {
        let token = MacroRunToken(onFinish: onFinish)
        token.beginWork()
        performer.runConcurrently {
            Interpreter(steps: steps, performer: performer, token: token).execute(steps.indices, depth: 0)
            token.endWork()
        }
        return token
    }

    /// The steps a repeat step at `index` re-runs, or nil if its range is invalid.
    public static func repeatRange(forStepAt index: Int, in steps: [MacroStep]) -> Range<Int>? {
        repeatRangeResult(forStepAt: index, in: steps).range
    }

    /// Why a repeat step's range is invalid, for display in the editor; nil if it's valid.
    public static func repeatProblem(forStepAt index: Int, in steps: [MacroStep]) -> String? {
        repeatRangeResult(forStepAt: index, in: steps).problem
    }

    /// Whether any repeat step in the macro repeats forever (so it must be stoppable).
    public static func containsInfiniteRepeat(_ steps: [MacroStep]) -> Bool {
        steps.contains { step in
            if case .repeatSteps(let config) = step.action { return config.isForever }
            return false
        }
    }

    private static func repeatRangeResult(forStepAt index: Int, in steps: [MacroStep]) -> (range: Range<Int>?, problem: String?) {
        guard steps.indices.contains(index), case .repeatSteps(let config) = steps[index].action else {
            return (nil, "Not a repeat step.")
        }

        switch config.scope {
        case .previousSteps:
            guard config.previousStepCount >= 1 else { return (nil, "Repeat at least 1 step.") }
            var start = index
            var counted = 0
            while start > 0 && counted < config.previousStepCount {
                start -= 1
                if case .marker = steps[start].action { continue }
                counted += 1
            }
            guard counted > 0 else { return (nil, "There are no steps before this one to repeat.") }
            return (start..<index, nil)

        case .betweenMarkers:
            let from = config.fromMarker.trimmingCharacters(in: .whitespaces)
            let to = config.toMarker.trimmingCharacters(in: .whitespaces)
            guard !from.isEmpty, !to.isEmpty else { return (nil, "Choose a start and end marker.") }
            guard let fromIndex = markerIndex(named: from, in: steps) else { return (nil, "No marker named “\(from)”.") }
            guard let toIndex = markerIndex(named: to, in: steps) else { return (nil, "No marker named “\(to)”.") }
            guard fromIndex < toIndex else { return (nil, "“\(from)” must come before “\(to)”.") }
            guard !(fromIndex...toIndex).contains(index) else {
                return (nil, "A repeat can't be inside the range it repeats.")
            }
            guard toIndex - fromIndex > 1 else { return (nil, "There are no steps between the markers.") }
            return ((fromIndex + 1)..<toIndex, nil)
        }
    }

    private static func markerIndex(named name: String, in steps: [MacroStep]) -> Int? {
        steps.firstIndex { step in
            if case .marker(let markerName) = step.action {
                return markerName.trimmingCharacters(in: .whitespaces) == name
            }
            return false
        }
    }

    private struct Interpreter {
        let steps: [MacroStep]
        let performer: MacroPerformer
        let token: MacroRunToken

        func execute(_ range: Range<Int>, depth: Int) {
            for index in range {
                if token.isCancelled { return }
                switch steps[index].action {
                case .keystroke(let combo):
                    performer.press(combo)
                case .delay(let milliseconds, _):
                    if milliseconds > 0 { performer.sleep(milliseconds: milliseconds, token: token) }
                case .click(let click):
                    performer.click(click)
                case .typeText(let text):
                    performer.type(text, token: token)
                case .marker:
                    break
                case .runShortcut(let shortcut):
                    performer.runShortcut(shortcut, token: token)
                case .repeatSteps(let config):
                    guard depth < MacroRunner.maxRepeatNesting,
                          let block = MacroRunner.repeatRange(forStepAt: index, in: steps) else { continue }
                    if config.continuesWhileRepeating {
                        token.beginWork()
                        performer.runConcurrently {
                            repeatBlock(block, config: config, depth: depth + 1)
                            token.endWork()
                        }
                    } else {
                        repeatBlock(block, config: config, depth: depth + 1)
                    }
                }
            }
        }

        private func repeatBlock(_ block: Range<Int>, config: RepeatConfig, depth: Int) {
            let hasPositiveDelay = steps[block].contains { step in
                if case .delay(let milliseconds, _) = step.action { return milliseconds > 0 }
                return false
            }
            var completed = 0
            while !token.isCancelled && (config.isForever || completed < config.count) {
                if !hasPositiveDelay {
                    performer.sleep(milliseconds: MacroRunner.minimumRepeatIntervalMs, token: token)
                    if token.isCancelled { return }
                }
                execute(block, depth: depth)
                completed += 1
            }
        }
    }
}

extension Mapping {
    /// The retrigger behavior actually used: a macro that repeats forever with no stop key
    /// always stops when its trigger is pressed again, so it can never be left unstoppable.
    public var effectiveRetriggerBehavior: RetriggerBehavior {
        if case .macro(let steps) = action, MacroRunner.containsInfiniteRepeat(steps), macroOptions.stopKey == nil {
            return .stop
        }
        return macroOptions.retriggerBehavior
    }
}
