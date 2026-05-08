import XCTest
@testable import MacGuard

// TASK: Unit-test ProcessMonitor.parseLine to lock in correct parsing behaviour.
// HOW CODE SOLVES: Covers the six cases most likely to regress: a normal line, a line with
//                  leading whitespace, a process name containing spaces (the BUG-S03 scenario),
//                  a missing column (too few fields), an entirely empty line, and a line whose
//                  numeric fields are not parseable. Running `swift test` after any edit to
//                  parseLine will catch regressions before they reach the build.
final class ParseLineTests: XCTestCase {

    // Well-formed line with a single-word process name
    func testWellFormedLine() throws {
        let result = ProcessMonitor.parseLine("  456  99.9  65536 yes")
        let p = try XCTUnwrap(result, "Expected a MonitoredProcess for a valid line")
        XCTAssertEqual(p.pid, 456)
        XCTAssertEqual(p.cpuPercent, 99.9, accuracy: 0.001)
        XCTAssertEqual(p.memoryMB, 65536.0 / 1024.0, accuracy: 0.001)
        XCTAssertEqual(p.name, "yes")
    }

    // Leading/trailing whitespace is trimmed before parsing
    func testLeadingWhitespace() throws {
        let result = ProcessMonitor.parseLine("    1   0.0   4096 launchd")
        let p = try XCTUnwrap(result)
        XCTAssertEqual(p.pid, 1)
        XCTAssertEqual(p.name, "launchd")
    }

    // Process name containing spaces must be preserved intact (BUG-S03 regression guard)
    func testProcessNameWithSpaces() throws {
        let result = ProcessMonitor.parseLine("  789   2.3  1024 Google Chrome Helper (Renderer)")
        let p = try XCTUnwrap(result, "Expected a MonitoredProcess for a name with spaces")
        XCTAssertEqual(p.pid, 789)
        XCTAssertEqual(p.name, "Google Chrome Helper (Renderer)")
    }

    // A line with only three columns (no comm field) must be rejected
    func testMissingCommField() {
        let result = ProcessMonitor.parseLine("  123   0.5  4096")
        XCTAssertNil(result, "A line with fewer than 4 tokens should return nil")
    }

    // Empty and whitespace-only lines must be rejected without crashing
    func testEmptyLine() {
        XCTAssertNil(ProcessMonitor.parseLine(""))
        XCTAssertNil(ProcessMonitor.parseLine("   "))
    }

    // Non-numeric PID or CPU fields must be rejected
    func testMalformedNumericFields() {
        XCTAssertNil(ProcessMonitor.parseLine("  abc   0.5  4096 Safari"),
                     "Non-numeric PID should return nil")
        XCTAssertNil(ProcessMonitor.parseLine("  123   xyz  4096 Safari"),
                     "Non-numeric CPU% should return nil")
    }
}
