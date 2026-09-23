import Foundation

public enum MappingAction: Codable, Hashable {
    case remap(output: KeyCombo)
    case macro(steps: [MacroStep])

    private enum CodingKeys: String, CodingKey {
        case type, output, steps
    }

    private enum Kind: String, Codable {
        case remap, macro
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .type)
        switch kind {
        case .remap:
            let output = try container.decode(KeyCombo.self, forKey: .output)
            self = .remap(output: output)
        case .macro:
            let steps = try container.decode([StoredMacroStep].self, forKey: .steps).flatMap(\.steps)
            self = .macro(steps: steps)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .remap(let output):
            try container.encode(Kind.remap, forKey: .type)
            try container.encode(output, forKey: .output)
        case .macro(let steps):
            try container.encode(Kind.macro, forKey: .type)
            try container.encode(steps, forKey: .steps)
        }
    }
}

/// What pressing a macro's trigger does while that macro is already running.
public enum RetriggerBehavior: String, Codable, Hashable, CaseIterable {
    case ignore
    case restart
    case runAnotherCopy
    case stop
}

/// Run-control settings for a macro mapping (unused for simple remaps).
public struct MacroOptions: Codable, Hashable {
    public var retriggerBehavior: RetriggerBehavior = .ignore
    /// A key that stops this macro while it runs; nil for none.
    public var stopKey: KeyCombo?

    public init(retriggerBehavior: RetriggerBehavior = .ignore, stopKey: KeyCombo? = nil) {
        self.retriggerBehavior = retriggerBehavior
        self.stopKey = stopKey
    }
}

/// A single trigger key/combo bound to either a simple remap or a macro sequence.
public struct Mapping: Codable, Identifiable, Hashable {
    public var id: UUID
    public var trigger: KeyCombo
    public var action: MappingAction
    public var isEnabled: Bool
    public var macroOptions: MacroOptions

    public init(id: UUID = UUID(), trigger: KeyCombo, action: MappingAction, isEnabled: Bool = true,
                macroOptions: MacroOptions = MacroOptions()) {
        self.id = id
        self.trigger = trigger
        self.action = action
        self.isEnabled = isEnabled
        self.macroOptions = macroOptions
    }

    private enum CodingKeys: String, CodingKey {
        case id, trigger, action, isEnabled, macroOptions
    }

    /// Mappings saved before `macroOptions` existed decode with the defaults.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        trigger = try container.decode(KeyCombo.self, forKey: .trigger)
        action = try container.decode(MappingAction.self, forKey: .action)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        macroOptions = try container.decodeIfPresent(MacroOptions.self, forKey: .macroOptions) ?? MacroOptions()
    }
}
