# MacGuard — AI Instructions (auto-loaded by Claude Code)

This file is your full project context. Read it before doing anything else.

---

## How AI Sessions Work in This Project

This project is built across many sessions using multiple AI assistants (Claude Code, Codex, ChatGPT). **No AI has memory between sessions.** The `docs/` folder is the shared memory.

Think of it as a relay race:
- The previous AI (or a previous session of you) left a trace in `docs/PROGRESS.md` and `docs/DEVLOG.md`
- You read that trace, orient yourself, do your work, and leave a clean trace for the next AI
- The next AI — whether it is you, Claude, Codex, or another tool — picks up exactly where you left off

**Your two responsibilities every session:**
1. **Read the trace** — `docs/PROGRESS.md` SESSION BRIEFING + latest `docs/DEVLOG.md` entry
2. **Write the trace** — update both files before the session ends, even if mid-task

If you skip writing the trace, the next AI starts blind. That wastes the user's time and breaks continuity.

---

## What This Project Is

A native macOS menu-bar app that monitors running processes, alerts on CPU spikes, and force-kills runaway processes after a configurable grace period.

**Stack:**
- Language: Swift 5.9+
- UI: SwiftUI + AppKit (NSStatusItem, NSWindow)
- Build: Swift Package Manager — `swift build` / `swift run`
- Platform: macOS 13 Ventura+ (Apple Silicon + Intel)
- Persistence: `UserDefaults` for settings, flat `.log` file in `~/Library/Application Support/MacGuard/` for history
- Process polling: `/bin/ps -axo pid=,pcpu=,rss=,comm=` invoked via `Foundation.Process` every 2 s
- Kill mechanism: `Darwin.kill(pid, SIGKILL)`
- Notifications: `UNUserNotificationCenter` (with Kill Now / Ignore action buttons)

**Key non-features (do not add):**
- No network calls, no telemetry, no cloud sync
- No external APIs, no API keys, no OAuth
- No database — `UserDefaults` + flat log file only
- No Xcode project file — SPM only (the user builds in VS Code)

---

## Project File Map

```
MAC_Guard/
├── CLAUDE.md                 ← This file (auto-loaded by Claude Code)
├── CODEX.md                  ← Same context, formatted for OpenAI Codex sessions
├── INSTRUCTIONS.md           ← Same context, paste for ChatGPT / other AIs
├── SECURITY.md               ← Permissions + kill-safety rules. READ ONLY — do not edit.
├── ROADMAP.md                ← Phased build plan. READ ONLY — do not edit.
├── README.md                 ← Setup guide. READ ONLY — do not edit.
├── MacGuard_Developer_Spec.docx  ← Original spec (source of truth for design decisions)
├── References/               ← Original Canvas-AI doc templates this set was tailored from. Ignore.
├── docs/
│   ├── PROGRESS.md           ← Task checklist per phase/week. Update as tasks complete.
│   ├── DEVLOG.md             ← Chronological log of every change. Update every session.
│   └── BUGS.md               ← Issue tracker, including pre-implementation spec findings.
├── Package.swift             ← SPM manifest (created in Week 1)
├── Sources/MacGuard/         ← All Swift sources (created across Weeks 1–4)
│   ├── main.swift
│   ├── AppDelegate.swift
│   ├── Models/               ← MonitoredProcess.swift, AppSettings.swift
│   ├── Services/             ← ProcessMonitor.swift, ProcessKiller.swift, AlertManager.swift
│   ├── Views/                ← DashboardView.swift, SettingsView.swift, CountdownBannerView.swift
│   └── Utilities/            ← Logger.swift, Whitelist.swift
└── Resources/                ← Menu-bar icons (green / yellow / red), created in Week 3
```

---

## Current Status

- **Active Phase:** Phase 1 — Foundation
- **Active Week:** Week 1 — Project Scaffolding
- Check `docs/PROGRESS.md` for the SESSION BRIEFING and the full task checklist.
- Check `docs/DEVLOG.md` for what changed most recently.

---

## Rules — Follow These Every Session

### At the start of every session
1. Read `docs/PROGRESS.md` — go straight to the **SESSION BRIEFING** block at the top. It tells you the last completed task and exactly what to do next. Do not scan the full checklist until you need to.
2. Read the latest entry in `docs/DEVLOG.md` to understand what changed most recently.
3. Confirm the next task with the user before writing any code — the SESSION BRIEFING is the default, but the user may want something different.
4. **Read `docs/BUGS.md`.** Several spec-review findings (BUG-S01 through BUG-S08) call out issues to fix *while typing in* the source from `MacGuard_Developer_Spec.docx` — do not blindly copy from the spec.

### At the end of every session (or after any change)
1. Update `docs/DEVLOG.md` — add a dated entry with what was changed and which files were affected.
2. Update `docs/PROGRESS.md` — check off completed tasks AND rewrite the **SESSION BRIEFING** block with: what was just completed, what the next task is, which files to touch, and any blockers.

### Never touch these files unless explicitly asked
- `README.md`
- `ROADMAP.md`
- `SECURITY.md`
- `MacGuard_Developer_Spec.docx`
- Anything inside `References/`

---

## Code Commenting Rules

Every piece of Swift code you write or modify **must include a comment block** using one of these two formats. Swift uses `//` line comments — same syntax as TS.

### For bug fixes / debugging
```swift
// ISSUE: <describe what was wrong with the previous code>
// FIX APPLIED: <describe how the new code resolves the issue>
```

### For new code / new features
```swift
// TASK: <describe what this code is supposed to do>
// HOW CODE SOLVES: <explain how/why this implementation achieves the task>
```

**Rules for comments:**
- Be specific — reference variable names, function names, or behavior
- Place the comment block directly above the function, struct, or block it describes
- Do not add vague comments like `// updated` or `// fixed`
- Every changed or newly written function must have its own comment block

**Example — Bug Fix:**
```swift
// ISSUE: parseLine split process names containing spaces because it used .components(separatedBy: .whitespaces)
// FIX APPLIED: switched to ps -o with fixed columns + a single rest-of-line capture for `comm`
private func parseLine(_ line: String) -> MonitoredProcess? { ... }
```

**Example — New Feature:**
```swift
// TASK: Reset spikeCounts and alertedPIDs for any PID no longer present in the latest ps sample
// HOW CODE SOLVES: After each poll, intersect the dictionary keys with the live PID set and drop the rest.
//                  Prevents unbounded growth and stale state when PIDs are recycled.
private func reapDeadPIDs(in latest: [MonitoredProcess]) { ... }
```

---

## Privacy & Safety Rules

MacGuard runs entirely locally — there are no API keys or remote secrets. The safety surface is different from a typical web app: this app **kills processes** on the user's machine. Read `SECURITY.md` for the full inventory.

### Never do these things
- Never widen the kill path: only `Darwin.kill(pid, SIGKILL)` after the configured grace period AND only for processes not in the whitelist.
- Never invoke shell with user-supplied input. The only command launched is `/bin/ps` with hardcoded arguments.
- Never use `Process.launchPath` with arguments built from a process name, PID, user setting, or anything else not a fixed string literal.
- Never bypass the whitelist. The defaults (`kernel_task`, `WindowServer`, `launchd`) are load-bearing safety guards.
- Never auto-kill if the user has not granted notification permission — they would have no way to cancel.
- Never log or display full command lines that may contain user file paths to anywhere outside the local log file.
- Never add a network request, telemetry beacon, or analytics pixel. This app is local-only by design.

### Always do these things
- Run `ps`/`Process` on a background `DispatchQueue`, never on the main thread (the spec's draft polls on main, which freezes the UI).
- Honor `AppSettings.killDelay` for the auto-kill timer — do not hardcode 60 s.
- Honor `AppSettings.cpuThreshold` for the spike test — do not hardcode 80%.
- Hold a single `AppSettings.shared` instance — re-reading `UserDefaults` per poll is wasteful and error-prone.
- Update the menu-bar icon and dashboard UI on the main thread only.
- When clicking "Kill Now" in the notification, cancel the pending auto-kill timer to avoid a double-kill log entry.
- Add a unit test for any new pure function (parser, settings serialization, threshold logic).

---

## Debugging Best Practices

When fixing a bug, follow this process — do not skip steps.

### Step 1 — Read the full error before touching code
- Read the complete Swift compiler error or runtime crash log
- Identify the exact file, line number, and function
- For runtime crashes, check `Console.app` filtered by `MacGuard` for `os_log` output and `ips`/`crash` reports
- State out loud (in a comment or response) what the **expected** behavior was vs what **actually** happened

### Step 2 — Isolate before fixing
- Do not change multiple things at once — change one thing, verify it, then move on
- Reproduce the bug with the smallest possible scenario (a single process, a single setting change)
- For monitor/spike bugs, lower `cpuThreshold` to 5% and run `yes > /dev/null &` to trigger a deterministic spike
- For kill-path bugs, target a known harmless PID first (e.g., `sleep 9999 &`)

### Step 3 — Write the fix with a comment block
Every bug fix **must** have this comment directly above the changed code:
```swift
// ISSUE: <what was wrong — be specific about variable names and behavior>
// FIX APPLIED: <how the new code resolves it — reference the change made>
```

### Step 4 — Verify the fix
- Run `swift build` — must succeed with no warnings
- Run `swift run` and exercise the changed path manually
- If a unit test exists, re-run it with `swift test`
- Check that the fix did not break adjacent behavior (e.g., changing the polling cadence affects icon updates AND spike detection)

### Step 5 — Document it
- Add an entry to `docs/DEVLOG.md` describing the bug, root cause, and fix
- Update the matching entry in `docs/BUGS.md` — change 🔴 to ✅ and add the date fixed
- If the bug reveals a pattern (e.g. "we forgot to dispatch back to main again"), note it in DEVLOG so we don't repeat it

### Common Bug Categories in This Project
| Category | What to Check First |
|---|---|
| UI freezes / beach-balling | `runPS` or `parseLine` running on main thread; long file I/O in `Logger` |
| Process never gets killed | PID dropped from `spikeCounts` between alert and timer fire; whitelist match too aggressive |
| Notification never appears | Permission denied silently; `UNUserNotificationCenter.delegate` not set; missing category registration |
| Notification action buttons do nothing | `userNotificationCenter(_:didReceive:withCompletionHandler:)` not implemented |
| `ProcessInfo` ambiguous error | Foundation's `ProcessInfo` collides with our model — use the local-name fix in `BUGS.md` BUG-S01 |
| Settings reset on relaunch | `AppSettings.init` reading `UserDefaults` before `didSet` is wired; double-init of `.shared` |
| Resources not loading | `Package.swift` `resources:` directive points outside the target's `path` — see BUG-S07 |

---

## Build & Run Commands

```bash
swift build              # compile only
swift run                # build + launch the app (menu-bar icon appears)
swift test               # run XCTest suites (added in Week 2)
swift package clean      # nuke .build/ if SPM gets confused
```

If `swift build` reports `error: no such target` or symbol collisions with `ProcessInfo`, see BUG-S01 in `docs/BUGS.md`.
