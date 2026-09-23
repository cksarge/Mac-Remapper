import Testing
@testable import MacRemapperCore

struct AppVersionTests {
    @Test func comparesNumericallyNotAlphabetically() {
        #expect(AppVersion.isVersion("1.0.10", newerThan: "1.0.9"))
        #expect(AppVersion.isVersion("v1.0.1", newerThan: "1.0.0"))
        #expect(AppVersion.isVersion("2", newerThan: "1.9.9"))
    }

    @Test func equalOrOlderIsNotNewer() {
        #expect(!AppVersion.isVersion("v1.0.1", newerThan: "1.0.1"))
        #expect(!AppVersion.isVersion("1.1", newerThan: "1.1.0"))
        #expect(!AppVersion.isVersion("1.0.0", newerThan: "1.0.1"))
        #expect(!AppVersion.isVersion("1.2.0-beta", newerThan: "1.2.0"))
    }
}
