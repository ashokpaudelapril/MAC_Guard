// swift-tools-version:5.9
import PackageDescription

// TASK: SPM manifest for MacGuard, a macOS 13+ menu-bar app built with Swift Package Manager.
// HOW CODE SOLVES: Declares a single executable target named `MacGuard` rooted at
//                  Sources/MacGuard. The Resources/ folder lives INSIDE the target's path
//                  (per BUG-S07 in docs/BUGS.md) so SPM can resolve `.process("Resources")`
//                  when icon assets are added in Week 3. The resources directive itself is
//                  intentionally omitted until Week 3 to keep the Week 1 build clean — an
//                  empty Resources/ directory under `.process` would emit warnings.
//                  The test target is omitted until Week 2 when the first XCTest file
//                  (ParseLineTests) lands.
let package = Package(
    name: "MacGuard",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MacGuard",
            path: "Sources/MacGuard"
            // resources: [.process("Resources")] // ← enabled in Week 3 with menu-bar icons
        )
        // .testTarget(name: "MacGuardTests", dependencies: ["MacGuard"], path: "Tests/MacGuardTests")
        // ← enabled in Week 2 once Tests/MacGuardTests/ParseLineTests.swift exists
    ]
)
