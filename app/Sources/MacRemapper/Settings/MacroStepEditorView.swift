import SwiftUI
import MacRemapperCore

struct MacroStepEditorView: View {
    @Binding var steps: [MacroStep]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if steps.isEmpty {
                Text("No steps yet — add one below.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            ForEach($steps) { $step in
                let index = steps.firstIndex(where: { $0.id == step.id }) ?? 0
                HStack(alignment: .firstTextBaseline) {
                    Text("\(index + 1).")
                        .foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .trailing)

                    Text(StepKind(step.action).verb)
                        .fontWeight(.medium)
                        .frame(width: 62, alignment: .leading)

                    stepContent($step, index: index)

                    Spacer(minLength: 8)

                    rowButtons(for: step, at: index)
                }
            }

            Menu {
                ForEach(StepKind.allCases) { kind in
                    Button {
                        steps.append(MacroStep(action: kind.newAction))
                    } label: {
                        Label(kind.menuTitle, systemImage: kind.symbol)
                    }
                }
            } label: {
                Label("Add Step", systemImage: "plus")
            }
            .fixedSize()
        }
    }

    @ViewBuilder
    private func stepContent(_ step: Binding<MacroStep>, index: Int) -> some View {
        switch step.wrappedValue.action {
        // Each binding reads the step's *current* value (not the value captured when the row was
        // drawn), so several edits in a row, like Pick… setting x then y, don't undo each other.
        case .keystroke(let combo):
            KeyCaptureView(combo: Binding(
                get: {
                    if case .keystroke(let live) = step.wrappedValue.action { return live }
                    return combo
                },
                set: { if let newValue = $0 { step.wrappedValue.action = .keystroke(newValue) } }
            ))
        case .delay:
            DelayStepView(step: step)
        case .click(let click):
            ClickStepView(click: Binding(
                get: {
                    if case .click(let live) = step.wrappedValue.action { return live }
                    return click
                },
                set: { step.wrappedValue.action = .click($0) }
            ))
        case .typeText(let text):
            TextField("Text to type", text: Binding(
                get: {
                    if case .typeText(let live) = step.wrappedValue.action { return live }
                    return text
                },
                set: { step.wrappedValue.action = .typeText($0) }
            ), prompt: Text("Text to type"))
            .labelsHidden()
            .frame(minWidth: 200)
        case .marker(let name):
            MarkerStepView(name: Binding(
                get: {
                    if case .marker(let live) = step.wrappedValue.action { return live }
                    return name
                },
                set: { step.wrappedValue.action = .marker($0) }
            ), isDuplicate: markerNames.filter { $0 == name.trimmingCharacters(in: .whitespaces) }.count > 1)
        case .repeatSteps(let config):
            RepeatStepView(config: Binding(
                get: {
                    if case .repeatSteps(let live) = step.wrappedValue.action { return live }
                    return config
                },
                set: { step.wrappedValue.action = .repeatSteps($0) }
            ), markerNames: uniqueMarkerNames, problem: MacroRunner.repeatProblem(forStepAt: index, in: steps))
        case .runShortcut(let shortcut):
            ShortcutStepView(shortcut: Binding(
                get: {
                    if case .runShortcut(let live) = step.wrappedValue.action { return live }
                    return shortcut
                },
                set: { step.wrappedValue.action = .runShortcut($0) }
            ))
        }
    }

    private func rowButtons(for step: MacroStep, at index: Int) -> some View {
        HStack(spacing: 8) {
            Button {
                moveStep(at: index, by: -1)
            } label: {
                Image(systemName: "chevron.up")
            }
            .disabled(index == 0)

            Button {
                moveStep(at: index, by: 1)
            } label: {
                Image(systemName: "chevron.down")
            }
            .disabled(index == steps.count - 1)

            Button {
                steps.removeAll { $0.id == step.id }
            } label: {
                Image(systemName: "minus.circle.fill")
            }
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    private var markerNames: [String] {
        steps.compactMap { step in
            if case .marker(let name) = step.action {
                let trimmed = name.trimmingCharacters(in: .whitespaces)
                return trimmed.isEmpty ? nil : trimmed
            }
            return nil
        }
    }

    private var uniqueMarkerNames: [String] {
        var seen = Set<String>()
        return markerNames.filter { seen.insert($0).inserted }
    }

    private func moveStep(at index: Int, by offset: Int) {
        let target = index + offset
        guard steps.indices.contains(target) else { return }
        steps.swapAt(index, target)
    }
}

/// The kinds of step the editor can add, with their labels and starting values.
private enum StepKind: CaseIterable, Identifiable {
    case keystroke, delay, click, typeText, marker, repeatSteps, runShortcut

    init(_ action: MacroStep.Action) {
        switch action {
        case .keystroke: self = .keystroke
        case .delay: self = .delay
        case .click: self = .click
        case .typeText: self = .typeText
        case .marker: self = .marker
        case .repeatSteps: self = .repeatSteps
        case .runShortcut: self = .runShortcut
        }
    }

    var id: Self { self }

    /// Short label shown at the start of each step row.
    var verb: String {
        switch self {
        case .keystroke: return "Press"
        case .delay: return "Wait"
        case .click: return "Click"
        case .typeText: return "Type"
        case .marker: return "Marker"
        case .repeatSteps: return "Repeat"
        case .runShortcut: return "Shortcut"
        }
    }

    var menuTitle: String {
        switch self {
        case .keystroke: return "Keystroke"
        case .delay: return "Delay"
        case .click: return "Mouse Click"
        case .typeText: return "Type Text"
        case .marker: return "Marker"
        case .repeatSteps: return "Repeat"
        case .runShortcut: return "Run Shortcut"
        }
    }

    var symbol: String {
        switch self {
        case .keystroke: return "keyboard"
        case .delay: return "timer"
        case .click: return "cursorarrow.click"
        case .typeText: return "character.cursor.ibeam"
        case .marker: return "flag"
        case .repeatSteps: return "repeat"
        case .runShortcut: return "square.stack.3d.up"
        }
    }

    var newAction: MacroStep.Action {
        switch self {
        case .keystroke: return .keystroke(.unset)
        case .delay: return .delay(milliseconds: 0, unit: .milliseconds)
        case .click: return .click(MouseClick())
        case .typeText: return .typeText("")
        case .marker: return .marker("")
        case .repeatSteps: return .repeatSteps(RepeatConfig())
        case .runShortcut: return .runShortcut(ShortcutRun())
        }
    }
}

// MARK: - Step views

/// Delay value (typed or stepped) with a ms/s unit picker.
private struct DelayStepView: View {
    @Binding var step: MacroStep

    private static let rangeMs = 0...60_000

    var body: some View {
        HStack(spacing: 6) {
            // Fixed width so the controls after it never shift as the value changes.
            TextField("Delay", value: valueInUnit, format: .number.precision(.fractionLength(0...3)))
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: 64)
            Stepper("Delay", value: milliseconds, in: Self.rangeMs, step: unit.wrappedValue == .seconds ? 500 : 25)
                .labelsHidden()
            Picker("Unit", selection: unit) {
                Text("ms").tag(DelayUnit.milliseconds)
                Text("s").tag(DelayUnit.seconds)
            }
            .labelsHidden()
            .fixedSize()
        }
    }

    private var milliseconds: Binding<Int> {
        Binding(
            get: {
                if case .delay(let milliseconds, _) = step.action { return milliseconds }
                return 0
            },
            set: { newValue in
                guard case .delay(_, let unit) = step.action else { return }
                let clamped = min(max(newValue, Self.rangeMs.lowerBound), Self.rangeMs.upperBound)
                step.action = .delay(milliseconds: clamped, unit: unit)
            }
        )
    }

    private var unit: Binding<DelayUnit> {
        Binding(
            get: {
                if case .delay(_, let unit) = step.action { return unit }
                return .milliseconds
            },
            set: { newUnit in
                guard case .delay(let milliseconds, _) = step.action else { return }
                step.action = .delay(milliseconds: milliseconds, unit: newUnit)
            }
        )
    }

    /// The delay in its chosen unit, for the text field; typed values convert back to ms.
    private var valueInUnit: Binding<Double> {
        let isSeconds = unit.wrappedValue == .seconds
        return Binding(
            get: { isSeconds ? Double(milliseconds.wrappedValue) / 1000 : Double(milliseconds.wrappedValue) },
            set: { milliseconds.wrappedValue = Int((isSeconds ? $0 * 1000 : $0).rounded()) }
        )
    }
}

private struct ClickStepView: View {
    @Binding var click: MouseClick

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Picker("Button", selection: $click.button) {
                    Text("Left").tag(MouseButton.left)
                    Text("Middle").tag(MouseButton.middle)
                    Text("Right").tag(MouseButton.right)
                }
                .labelsHidden()
                .fixedSize()

                Picker("Clicks", selection: $click.clickCount) {
                    Text("Single").tag(1)
                    Text("Double").tag(2)
                }
                .labelsHidden()
                .fixedSize()

                Picker("Position", selection: $click.usesFixedPosition) {
                    Text("at current position").tag(false)
                    Text("at x, y").tag(true)
                }
                .labelsHidden()
                .fixedSize()
            }

            if click.usesFixedPosition {
                HStack(spacing: 6) {
                    Text("x")
                    TextField("x", value: $click.x, format: .number.precision(.fractionLength(0)))
                        .labelsHidden()
                        .monospacedDigit()
                        .frame(width: 64)
                    Text("y")
                    TextField("y", value: $click.y, format: .number.precision(.fractionLength(0)))
                        .labelsHidden()
                        .monospacedDigit()
                        .frame(width: 64)
                    Button {
                        ScreenPointPicker.pick { point in
                            var picked = click
                            picked.x = point.x
                            picked.y = point.y
                            click = picked
                        }
                    } label: {
                        Label("Pick…", systemImage: "scope")
                    }
                    .help("Click anywhere on screen to use that position")
                }
                Toggle("Return cursor afterwards", isOn: $click.returnsCursor)
            }
        }
    }
}

private struct MarkerStepView: View {
    @Binding var name: String
    var isDuplicate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Marker name", text: $name, prompt: Text("Marker name, e.g. start"))
                .labelsHidden()
                .frame(width: 180)
            if isDuplicate {
                Label("Another marker has this name; repeats use the first one.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Text("A named point that Repeat steps can refer to.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct RepeatStepView: View {
    @Binding var config: RepeatConfig
    var markerNames: [String]
    var problem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Picker("What", selection: $config.scope) {
                    Text("the last").tag(RepeatScope.previousSteps)
                    Text("from marker").tag(RepeatScope.betweenMarkers)
                }
                .labelsHidden()
                .fixedSize()

                switch config.scope {
                case .previousSteps:
                    countField($config.previousStepCount, range: 1...999)
                    Text(config.previousStepCount == 1 ? "step" : "steps")
                case .betweenMarkers:
                    markerPicker($config.fromMarker)
                    Text("to")
                    markerPicker($config.toMarker)
                }
            }

            HStack(spacing: 6) {
                Picker("How many times", selection: $config.isForever) {
                    Text("again").tag(false)
                    Text("forever, until stopped").tag(true)
                }
                .labelsHidden()
                .fixedSize()

                if !config.isForever {
                    countField($config.count, range: 1...100_000)
                    Text(config.count == 1 ? "more time" : "more times")
                }
            }

            Picker("Then", selection: $config.continuesWhileRepeating) {
                Text("then continue with the next steps").tag(false)
                Text("and continue with the next steps meanwhile").tag(true)
            }
            .labelsHidden()
            .fixedSize()

            if let problem {
                Label(problem, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func countField(_ value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack(spacing: 4) {
            TextField("Count", value: Binding(
                get: { value.wrappedValue },
                set: { value.wrappedValue = min(max($0, range.lowerBound), range.upperBound) }
            ), format: .number)
            .labelsHidden()
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .frame(width: 52)
            Stepper("Count", value: value, in: range)
                .labelsHidden()
        }
    }

    private func markerPicker(_ selection: Binding<String>) -> some View {
        Picker("Marker", selection: selection) {
            Text("Choose…").tag("")
            ForEach(markerNames, id: \.self) { name in
                Text(name).tag(name)
            }
            // Keep a stale selection visible (e.g. a renamed marker) so it isn't silently changed.
            if !selection.wrappedValue.isEmpty && !markerNames.contains(selection.wrappedValue) {
                Text("\(selection.wrappedValue) (missing)").tag(selection.wrappedValue)
            }
        }
        .labelsHidden()
        .fixedSize()
    }
}

private struct ShortcutStepView: View {
    @Binding var shortcut: ShortcutRun
    @ObservedObject private var library = ShortcutsLibrary.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if library.names.isEmpty {
                TextField("Shortcut name", text: $shortcut.name, prompt: Text("Shortcut name"))
                    .labelsHidden()
                    .frame(width: 200)
            } else {
                Picker("Shortcut", selection: $shortcut.name) {
                    Text("Choose a shortcut…").tag("")
                    ForEach(library.names, id: \.self) { name in
                        Text(name).tag(name)
                    }
                    if !shortcut.name.isEmpty && !library.names.contains(shortcut.name) {
                        Text("\(shortcut.name) (not found)").tag(shortcut.name)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
            Toggle("Wait until it finishes", isOn: $shortcut.waitsUntilFinished)
        }
        .onAppear { library.loadIfNeeded() }
    }
}
