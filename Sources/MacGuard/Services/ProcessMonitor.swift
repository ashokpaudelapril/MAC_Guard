import Foundation
import Combine

// TASK: Poll /bin/ps every 2 s, detect sustained CPU spikes, and fire onSpike / onUpdate callbacks.
// HOW CODE SOLVES: runPS() shells out to /bin/ps on a dedicated background DispatchQueue so the
//                  main thread — and therefore the UI — is never blocked by process startup or
//                  waitUntilExit() latency (BUG-S02 fix over the spec's main-thread poll).
//                  Results are dispatched back to the main queue for @Published mutation and safe
//                  UI callback delivery. spikeCounts tracks consecutive above-threshold samples per
//                  PID; reaching spikeConfirmSamples (15 × 2 s = 30 s) fires onSpike once per PID
//                  per event. Dead PIDs are pruned after every poll to prevent unbounded dictionary
//                  growth and false alerts from recycled PIDs (BUG-S04).
final class ProcessMonitor: ObservableObject {
    @Published var processes: [MonitoredProcess] = []
    // TASK: Publish the current CPU health level so SwiftUI views can observe it directly.
    // HOW CODE SOLVES: Storing the computed level as @Published lets ContentView's header chip
    //                  react to poll results without an additional ObservableObject wrapper.
    @Published var cpuLevel: CPULevel = .normal
    var onSpike:  ((MonitoredProcess) -> Void)?
    var onUpdate: ((CPULevel) -> Void)?

    private var timer: Timer?
    private var spikeCounts:  [pid_t: Int]  = [:]
    private var alertedPIDs:  Set<pid_t>    = []
    // TASK: Rolling 60-second CPU history per PID for the sparkline graph.
    // HOW CODE SOLVES: Capped at 30 samples (30 × 2 s = 60 s). Not @Published — views
    //                  read it during the re-render triggered by the processes update, so
    //                  they always see the freshly-updated values without extra subscriptions.
    private var cpuHistories: [pid_t: [Double]] = [:]
    private let maxHistoryLength = 30
    private let settings: AppSettings
    private let spikeConfirmSamples = 15
    private let pollQueue = DispatchQueue(label: "macguard.monitor.poll", qos: .utility)

    init(settings: AppSettings) { self.settings = settings }

    func start() {
        poll()  // immediate first sample so the UI isn't blank for 2 s
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() { timer?.invalidate() }

    // TASK: Answer whether a PID is still accumulating spike samples at this moment.
    // HOW CODE SOLVES: AppDelegate checks this immediately before the auto-kill timer fires to
    //                  abort if the process already dropped below threshold on its own (BUG-S06).
    func isStillSpiking(pid: pid_t) -> Bool {
        (spikeCounts[pid] ?? 0) > 0
    }

    // TASK: Dispatch ps work to background and publish the results on the main thread.
    // HOW CODE SOLVES: runPS() is a pure static function with no instance state, so it is safe
    //                  to call from pollQueue. DispatchQueue.main.async brings results back to
    //                  the main actor for @Published mutation and UI callback delivery (BUG-S02).
    private func poll() {
        pollQueue.async { [weak self] in
            guard let self else { return }
            let raw = ProcessMonitor.runPS()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.updateHistories(raw)
                self.processes = raw
                self.detectSpikes(raw)
                self.cpuLevel = self.overallLevel(raw)
                self.onUpdate?(self.cpuLevel)
            }
        }
    }

    // TASK: Shell out to /bin/ps with hardcoded arguments and parse stdout into MonitoredProcess values.
    // HOW CODE SOLVES: executableURL is set to the literal "/bin/ps" and arguments is a literal
    //                  array — no user-supplied data ever reaches the argument list, preventing
    //                  shell injection (SECURITY.md). standardError is redirected to a throwaway
    //                  pipe so ps noise doesn't pollute our output. Static so it can be called
    //                  from a background DispatchQueue without touching @Published instance state.
    static func runPS() -> [MonitoredProcess] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments     = ["-axo", "pid=,pcpu=,rss=,comm="]
        let pipe  = Pipe()
        task.standardOutput = pipe
        task.standardError  = Pipe()  // silence ps warnings
        // ISSUE: task.waitUntilExit() internally requires an active RunLoop and hangs
        //        indefinitely when called from a background DispatchQueue thread.
        // FIX APPLIED: Set a no-op terminationHandler so Foundation reaps the child via
        //              kqueue/kevent (no RunLoop needed). readDataToEndOfFile() then blocks
        //              on a plain read() syscall until ps closes stdout on exit.
        task.terminationHandler = { _ in }
        do { try task.run() } catch { return [] }
        let data   = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return output.components(separatedBy: "\n").compactMap { parseLine($0) }
    }

    // TASK: Parse one line of `ps -axo pid=,pcpu=,rss=,comm=` output into a MonitoredProcess.
    // HOW CODE SOLVES: split(separator:maxSplits:omittingEmptySubsequences:) with maxSplits: 3
    //                  yields exactly four tokens: pid, %cpu, rss, and then the entire remainder
    //                  of the line as the comm field. This preserves process names that contain
    //                  spaces such as "Google Chrome Helper (Renderer)" — the spec's approach of
    //                  splitting on all whitespace then joining parts[3...] would re-join spaces
    //                  but then strip path components via components(separatedBy: "/"), silently
    //                  corrupting names for processes whose comm contains a slash (BUG-S03 fix).
    static func parseLine(_ line: String) -> MonitoredProcess? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
        guard parts.count == 4,
              let pid = pid_t(parts[0]),
              let cpu = Double(parts[1]),
              let rss = Double(parts[2]) else { return nil }
        let name = String(parts[3])
        return MonitoredProcess(pid: pid, name: name,
                                cpuPercent: cpu, memoryMB: rss / 1024.0, spikeDuration: 0)
    }

    private func detectSpikes(_ list: [MonitoredProcess]) {
        for p in list {
            guard !settings.whitelist.contains(p.name) else { continue }
            if p.cpuPercent >= settings.cpuThreshold {
                spikeCounts[p.pid, default: 0] += 1
                if spikeCounts[p.pid]! == spikeConfirmSamples && !alertedPIDs.contains(p.pid) {
                    alertedPIDs.insert(p.pid)
                    onSpike?(p)
                }
            } else {
                spikeCounts[p.pid] = 0
                alertedPIDs.remove(p.pid)
            }
        }
        reapDeadPIDs(in: list)
    }

    // TASK: Remove spikeCounts and alertedPIDs entries for PIDs absent from the latest ps sample.
    // HOW CODE SOLVES: Builds the live PID set, then filters both dictionaries in place so entries
    //                  for dead processes are discarded. Without this, spikeCounts grows without
    //                  bound over a long session and a recycled PID inherits the previous process's
    //                  spike counter, triggering a spurious immediate alert (BUG-S04 fix).
    private func reapDeadPIDs(in latest: [MonitoredProcess]) {
        let live = Set(latest.map(\.pid))
        spikeCounts = spikeCounts.filter { live.contains($0.key) }
        alertedPIDs = alertedPIDs.filter { live.contains($0) }
    }

    private func overallLevel(_ list: [MonitoredProcess]) -> CPULevel {
        let max = list.map(\.cpuPercent).max() ?? 0
        if max >= settings.cpuThreshold          { return .critical }
        if max >= settings.cpuThreshold * 0.7    { return .warning  }
        return .normal
    }

    // TASK: Return the last 30 CPU samples for a PID, for use by SparklineView.
    // HOW CODE SOLVES: Called from DashboardView during the render pass triggered by
    //                  processes changing — cpuHistories is always up-to-date because
    //                  updateHistories runs on main before self.processes is assigned.
    func cpuHistory(for pid: pid_t) -> [Double] {
        cpuHistories[pid] ?? []
    }

    // TASK: Append the latest CPU sample for each process and prune dead PIDs.
    // HOW CODE SOLVES: Caps each history array at maxHistoryLength so the rolling window
    //                  never grows past 60 s. Dead PID pruning runs in the same pass so
    //                  cpuHistories and spikeCounts stay in sync without a second loop.
    private func updateHistories(_ list: [MonitoredProcess]) {
        let live = Set(list.map(\.pid))
        cpuHistories = cpuHistories.filter { live.contains($0.key) }
        for p in list {
            cpuHistories[p.pid, default: []].append(p.cpuPercent)
            if cpuHistories[p.pid]!.count > maxHistoryLength {
                cpuHistories[p.pid]!.removeFirst()
            }
        }
    }
}
