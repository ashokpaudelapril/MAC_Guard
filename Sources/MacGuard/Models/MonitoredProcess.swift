import Foundation

// TASK: Value type representing a single process sample returned by ps.
// HOW CODE SOLVES: Struct satisfies Identifiable using pid as the stable identity so SwiftUI
//                  List can track the same process across polls without creating new UUIDs on
//                  every sample. Equatable synthesis covers all stored fields; pid equality
//                  is the primary discriminator since it matches Identifiable.id.
//                  Named MonitoredProcess (not ProcessInfo) to avoid collision with
//                  Foundation.ProcessInfo — the built-in class for querying the running
//                  process's own metadata (BUG-S01 fix).
struct MonitoredProcess: Identifiable, Equatable {
    var id: pid_t { pid }
    let pid: pid_t
    let name: String
    var cpuPercent: Double
    var memoryMB: Double
    var spikeDuration: TimeInterval
}

// TASK: Classify overall CPU health for menu-bar icon colour coding.
// HOW CODE SOLVES: Three cases map to the three icon tints (green / orange / red).
//                  Computed by ProcessMonitor.overallLevel(_:) and forwarded via onUpdate.
enum CPULevel { case normal, warning, critical }
