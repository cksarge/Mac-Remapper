import Foundation
import CoreGraphics
import Combine
import AppKit

/// An enabled profile as shown in the menu bar, and whether it applies to the current app.
public struct ProfileStatus: Identifiable, Equatable {
    public let id: Profile.ID
    public let name: String
    public let scope: ProfileScope
    public let isActive: Bool
}

/// Central coordinator: owns the profile store, permission state, event tap,
/// frontmost-app monitor, and mapping engine, and wires them together.
public final class AppState: ObservableObject {
    @Published public var isRemappingEnabled: Bool = true {
        didSet { updateTapState() }
    }
    @Published public private(set) var profileStatuses: [ProfileStatus] = []
    @Published public private(set) var hasRunningMacros = false

    public let profileStore: ProfileStore
    public let accessibilityPermission: AccessibilityPermission
    public let launchAtLogin: LaunchAtLoginManager

    private let eventTap = EventTapManager()
    private let frontmostAppMonitor = FrontmostAppMonitor()
    private let mappingEngine = MappingEngine()
    private let macroPerformer = SystemMacroPerformer()

    /// One in-progress run of a macro. Only touched on the main thread.
    private struct RunningMacro {
        let runID: UUID
        let mappingID: Mapping.ID
        let stopKey: KeyCombo?
        let token: MacroRunToken
    }
    private var runningMacros: [RunningMacro] = []

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
            guard let self else { return }
            self.rebuildEngine(profiles: self.profileStore.profiles)
        }

        // @Published emits in willSet, before the property holds the new value, so these
        // sinks must use the emitted value rather than re-reading the property.
        profileStore.$profiles
            .sink { [weak self] profiles in self?.rebuildEngine(profiles: profiles) }
            .store(in: &cancellables)

        accessibilityPermission.$isTrusted
            .sink { [weak self] trusted in
                // Views observe AppState, not the nested permission object, so relay the change.
                self?.objectWillChange.send()
                self?.updateTapState(isTrusted: trusted)
            }
            .store(in: &cancellables)

        // Flush the debounced save so an edit made just before quitting isn't lost.
        NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in self?.profileStore.saveNow() }
            .store(in: &cancellables)
    }

    private func updateTapState(isTrusted: Bool? = nil) {
        if isRemappingEnabled && (isTrusted ?? accessibilityPermission.isTrusted) {
            eventTap.start()
        } else {
            eventTap.stop()
            stopAllMacros()
        }
    }

    // MARK: - Macro runs

    public func stopAllMacros() {
        cancel(runningMacros)
    }

    private func handleMacroTrigger(_ mapping: Mapping) {
        let running = runningMacros.filter { $0.mappingID == mapping.id }
        guard !running.isEmpty else {
            startMacro(mapping)
            return
        }
        switch mapping.effectiveRetriggerBehavior {
        case .ignore:
            break
        case .restart:
            cancel(running)
            startMacro(mapping)
        case .runAnotherCopy:
            startMacro(mapping)
        case .stop:
            cancel(running)
        }
    }

    private func startMacro(_ mapping: Mapping) {
        guard case .macro(let steps) = mapping.action else { return }
        let runID = UUID()
        let token = MacroRunner.start(steps, performer: macroPerformer) { [weak self] in
            // Enqueued after this call returns, so the run is always registered before removal.
            DispatchQueue.main.async { self?.removeRuns { $0.runID == runID } }
        }
        runningMacros.append(RunningMacro(runID: runID, mappingID: mapping.id,
                                          stopKey: mapping.macroOptions.stopKey, token: token))
        updateRunningFlag()
    }

    /// Stops any running macros whose stop key is `combo`; returns whether any were stopped.
    private func stopMacros(withStopKey combo: KeyCombo) -> Bool {
        let matching = runningMacros.filter { $0.stopKey == combo }
        cancel(matching)
        return !matching.isEmpty
    }

    private func cancel(_ runs: [RunningMacro]) {
        guard !runs.isEmpty else { return }
        runs.forEach { $0.token.cancel() }
        let ids = Set(runs.map(\.runID))
        removeRuns { ids.contains($0.runID) }
    }

    private func removeRuns(where shouldRemove: (RunningMacro) -> Bool) {
        runningMacros.removeAll(where: shouldRemove)
        updateRunningFlag()
    }

    private func updateRunningFlag() {
        let running = !runningMacros.isEmpty
        if running != hasRunningMacros {
            hasRunningMacros = running
        }
    }

    private func rebuildEngine(profiles: [Profile]) {
        mappingEngine.rebuild(profiles: profiles, frontmostBundleID: frontmostAppMonitor.frontmostBundleID)

        let bundleID = frontmostAppMonitor.frontmostBundleID
        profileStatuses = profiles
            .filter(\.isEnabled)
            .map { ProfileStatus(id: $0.id, name: $0.name, scope: $0.scope,
                                 isActive: $0.scope.matches(bundleIdentifier: bundleID)) }
    }

    // MARK: - Tap callback

    private func handle(event: CGEvent, type: CGEventType) -> CGEvent? {
        // Our own macro output passes straight through, so it never triggers mappings.
        if SystemMacroPerformer.isSynthetic(event) {
            return event
        }
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

        if type == .keyDown, stopMacros(withStopKey: combo) {
            swallowedKeyUpCodes.insert(keyCode)
            return nil
        }

        switch mappingEngine.resolve(combo) {
        case .passthrough:
            return event

        case .remap(let output):
            event.setIntegerValueField(.keyboardEventKeycode, value: Int64(output.keyCode))
            event.flags = output.cgEventFlags
            return event

        case .macro(let mapping):
            if type == .keyDown {
                swallowedKeyUpCodes.insert(keyCode)
                // Holding the trigger sends auto-repeat key-downs; only the real press counts.
                if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
                    handleMacroTrigger(mapping)
                }
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
