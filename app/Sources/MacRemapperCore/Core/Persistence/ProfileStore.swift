import Foundation
import Combine

/// Loads/saves the user's profiles as JSON under Application Support.
/// Writes are debounced so rapid edits (e.g. typing a profile name) don't
/// each trigger a disk write.
public final class ProfileStore: ObservableObject {
    @Published public var profiles: [Profile] = [] {
        didSet { scheduleSave() }
    }

    private let fileURL: URL
    private var saveWorkItem: DispatchWorkItem?
    private let saveDebounceInterval: TimeInterval = 0.5

    /// When true, mutations to `profiles` don't trigger a save — used while loading.
    private var isLoading = false

    public init(directory: URL? = nil) {
        let baseDirectory = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MacRemapper", isDirectory: true)
        fileURL = baseDirectory.appendingPathComponent("profiles.json")
        load()
    }

    public func load() {
        isLoading = true
        defer { isLoading = false }

        guard let data = try? Data(contentsOf: fileURL) else {
            profiles = []
            return
        }
        guard let document = try? JSONDecoder.macRemapper.decode(ProfileDocument.self, from: data) else {
            profiles = []
            return
        }
        profiles = document.profiles
    }

    public func saveNow() {
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let document = ProfileDocument(profiles: profiles)
        guard let data = try? JSONEncoder.macRemapper.encode(document) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func scheduleSave() {
        guard !isLoading else { return }
        saveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.saveNow()
        }
        saveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + saveDebounceInterval, execute: workItem)
    }
}

extension JSONEncoder {
    static var macRemapper: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        // .iso8601 (via ISO8601DateFormatter) only has whole-second precision, and
        // .secondsSince1970 doesn't round-trip bit-exactly either: Date's native
        // storage is timeIntervalSinceReferenceDate (2001 epoch), and converting to
        // the much larger-magnitude 1970-epoch value and back loses low-order
        // fractional bits. Encoding the native representation directly is exact.
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.timeIntervalSinceReferenceDate)
        }
        return encoder
    }
}

extension JSONDecoder {
    static var macRemapper: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let seconds = try container.decode(Double.self)
            return Date(timeIntervalSinceReferenceDate: seconds)
        }
        return decoder
    }
}
