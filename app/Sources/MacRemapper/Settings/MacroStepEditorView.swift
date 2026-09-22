import SwiftUI
import MacRemapperCore

struct MacroStepEditorView: View {
    @Binding var steps: [MacroStep]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if steps.isEmpty {
                Text("No steps yet — add one below.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            ForEach($steps) { $step in
                let index = steps.firstIndex(where: { $0.id == step.id }) ?? 0
                HStack {
                    Text("\(index + 1).")
                        .foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .trailing)

                    KeyCaptureView(combo: Binding(
                        get: { step.combo },
                        set: { if let newValue = $0 { step.combo = newValue } }
                    ))

                    Stepper(value: $step.delayAfterMs, in: 0...5000, step: 25) {
                        Text("Delay after: \(step.delayAfterMs) ms")
                    }
                    .frame(width: 220)

                    Button {
                        moveStep(at: index, by: -1)
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .buttonStyle(.plain)
                    .disabled(index == 0)

                    Button {
                        moveStep(at: index, by: 1)
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .buttonStyle(.plain)
                    .disabled(index == steps.count - 1)

                    Button {
                        steps.removeAll { $0.id == step.id }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }

            Button {
                steps.append(MacroStep(combo: .unset))
            } label: {
                Label("Add Step", systemImage: "plus")
            }
        }
    }

    private func moveStep(at index: Int, by offset: Int) {
        let target = index + offset
        guard steps.indices.contains(target) else { return }
        steps.swapAt(index, target)
    }
}
