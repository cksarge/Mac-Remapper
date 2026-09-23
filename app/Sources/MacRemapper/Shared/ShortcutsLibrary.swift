import Foundation

/// The names of the user's shortcuts in the Shortcuts app, read via the built-in
/// `shortcuts list` command (no special entitlement or developer account needed).
final class ShortcutsLibrary: ObservableObject {
    static let shared = ShortcutsLibrary()

    @Published private(set) var names: [String] = []
    private var hasLoaded = false

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        reload()
    }

    func reload() {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["list"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            guard (try? process.run()) != nil else { return }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            let names = String(decoding: data, as: UTF8.self)
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            DispatchQueue.main.async { self.names = names }
        }
    }
}
