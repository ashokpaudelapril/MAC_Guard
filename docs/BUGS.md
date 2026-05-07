# MacGuard — Bug & Issue Tracker

> Generated: 2026-05-06
> Source: Static review of the source code embedded in `MacGuard_Developer_Spec.docx`
> Status key: 🔴 Open · ✅ Fixed
>
> **Read this before typing in any code from the spec.** These are findings from a static
> review of the spec's source. Apply each fix *while* typing the corresponding section, not
> after — every one of them changes how the file should be written from the start.

---

## How to Use This File

Each `BUG-S##` (S = "spec-review") entry maps to a section of `MacGuard_Developer_Spec.docx`. When the roadmap says "create `Sources/MacGuard/Services/ProcessMonitor.swift` from spec section 4.5", scan this file for any open `BUG-S##` that touches that section and apply the fix as you write the file.

When a fix lands, change the status emoji to ✅ and add the date fixed. When all items in a section are done, note it in `docs/DEVLOG.md`.

---

## SPEC-REVIEW FINDINGS — Apply While Typing the Source

---

### BUG-S01 · `struct ProcessInfo` collides with `Foundation.ProcessInfo` 🔴
**File:** `Sources/MacGuard/Models/ProcessInfo.swift` (will become `MonitoredProcess.swift`) · **Spec section:** 4.3
**What's wrong:** The spec defines `struct ProcessInfo` in our module. `Foundation.ProcessInfo` already exists as a public class for getting info about the *running* process. Inside files that `import Foundation` (effectively all of them), references to `ProcessInfo` are at best ambiguous and at worst silently resolve to Foundation's class — meaning `ProcessInfo(pid: …, name: …)` will fail to compile or, worse, compile against the wrong type.
**How to fix:**
1. Rename the file to `MonitoredProcess.swift`.
2. Rename the type to `MonitoredProcess`.
3. Update every reference in the codebase: `ProcessMonitor`, `ProcessKiller`, `AlertManager`, `DashboardView`, `AppDelegate`. (At Week 1 there are none to update yet — apply rename at first introduction.)

---

### BUG-S02 · `runPS` blocks the main thread 🔴
**File:** `Sources/MacGuard/Services/ProcessMonitor.swift` · **Spec section:** 4.5 (`poll()` and `runPS()`)
**What's wrong:** The spec uses `Timer.scheduledTimer(withTimeInterval: 2.0, …)` which fires on the main run loop. Inside that callback, `poll()` calls `runPS()` which launches `/bin/ps` with `task.run()` followed by `task.waitUntilExit()` — a synchronous wait. Process startup + wait can take 30–80 ms; on a busy system this beachballs the UI every 2 seconds.
**How to fix:** Move polling to a background `DispatchQueue` and dispatch the published state back to main:
```swift
private let pollQueue = DispatchQueue(label: "macguard.monitor.poll", qos: .utility)

private func poll() {
  pollQueue.async { [weak self] in
    guard let self else { return }
    let raw = self.runPS()
    DispatchQueue.main.async {
      self.processes = raw
      self.detectSpikes(raw)
      self.onUpdate?(self.overallLevel(raw))
    }
  }
}
```
Important: keep `spikeCounts` / `alertedPIDs` access on the main thread — only the `runPS()` shell-out moves to the background.

---

### BUG-S03 · `parseLine` mishandles process names containing spaces 🔴
**File:** `Sources/MacGuard/Services/ProcessMonitor.swift` · **Spec section:** 4.5 (`parseLine`)
**What's wrong:** The spec splits the entire `ps` line by whitespace, then takes `parts[3...]` as the name. For most lines this works because `comm` from `ps -axo comm` is the basename. But:
- A trailing newline or extra space gets coerced into an empty `parts[3]`.
- The `.components(separatedBy: "/").last` step assumes `comm` may contain slashes — `ps -axo comm=` already strips the path, so this step is harmless but misleading.
- More importantly, if the user later switches to `ps -axo command=` (full command line) for richer info, the whitespace split silently truncates everything after the first space.
**How to fix:** Use fixed-column scanning. Read PID, %CPU, RSS via whitespace splitting on the first three tokens, then take **the rest of the line** as `comm` without splitting:
```swift
private func parseLine(_ line: String) -> MonitoredProcess? {
  let trimmed = line.trimmingCharacters(in: .whitespaces)
  guard !trimmed.isEmpty else { return nil }
  // Pull the first three whitespace-separated tokens, keep the remainder verbatim
  var parts = trimmed.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
  guard parts.count == 4,
        let pid = pid_t(parts[0]),
        let cpu = Double(parts[1]),
        let rss = Double(parts[2]) else { return nil }
  let name = String(parts[3])
  return MonitoredProcess(pid: pid, name: name, cpuPercent: cpu, memoryMB: rss / 1024.0, spikeDuration: 0)
}
```
This also makes the function stable if we later switch to `command=`.

---

### BUG-S04 · `spikeCounts` and `alertedPIDs` grow unbounded 🔴
**File:** `Sources/MacGuard/Services/ProcessMonitor.swift` · **Spec section:** 4.5 (`detectSpikes`)
**What's wrong:** `spikeCounts: [Int32: Int]` grows by one entry per unique PID seen. Dead PIDs are never removed. Over a long uptime the dictionary leaks memory and — worse — when macOS recycles a PID, the new process inherits the old PID's spike count from the dictionary, causing a spurious immediate alert.
**How to fix:** After each poll, prune any PID not present in the current sample:
```swift
private func reapDeadPIDs(in latest: [MonitoredProcess]) {
  let live = Set(latest.map(\.pid))
  spikeCounts  = spikeCounts .filter { live.contains($0.key) }
  alertedPIDs  = alertedPIDs .filter { live.contains($0)     }
}
```
Call `reapDeadPIDs(in: raw)` at the end of `detectSpikes`.

---

### BUG-S05 · Auto-kill timer hardcodes 60 s, ignores `AppSettings.killDelay` 🔴
**File:** `Sources/MacGuard/AppDelegate.swift` · **Spec section:** 4.2 (`handleSpike`)
**What's wrong:** The spec has `DispatchQueue.main.asyncAfter(deadline: .now() + 60)`. The Settings panel exposes `killDelay` as a slider from 15–300 s, but the actual timer ignores it — every kill fires at exactly 60 s regardless.
**How to fix:** Read the value at the time the timer is scheduled (not when the spike is detected, in case the user just changed it):
```swift
let delay = AppSettings.shared.killDelay
DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in …
```

---

### BUG-S06 · No way to cancel the auto-kill timer 🔴
**File:** `Sources/MacGuard/AppDelegate.swift` + `Sources/MacGuard/Services/AlertManager.swift` · **Spec section:** 4.2 (`handleSpike`) + 4.7 (`AlertManager`)
**What's wrong:** Two related problems:
1. `DispatchQueue.main.asyncAfter` cannot be cancelled. If the user clicks "Ignore" or "Kill Now" in the notification, the timer still fires `killDelay` seconds later, producing a duplicate `AUTO-KILL` log entry (or a SIGKILL on a PID that is already dead — and possibly recycled to an innocent process).
2. The spec never implements `userNotificationCenter(_:didReceive:withCompletionHandler:)`, so the action buttons (KILL, IGNORE) do nothing.
**How to fix:**
1. Use `DispatchWorkItem` instead of `asyncAfter`, store it keyed by PID, and cancel it on user action or when the process drops below threshold. Re-check `monitor.isStillSpiking(pid:)` at fire time and abort if false.
2. Implement the notification delegate handler in `AlertManager` and route KILL/IGNORE back to `AppDelegate` via a callback closure or via posting to `NotificationCenter.default`. KILL → kill immediately + cancel pending. IGNORE → cancel pending only.
```swift
var pendingKills: [pid_t: DispatchWorkItem] = [:]

func handleSpike(_ p: MonitoredProcess) {
  alertManager.sendAlert(for: p)
  Logger.shared.log("ALERT: \(p.name) [PID \(p.pid)] at \(Int(p.cpuPercent))% CPU")
  let work = DispatchWorkItem { [weak self] in
    guard let self else { return }
    if self.monitor.isStillSpiking(pid: p.pid) {
      ProcessKiller.kill(p)
      Logger.shared.log("AUTO-KILL: \(p.name) [PID \(p.pid)]")
    }
    self.pendingKills[p.pid] = nil
  }
  pendingKills[p.pid] = work
  DispatchQueue.main.asyncAfter(deadline: .now() + AppSettings.shared.killDelay, execute: work)
}

func cancelPendingKill(pid: pid_t) {
  pendingKills[pid]?.cancel()
  pendingKills[pid] = nil
}
```

---

### BUG-S07 · `Package.swift` resources path is wrong 🔴
**File:** `Package.swift` · **Spec section:** 3
**What's wrong:** The spec declares:
```swift
.executableTarget(
    name: "MacGuard",
    path: "Sources/MacGuard",
    resources: [.process("Resources")]
)
```
SPM resolves resource paths **relative to the target's `path`**. So `.process("Resources")` looks for `Sources/MacGuard/Resources/`. But the spec's "Project Directory Layout" (section 2.1) shows `Resources/` at the project root, alongside `Package.swift`. With that layout, `swift build` fails with `error: invalid resource path 'Resources'`.
**How to fix:** Pick one of these (we will go with option A):
- **Option A (recommended):** Move `Resources/` to `Sources/MacGuard/Resources/`. Keep the `Package.swift` line as-is.
- Option B: Change the manifest to `resources: [.process("../../Resources")]` — works but ugly and breaks `swift package describe`.
- Option C: Drop the `path:` and let SPM use the default `Sources/MacGuard` for the target while keeping `Resources/` at root. Same actual result as Option A but more implicit.
Apply Option A in Week 1 when the directory tree is created.

---

### BUG-S08 · `nonZeroOr` discards a user-set value of 0 🔴
**File:** `Sources/MacGuard/Models/AppSettings.swift` · **Spec section:** 4.4
**What's wrong:** The spec reads `cpuThreshold` as `UserDefaults.standard.double(forKey: "cpuThreshold").nonZeroOr(80.0)`. The `nonZeroOr` extension treats `0.0` as "not set" and substitutes the default. But:
- `UserDefaults.double(forKey:)` returns `0.0` both when the key has never been set AND when the user explicitly stored `0.0`. The two cases are indistinguishable.
- If the user lowers `cpuThreshold` to 0% (which the slider doesn't allow today, but might later for testing), the setting silently flips back to 80% on next launch.
**How to fix:** Test for key presence explicitly:
```swift
private static func loadDouble(_ key: String, default fallback: Double) -> Double {
  guard UserDefaults.standard.object(forKey: key) != nil else { return fallback }
  return UserDefaults.standard.double(forKey: key)
}
```
Then `cpuThreshold = AppSettings.loadDouble("cpuThreshold", default: 80.0)`. Drop the `nonZeroOr` extension entirely.

---

### BUG-S09 · `Logger.log` is not thread-safe 🔴
**File:** `Sources/MacGuard/Utilities/Logger.swift` · **Spec section:** 4.10
**What's wrong:** Each call to `log(_:)` opens a file handle, seeks to end, writes, closes. There is no lock or serial queue. If two threads call `Logger.shared.log` concurrently (e.g., the main thread logs an `ALERT` while a background work item logs `AUTO-KILL`), their writes can interleave inside a single line — producing corrupted log entries that break parsing in the History view.
**How to fix:** Wrap the I/O in a serial dispatch queue:
```swift
private let queue = DispatchQueue(label: "macguard.logger", qos: .utility)

func log(_ message: String) {
  queue.async { [self] in
    let stamp = ISO8601DateFormatter().string(from: Date())
    let line = "[\(stamp)] \(message)\n"
    // ... existing write logic ...
  }
}
```
The `async` makes `log` non-blocking from the caller's perspective and serializes file access.

---

### BUG-S10 · `CountdownBannerView` and `Whitelist` are referenced but never implemented in the spec 🔴
**File:** `Sources/MacGuard/Views/CountdownBannerView.swift`, `Sources/MacGuard/Utilities/Whitelist.swift` · **Spec section:** 2.1 (Project Directory Layout)
**What's wrong:** The spec's directory layout (section 2.1) lists `CountdownBannerView.swift` and `Whitelist.swift`, but section 4 never provides their source. If you scaffold the project from the layout alone you'll have two missing files and no design intent for either.
**How to fix:** Both are addressed in Phase 3, Week 4 of `ROADMAP.md`:
- `Whitelist.swift` is a small static helper exposing `protectedDefaults`, `isProtected(_:)` (case-sensitive exact match per `SECURITY.md` whitelist integrity rules), and `merging(_ user: [String])`. Use it everywhere the whitelist is checked instead of repeating `settings.whitelist.contains(p.name)`.
- `CountdownBannerView.swift` is a SwiftUI view bound to a `@Published var remainingSeconds: TimeInterval` on the AppDelegate, showing a progress bar from `killDelay → 0` with a Cancel button that calls `cancelPendingKill(pid:)` (BUG-S06).
For Phases 1–2 you can leave these files unimplemented — just don't be surprised when they're missing.

---

## Summary

| Severity | Count | Fixed |
|---|---|---|
| 🔴 Spec-review findings | 10 | 0 |
| **Total** | **10** | **0** |

---

## Suggested Fix Order

The order matches the order in which each file is created per `ROADMAP.md`:

1. **BUG-S07** (Week 1) — `Package.swift` resources path. Block 1 of `swift build`.
2. **BUG-S01** (Week 2, first file) — Rename `ProcessInfo` → `MonitoredProcess` everywhere.
3. **BUG-S08** (Week 2) — `AppSettings` defaults via key-presence check.
4. **BUG-S02, S03, S04** (Week 2) — `ProcessMonitor` threading + parser + PID reaping.
5. **BUG-S05, S06** (Week 3) — `AppDelegate` cancellable timer + `AlertManager` notification action handler.
6. **BUG-S09** (Week 4) — `Logger` serial queue.
7. **BUG-S10** (Week 4) — `Whitelist.swift` + `CountdownBannerView.swift`.

---

<!-- New bug entries discovered during implementation go below this line. Use BUG-## (no S prefix) for runtime bugs found after code is written. -->

## Runtime Bugs (post-implementation)

*(none yet — the project has no code)*
