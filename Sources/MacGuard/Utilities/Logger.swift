import Foundation

// TASK: Thread-safe singleton that appends timestamped event lines to history.log.
// HOW CODE SOLVES: All file I/O is serialised on a private DispatchQueue so concurrent
//                  callers (main thread logging ALERT while a background work item logs
//                  AUTO-KILL) can never interleave mid-line (BUG-S09 fix — the spec uses
//                  no lock). Log file lives in ~/Library/Application Support/MacGuard/.
//                  Rotation kicks in at 5 MB, keeping total disk use under ~10 MB.
final class Logger {
    static let shared = Logger()

    private let queue = DispatchQueue(label: "macguard.logger", qos: .utility)
    private let maxBytes = 5 * 1024 * 1024  // 5 MB rotation threshold

    private let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private var logURL: URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("MacGuard/history.log")
    }

    private init() {
        queue.async { [self] in createDirectoryIfNeeded() }
    }

    // TASK: Append one timestamped event line to the log file.
    // HOW CODE SOLVES: Dispatches asynchronously so callers on the main thread are never
    //                  blocked by disk I/O. The serial queue ensures lines are written in
    //                  arrival order even when multiple events fire simultaneously.
    func log(_ message: String) {
        queue.async { [self] in
            guard let url = logURL else { return }
            rotateIfNeeded(url: url)
            let stamp = formatter.string(from: Date())
            guard let data = "[\(stamp)] \(message)\n".data(using: .utf8) else { return }
            if FileManager.default.fileExists(atPath: url.path) {
                guard let handle = try? FileHandle(forWritingTo: url) else { return }
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    // TASK: Return all log entries newest-first for the History view.
    // HOW CODE SOLVES: Reads synchronously — a one-shot read of up to 5 MB is fast enough
    //                  for an on-demand UI request. Reversing puts the most recent event at
    //                  index 0 so the History list shows it at the top without manual sorting.
    func entries() -> [String] {
        guard let url = logURL,
              let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return content.components(separatedBy: "\n").filter { !$0.isEmpty }.reversed()
    }

    // TASK: Export all log entries as RFC-4180 CSV text for NSSavePanel download.
    // HOW CODE SOLVES: Reads entries() (newest-first) and reverses to chronological order
    //                  for a sensible spreadsheet layout. Each entry is split on the
    //                  ISO-8601 bracket into two columns — Timestamp and Event — so the
    //                  user can sort/filter by time in Excel or Numbers. Internal quotes
    //                  are doubled per RFC 4180. Returns nil if the log file is empty.
    func exportCSV() -> String? {
        let raw = entries()   // newest-first
        guard !raw.isEmpty else { return nil }
        var lines = ["\"Timestamp\",\"Event\""]
        for entry in raw.reversed() {   // chronological in CSV
            if entry.hasPrefix("["), let closeIdx = entry.firstIndex(of: "]") {
                let stamp = String(entry[entry.index(after: entry.startIndex)..<closeIdx])
                let msg   = String(entry[entry.index(after: closeIdx)...])
                              .trimmingCharacters(in: .whitespaces)
                let safe  = msg.replacingOccurrences(of: "\"", with: "\"\"")
                lines.append("\"\(stamp)\",\"\(safe)\"")
            } else {
                let safe = entry.replacingOccurrences(of: "\"", with: "\"\"")
                lines.append("\"\",\"\(safe)\"")
            }
        }
        return lines.joined(separator: "\n")
    }

    private func createDirectoryIfNeeded() {
        guard let url = logURL else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    // TASK: Rotate history.log to history.log.1 when the file exceeds 5 MB.
    // HOW CODE SOLVES: Moves the current file to the .1 archive (discarding the previous .1)
    //                  then lets the next write create a fresh history.log. Called inside the
    //                  serial queue so rotation and the subsequent write are atomic from the
    //                  logger's perspective — no other log() call can interleave.
    private func rotateIfNeeded(url: URL) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int, size > maxBytes else { return }
        let archive = url.deletingLastPathComponent().appendingPathComponent("history.log.1")
        try? FileManager.default.removeItem(at: archive)
        try? FileManager.default.moveItem(at: url, to: archive)
    }
}
