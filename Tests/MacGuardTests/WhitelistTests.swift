import XCTest
@testable import MacGuard

final class WhitelistTests: XCTestCase {

    // The three protected names must always be recognised as protected
    func testProtectedDefaultsAreProtected() {
        XCTAssertTrue(Whitelist.isProtected("kernel_task"))
        XCTAssertTrue(Whitelist.isProtected("WindowServer"))
        XCTAssertTrue(Whitelist.isProtected("launchd"))
    }

    // Ordinary process names must not be flagged as protected
    func testArbitraryNameIsNotProtected() {
        XCTAssertFalse(Whitelist.isProtected("yes"))
        XCTAssertFalse(Whitelist.isProtected("Safari"))
        XCTAssertFalse(Whitelist.isProtected(""))
    }

    // Match is case-sensitive — "KERNEL_TASK" is not protected
    func testProtectionIsCaseSensitive() {
        XCTAssertFalse(Whitelist.isProtected("KERNEL_TASK"))
        XCTAssertFalse(Whitelist.isProtected("windowserver"))
        XCTAssertFalse(Whitelist.isProtected("Launchd"))
    }

    // merging() must always include all three protected defaults regardless of input
    func testMergingAlwaysContainsProtectedDefaults() {
        let merged = Whitelist.merging(["myapp", "helper"])
        XCTAssertTrue(merged.contains("kernel_task"))
        XCTAssertTrue(merged.contains("WindowServer"))
        XCTAssertTrue(merged.contains("launchd"))
        XCTAssertTrue(merged.contains("myapp"))
        XCTAssertTrue(merged.contains("helper"))
    }

    // merging() with an empty list still produces the three defaults
    func testMergingEmptyUserList() {
        let merged = Whitelist.merging([])
        XCTAssertEqual(Set(merged), Set(Whitelist.protectedDefaults))
    }

    // Duplicates in the user list must not appear twice in the merged result
    func testMergingDeduplicates() {
        let merged = Whitelist.merging(["kernel_task", "myapp", "myapp"])
        let kernelCount = merged.filter { $0 == "kernel_task" }.count
        let myappCount  = merged.filter { $0 == "myapp" }.count
        XCTAssertEqual(kernelCount, 1)
        XCTAssertEqual(myappCount,  1)
    }
}
