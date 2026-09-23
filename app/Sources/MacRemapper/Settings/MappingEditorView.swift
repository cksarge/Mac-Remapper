import SwiftUI
import MacRemapperCore

struct MappingEditorView: View {
    @Binding var mapping: Mapping

    private enum Kind: String, CaseIterable, Identifiable {
        case remap = "Simple Remap"
        case macro = "Macro"
        var id: String { rawValue }
    }

    private var kind: Binding<Kind> {
        Binding(
            get: {
                if case .macro = mapping.action { return .macro }
                return .remap
            },
            set: { newKind in
                switch newKind {
                case .remap:
                    mapping.action = .remap(output: .unset)
                case .macro:
                    mapping.action = .macro(steps: [])
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Enabled", isOn: $mapping.isEnabled)

            HStack {
                Text("Trigger Key")
                Spacer()
                KeyCaptureView(combo: Binding(
                    get: { mapping.trigger },
                    set: { if let newValue = $0 { mapping.trigger = newValue } }
                ))
            }

            Picker("Action Type", selection: kind) {
                ForEach(Kind.allCases) { k in
                    Text(k.rawValue).tag(k)
                }
            }
            .pickerStyle(.segmented)

            switch mapping.action {
            case .remap:
                HStack {
                    Text("Output Key")
                    Spacer()
                    KeyCaptureView(combo: Binding(
                        get: {
                            if case .remap(let output) = mapping.action { return output }
                            return nil
                        },
                        set: { newValue in
                            if let newValue { mapping.action = .remap(output: newValue) }
                        }
                    ))
                }
            case .macro:
                VStack(alignment: .leading, spacing: 6) {
                    Text("Macro Steps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    MacroStepEditorView(steps: Binding(
                        get: {
                            if case .macro(let steps) = mapping.action { return steps }
                            return []
                        },
                        set: { mapping.action = .macro(steps: $0) }
                    ))
                }

                Divider()

                macroRunOptions
            }
        }
        .padding(.vertical, 6)
    }

    private var macroRunOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Pressing the trigger while it's running", selection: $mapping.macroOptions.retriggerBehavior) {
                Text("Does nothing").tag(RetriggerBehavior.ignore)
                Text("Restarts it").tag(RetriggerBehavior.restart)
                Text("Runs another copy").tag(RetriggerBehavior.runAnotherCopy)
                Text("Stops it").tag(RetriggerBehavior.stop)
            }

            HStack {
                Text("Stop key")
                Spacer()
                KeyCaptureView(combo: $mapping.macroOptions.stopKey, placeholder: "None")
                if mapping.macroOptions.stopKey != nil {
                    Button {
                        mapping.macroOptions.stopKey = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Remove stop key")
                }
            }

            if let note = runOptionsNote {
                Label(note, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var runOptionsNote: String? {
        if mapping.effectiveRetriggerBehavior != mapping.macroOptions.retriggerBehavior {
            return "This macro repeats forever, so pressing its trigger again always stops it. Set a stop key to choose something else."
        }
        if let stopKey = mapping.macroOptions.stopKey, stopKey == mapping.trigger {
            return "The stop key is the same as the trigger, so pressing it while the macro runs stops it."
        }
        return nil
    }
}
