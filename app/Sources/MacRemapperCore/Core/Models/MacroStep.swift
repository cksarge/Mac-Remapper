import Foundation

/// One keystroke within a macro sequence, plus the delay to wait after it fires
/// before the next step (or completion) proceeds.
public struct MacroStep: Codable, Identifiable, Hashable {
    public var id: UUID
    public var combo: KeyCombo
    public var delayAfterMs: Int

    public init(id: UUID = UUID(), combo: KeyCombo, delayAfterMs: Int = 50) {
        self.id = id
        self.combo = combo
        self.delayAfterMs = delayAfterMs
    }
}
