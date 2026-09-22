import Testing
import Foundation
@testable import MacRemapperCore

struct ProfileStoreTests {
    @Test func saveAndReloadRoundTrips() {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacRemapperTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let store = ProfileStore(directory: tempDirectory)
        let profile = Profile(
            name: "Test Profile",
            scope: .global,
            mappings: [Mapping(trigger: KeyCombo(keyCode: 13, modifiers: []), action: .remap(output: KeyCombo(keyCode: 126, modifiers: [])))]
        )
        store.profiles = [profile]
        store.saveNow()

        let reloaded = ProfileStore(directory: tempDirectory)
        #expect(reloaded.profiles == [profile])
    }

    @Test func missingFileStartsEmpty() {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacRemapperTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let store = ProfileStore(directory: tempDirectory)
        #expect(store.profiles.isEmpty)
    }
}
