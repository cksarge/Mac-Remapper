import Foundation
import CoreGraphics
import Combine

/// Central coordinator: owns the profile store, permission state, event tap,
/// frontmost-app monitor, and mapping engine, and wires them together.
public final class AppState: ObservableObject {
    @Published public var isRemappingEnabled: Bool = true {
        didSet { updateTapState() }
    }
    @Published public private(set) var activeProfileNames: [String] = []

    public let profileStore: ProfileStore
    public let accessibilityPermission: AccessibilityPermission
    public let launchAtLogin: LaunchAtLoginManager

    private let eventTap = EventTapManager()
    private let frontmostAppMonitor = FrontmostAppMonitor()
    private let mappingEngine = MappingEngine()

    private var cancellables: Set<AnyCancellable> = []

    /// Trigger keycodes currently mid-macro, so their matching keyUp is also
    /// swallowed instead of leaking a keystroke for a key the OS never saw keyDown for.
    private var swallowedKeyUpCodes: Set<UInt16> = []

    public init() {
        profileStore = ProfileStore()
        accessibilityPermission = AccessibilityPermission()
        launchAtLogin = LaunchAtLoginManager()

        eventTap.onKeyEvent = { [weak self] event, type in
            self?.handle(event: event, type: type)
        }

        frontmostAppMonitor.onChange = { [weak self] _ in
            self?.rebuildEngine()
        }

        profileStore.$profiles
            .sink { [weak self] _ in self?.rebuildEngine() }
            .store(in: &cancellables)

        accessibilityPermission.$isTrusted
            .sink { [weak self] _ in self?.updateTapState() }
            .store(in: &cancellables)

        rebuildEngine()
        updateTapState()
    }

    private func updateTapState() {
        if isRemappingEnabled && accessibilityPermission.isTrusted {
            eventTap.start()
        } else {
            eventTap.stop()
        }
    }

    private func rebuildEngine() {
        mappingEngine.rebuild(profiles: profileStore.profiles, frontmostBundleID: frontmostAppMonitor.frontmostBundleID)

        let bundleID = frontmostAppMonitor.frontmostBundleID
        let names = profileStore.profiles
            .filter { $0.isEnabled && $0.scope.matches(bundleIdentifier: bundleID) }
            .map(\.name)
        activeProfileNames = names
    }

    // MARK: - Tap callback

    private func handle(event: CGEvent, type: CGEventType) -> CGEvent? {
        switch type {
        case .keyDown, .keyUp:
            return handleStandardKey(event: event, type: type)
        case .flagsChanged:
            return handleModifierKey(event: event)
        default:
            return event
        }
    }

    private func handleStandardKey(event: CGEvent, type: CGEventType) -> CGEvent? {
        let keyCode = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))

        if type == .keyUp, swallowedKeyUpCodes.contains(keyCode) {
            swallowedKeyUpCodes.remove(keyCode)
            return nil
        }

        let combo = KeyCombo(keyCode: keyCode, modifiers: ModifierFlags(cgEventFlags: event.flags))

        switch mappingEngine.resolve(combo) {
        case .passthrough:
            return event

        case .remap(let output):
            event.setIntegerValueField(.keyboardEventKeycode, value: Int64(output.keyCode))
            event.flags = output.modifiers.cgEventFlags
            return event

        case .macro(let steps):
            if type == .keyDown {
                swallowedKeyUpCodes.insert(keyCode)
                EventSynthesizer.runMacro(steps)
            }
            return nil
        }
    }

    private func handleModifierKey(event: CGEvent) -> CGEvent? {
        let keyCode = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
        let combo = KeyCombo(keyCode: keyCode, modifiers: [])

        guard case .remap(let output) = mappingEngine.resolve(combo) else {
            return event
        }

        // Modifier-to-modifier remap: swap both the reported keycode and the
        // corresponding CGEventFlags bit, preserving press/release direction.
        guard let originalMask = KeyCodeTable.modifierMask(for: keyCode),
              let outputMask = KeyCodeTable.modifierMask(for: output.keyCode) else {
            return event
        }

        let isPressed = event.flags.contains(originalMask)
        var flags = event.flags
        flags.remove(originalMask)
        if isPressed {
            flags.insert(outputMask)
        } else {
            flags.remove(outputMask)
        }

        event.setIntegerValueField(.keyboardEventKeycode, value: Int64(output.keyCode))
        event.flags = flags
        return event
    }
}
