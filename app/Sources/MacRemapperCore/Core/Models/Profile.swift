import Foundation

public enum ProfileScope: Codable, Hashable {
    case global
    case apps(bundleIdentifiers: [String])

    private enum CodingKeys: String, CodingKey {
        case type, bundleIdentifiers
    }

    private enum Kind: String, Codable {
        case global, apps
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .type)
        switch kind {
        case .global:
            self = .global
        case .apps:
            let ids = try container.decode([String].self, forKey: .bundleIdentifiers)
            self = .apps(bundleIdentifiers: ids)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .global:
            try container.encode(Kind.global, forKey: .type)
        case .apps(let ids):
            try container.encode(Kind.apps, forKey: .type)
            try container.encode(ids, forKey: .bundleIdentifiers)
        }
    }

    public var isGlobal: Bool {
        if case .global = self { return true }
        return false
    }

    public func matches(bundleIdentifier: String?) -> Bool {
        switch self {
        case .global:
            return true
        case .apps(let ids):
            guard let bundleIdentifier else { return false }
            return ids.contains(bundleIdentifier)
        }
    }
}

/// A named, independently toggleable set of key mappings, active either
/// everywhere ("Global") or only while a specific set of apps is frontmost.
public struct Profile: Codable, Identifiable, Hashable {
    public var id: UUID
    public var name: String
    public var scope: ProfileScope
    public var mappings: [Mapping]
    public var isEnabled: Bool
    public var createdAt: Date
    public var modifiedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        scope: ProfileScope = .global,
        mappings: [Mapping] = [],
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.scope = scope
        self.mappings = mappings
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

/// Top-level persisted document wrapper, versioned so future releases can migrate the schema.
struct ProfileDocument: Codable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var profiles: [Profile]

    init(schemaVersion: Int = ProfileDocument.currentSchemaVersion, profiles: [Profile]) {
        self.schemaVersion = schemaVersion
        self.profiles = profiles
    }
}
