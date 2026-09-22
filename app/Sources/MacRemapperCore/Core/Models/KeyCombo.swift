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
        self.modifiers = modifiers
    }

    /// Placeholder for "no key captured yet" — see `KeyCodeTable.unsetKeyCode`.
    public static let unset = KeyCombo(keyCode: KeyCodeTable.unsetKeyCode, modifiers: [])

    public var displayString: String {
        let keyName = KeyCodeTable.name(for: keyCode)
        return modifiers.displaySymbols + keyName
    }
}
