import Foundation

/// The unit a delay step is shown and edited in. The delay itself is always
/// stored in milliseconds, so switching units never changes the actual timing.
public enum DelayUnit: String, Codable, Hashable, CaseIterable {
    case milliseconds
    case seconds
}

public enum MouseButton: String, Codable, Hashable, CaseIterable {
    case left, middle, right
}

/// A mouse click, at the pointer's current position or at fixed screen coordinates
/// (global display points, origin at the top-left of the main display).
public struct MouseClick: Codable, Hashable {
    public var button: MouseButton = .left
    /// 1 for a single click, 2 for a double-click.
    public var clickCount: Int = 1
    public var usesFixedPosition: Bool = false
    public var x: Double = 0
    public var y: Double = 0
    /// For fixed-position clicks: move the pointer back to where it was afterwards.
    public var returnsCursor: Bool = false

    public init() {}
}

public enum RepeatScope: String, Codable, Hashable, CaseIterable {
    /// The last `previousStepCount` steps before the repeat step (markers not counted).
    case previousSteps
    /// The steps between the markers `fromMarker` and `toMarker`.
    case betweenMarkers
}

/// Re-runs an earlier part of the macro. The part runs normally when first reached;
/// this step then runs it `count` more times (or until stopped, when `isForever`).
public struct RepeatConfig: Codable, Hashable {
    public var isForever: Bool = false
    public var count: Int = 1
    public var scope: RepeatScope = .previousSteps
    public var previousStepCount: Int = 1
    public var fromMarker: String = ""
    public var toMarker: String = ""
    /// True: the following steps run at the same time as the repeats.
    /// False: the following steps wait until the repeats finish.
    public var continuesWhileRepeating: Bool = false

    public init() {}
}

/// Runs a shortcut from the Shortcuts app, via the built-in `shortcuts` command.
public struct ShortcutRun: Codable, Hashable {
    public var name: String = ""
    public var waitsUntilFinished: Bool = true

    public init() {}
}

/// One step of a macro.
public struct MacroStep: Codable, Identifiable, Hashable {
    public enum Action: Hashable {
        case keystroke(KeyCombo)
        case delay(milliseconds: Int, unit: DelayUnit)
        case click(MouseClick)
        case typeText(String)
        /// A named position that repeat steps can refer to. Does nothing when run.
        case marker(String)
        case repeatSteps(RepeatConfig)
        case runShortcut(ShortcutRun)
    }

    public var id: UUID
    public var action: Action

    public init(id: UUID = UUID(), action: Action) {
        self.id = id
        self.action = action
    }

    public static func keystroke(_ combo: KeyCombo) -> MacroStep {
        MacroStep(action: .keystroke(combo))
    }

    public static func delay(milliseconds: Int = 0, unit: DelayUnit = .milliseconds) -> MacroStep {
        MacroStep(action: .delay(milliseconds: milliseconds, unit: unit))
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, combo, delayMs, delayUnit, click, text, marker, repeatConfig, shortcut
    }

    private enum StepType: String, Codable {
        case keystroke, delay, click, typeText, marker, repeatSteps, runShortcut
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        switch try container.decode(StepType.self, forKey: .type) {
        case .keystroke:
            action = .keystroke(try container.decode(KeyCombo.self, forKey: .combo))
        case .delay:
            action = .delay(
                milliseconds: try container.decode(Int.self, forKey: .delayMs),
                unit: try container.decodeIfPresent(DelayUnit.self, forKey: .delayUnit) ?? .milliseconds
            )
        case .click:
            action = .click(try container.decode(MouseClick.self, forKey: .click))
        case .typeText:
            action = .typeText(try container.decode(String.self, forKey: .text))
        case .marker:
            action = .marker(try container.decode(String.self, forKey: .marker))
        case .repeatSteps:
            action = .repeatSteps(try container.decode(RepeatConfig.self, forKey: .repeatConfig))
        case .runShortcut:
            action = .runShortcut(try container.decode(ShortcutRun.self, forKey: .shortcut))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        switch action {
        case .keystroke(let combo):
            try container.encode(StepType.keystroke, forKey: .type)
            try container.encode(combo, forKey: .combo)
        case .delay(let milliseconds, let unit):
            try container.encode(StepType.delay, forKey: .type)
            try container.encode(milliseconds, forKey: .delayMs)
            try container.encode(unit, forKey: .delayUnit)
        case .click(let click):
            try container.encode(StepType.click, forKey: .type)
            try container.encode(click, forKey: .click)
        case .typeText(let text):
            try container.encode(StepType.typeText, forKey: .type)
            try container.encode(text, forKey: .text)
        case .marker(let name):
            try container.encode(StepType.marker, forKey: .type)
            try container.encode(name, forKey: .marker)
        case .repeatSteps(let config):
            try container.encode(StepType.repeatSteps, forKey: .type)
            try container.encode(config, forKey: .repeatConfig)
        case .runShortcut(let shortcut):
            try container.encode(StepType.runShortcut, forKey: .type)
            try container.encode(shortcut, forKey: .shortcut)
        }
    }
}

/// Decodes one stored step into one or more `MacroStep`s. Pre-release files stored a
/// keystroke with a delay attached (`delayBeforeMs`, or earlier `delayAfterMs`); those
/// expand into a delay step followed by the keystroke step.
struct StoredMacroStep: Decodable {
    let steps: [MacroStep]

    private enum LegacyKeys: String, CodingKey {
        case type, id, combo, delayBeforeMs, delayAfterMs, delayUnit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: LegacyKeys.self)
        if container.contains(.type) {
            steps = [try MacroStep(from: decoder)]
            return
        }

        let combo = try container.decode(KeyCombo.self, forKey: .combo)
        let delay = try container.decodeIfPresent(Int.self, forKey: .delayBeforeMs)
            ?? container.decodeIfPresent(Int.self, forKey: .delayAfterMs)
            ?? 0
        let unit = try container.decodeIfPresent(DelayUnit.self, forKey: .delayUnit) ?? .milliseconds

        var expanded: [MacroStep] = []
        if delay > 0 {
            expanded.append(.delay(milliseconds: delay, unit: unit))
        }
        expanded.append(MacroStep(id: try container.decode(UUID.self, forKey: .id), action: .keystroke(combo)))
        steps = expanded
    }
}
