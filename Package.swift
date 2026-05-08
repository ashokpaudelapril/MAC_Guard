// swift-tools-version:5.9
import PackageDescription

// TASK: SPM manifest for MacGuard, a macOS 13+ menu-bar app built with Swift Package Manager.
// HOW CODE SOLVES: Executable target rooted at Sources/MacGuard. Resources/ lives inside the
//                  target path (BUG-S07 fix — spec had it at the project root). Resources
//                  directive remains commented out until Week 3 when icon assets land. Test
//                  target enabled in Week 2 once ParseLineTests.swift exists.
let package = Package(
    name: "MacGuard",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MacGuard",
            path: "Sources/MacGuard"
            // resources: [.process("Resources")] // ← enabled in Week 3 with menu-bar icons
        ),
        .testTarget(
            name: "MacGuardTests",
            dependencies: [.target(name: "MacGuard")],
            path: "Tests/MacGuardTests"
        )
    ]
)
