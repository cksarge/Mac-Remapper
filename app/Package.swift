// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacRemapper",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        // Pure logic: models, event tap, mapping engine, persistence. No SwiftUI
        // dependency, so it builds and tests with just the Xcode Command Line
        // Tools — no full Xcode.app required.
        .target(
            name: "MacRemapperCore",
            path: "Sources/MacRemapperCore"
        ),
        // SwiftUI UI layer. Requires full Xcode.app to compile (SwiftUI's
        // @State/@Binding property wrappers are implemented as compiler macros
        // whose plugin only ships inside Xcode, not the standalone CLT).
        .executableTarget(
            name: "MacRemapper",
            dependencies: ["MacRemapperCore"],
            path: "Sources/MacRemapper"
        ),
        .testTarget(
            name: "MacRemapperCoreTests",
            dependencies: ["MacRemapperCore"],
            path: "Tests/MacRemapperCoreTests"
        ),
        // Runs MacRemapperCore's checks without XCTest/swift-testing — see
        // Sources/CoreSmokeTest/main.swift for why. `swift run CoreSmokeTest`.
        .executableTarget(
            name: "CoreSmokeTest",
            dependencies: ["MacRemapperCore"],
            path: "Sources/CoreSmokeTest"
        )
    ]
)
