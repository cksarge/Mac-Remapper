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
            let steps = try container.decode([MacroStep].self, forKey: .steps)
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

/// A single trigger key/combo bound to either a simple remap or a macro sequence.
public struct Mapping: Codable, Identifiable, Hashable {
    public var id: UUID
    public var trigger: KeyCombo
    public var action: MappingAction
    public var isEnabled: Bool

    public init(id: UUID = UUID(), trigger: KeyCombo, action: MappingAction, isEnabled: Bool = true) {
        self.id = id
        self.trigger = trigger
        self.action = action
        self.isEnabled = isEnabled
    }
}
