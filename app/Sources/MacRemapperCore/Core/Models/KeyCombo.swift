import Foundation
import CoreGraphics

public struct ModifierFlags: OptionSet, Codable, Hashable {
    public let rawValue: UInt8

    public static let command  = ModifierFlags(rawValue: 1 << 0)
    public static let option   = ModifierFlags(rawValue: 1 << 1)
    public static let control  = ModifierFlags(rawValue: 1 << 2)
    public static let shift    = ModifierFlags(rawValue: 1 << 3)
    public static let function = ModifierFlags(rawValue: 1 << 4)

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public init(cgEventFlags: CGEventFlags) {
        var flags: ModifierFlags = []
        if cgEventFlags.contains(.maskCommand) { flags.insert(.command) }
        if cgEventFlags.contains(.maskAlternate) { flags.insert(.option) }
        if cgEventFlags.contains(.maskControl) { flags.insert(.control) }
        if cgEventFlags.contains(.maskShift) { flags.insert(.shift) }
        if cgEventFlags.contains(.maskSecondaryFn) { flags.insert(.function) }
        self = flags
    }

    var cgEventFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if contains(.command) { flags.insert(.maskCommand) }
        if contains(.option) { flags.insert(.maskAlternate) }
        if contains(.control) { flags.insert(.maskControl) }
        if contains(.shift) { flags.insert(.maskShift) }
        if contains(.function) { flags.insert(.maskSecondaryFn) }
        return flags
    }

    /// Symbols in the conventional macOS modifier display order: ⌃⌥⇧⌘
    public var displaySymbols: String {
        var s = ""
        if contains(.control) { s += "⌃" }
        if contains(.option) { s += "⌥" }
        if contains(.shift) { s += "⇧" }
        if contains(.command) { s += "⌘" }
        if contains(.function) { s += "fn" }
        return s
    }
}

/// A single physical key plus any held modifiers, e.g. Cmd+Shift+4.
public struct KeyCombo: Codable, Hashable {
    public var keyCode: UInt16
    public var modifiers: ModifierFlags

    public init(keyCode: UInt16, modifiers: ModifierFlags = []) {
        self.keyCode = keyCode
        // The fn flag macOS stamps on arrows/F-keys isn't a real modifier: keeping it
        // would make "Up" record as fn+Up (Page Up) and never match a plain arrow press.
        var modifiers = modifiers
        if KeyCodeTable.hasImplicitFn(keyCode) {
            modifiers.remove(.function)
        }
        self.modifiers = modifiers
    }

    private enum CodingKeys: String, CodingKey {
        case keyCode, modifiers
    }

    /// Routes decoding through `init(keyCode:modifiers:)`, which also repairs combos
    /// saved before the implicit-fn flag was stripped.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            keyCode: try container.decode(UInt16.self, forKey: .keyCode),
            modifiers: try container.decode(ModifierFlags.self, forKey: .modifiers)
        )
    }

    /// Flags for posting this combo: the held modifiers plus any the key implicitly carries.
    var cgEventFlags: CGEventFlags {
        modifiers.cgEventFlags.union(KeyCodeTable.implicitFlags(for: keyCode))
    }

    /// Placeholder for "no key captured yet" — see `KeyCodeTable.unsetKeyCode`.
    public static let unset = KeyCombo(keyCode: KeyCodeTable.unsetKeyCode, modifiers: [])

    public var displayString: String {
        let keyName = KeyCodeTable.name(for: keyCode)
        return modifiers.displaySymbols + keyName
    }
}
