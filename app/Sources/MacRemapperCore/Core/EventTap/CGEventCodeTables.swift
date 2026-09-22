import Foundation
import CoreGraphics

/// Maps between macOS virtual keycodes (CGKeyCode) and human-readable names,
/// for display in the UI (mapping list, key capture, macro step editor).
public enum KeyCodeTable {
    /// Sentinel used by the UI to represent "no key captured yet" for a new
    /// mapping/macro step. Not a real macOS virtual keycode (those run 0–127),
    /// so it can never match a real incoming key event — an unfinished mapping
    /// is a safe no-op rather than accidentally remapping "A" (keycode 0).
    public static let unsetKeyCode: UInt16 = .max

    private static let names: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
        38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
        45: "N", 46: "M", 47: ".", 50: "`",
        36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Escape",
        55: "Command", 56: "Shift", 57: "Caps Lock", 58: "Option", 59: "Control",
        60: "Right Shift", 61: "Right Option", 62: "Right Control", 63: "Fn",
        123: "Left", 124: "Right", 125: "Down", 126: "Up",
        116: "Page Up", 121: "Page Down", 115: "Home", 119: "End",
        117: "Forward Delete",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17",
        79: "F18", 80: "F19", 90: "F20"
    ]

    public static func name(for keyCode: UInt16) -> String {
        if keyCode == unsetKeyCode { return "Not Set" }
        return names[keyCode] ?? "Key \(keyCode)"
    }

    /// True if this keycode is a pure modifier key (delivered via flagsChanged
    /// events, not keyDown/keyUp).
    public static func isModifierKey(_ keyCode: UInt16) -> Bool {
        modifierMasks[keyCode] != nil
    }

    /// The CGEventFlags bit a given modifier keycode corresponds to, used to swap
    /// the flag bit in place when remapping one modifier key to another.
    private static let modifierMasks: [UInt16: CGEventFlags] = [
        54: .maskCommand, 55: .maskCommand,
        56: .maskShift, 60: .maskShift,
        58: .maskAlternate, 61: .maskAlternate,
        59: .maskControl, 62: .maskControl,
        57: .maskAlphaShift,
        63: .maskSecondaryFn
    ]

    public static func modifierMask(for keyCode: UInt16) -> CGEventFlags? {
        modifierMasks[keyCode]
    }
}
