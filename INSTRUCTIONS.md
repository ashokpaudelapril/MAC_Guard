# MacGuard — Project Instructions for AI Assistants

Paste this file at the start of any AI session (ChatGPT, Gemini, etc.) to give the assistant full project context.

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
- Persistence: `UserDefaults` for settings, flat `.log` file in `~/Library/Application Support/MacGuard/`
- Process polling: `/bin/ps -axo pid=,pcpu=,rss=,comm=` via `Foundation.Process` every 2 s
- Kill mechanism: `Darwin.kill(pid, SIGKILL)`
- Notifications: `UNUserNotificationCenter` with Kill Now / Ignore action buttons

**Key non-features (do not add):**
- No network calls, no telemetry, no cloud sync
- No external APIs, no API keys, no OAuth
- No database — `UserDefaults` + flat log file only
- No Xcode project file — SPM only

---

## Project File Map

```
MAC_Guard/
├── INSTRUCTIONS.md           ← This file (paste for ChatGPT / other AIs)
├── CODEX.md                  ← Same context, formatted for OpenAI Codex sessions
├── CLAUDE.md                 ← Same context, auto-loaded by Claude Code
├── SECURITY.md               ← Permissions + kill-safety rules. READ ONLY — do not edit.
├── ROADMAP.md                ← Phased build plan. READ ONLY — do not edit.
├── README.md                 ← Setup guide. READ ONLY — do not edit.
├── MacGuard_Developer_Spec.docx  ← Original spec
├── docs/
│   ├── PROGRESS.md           ← Task checklist per phase/week
│   ├── DEVLOG.md             ← Chronological log of every change
│   └── BUGS.md               ← Issue tracker incl. spec-review findings
├── Package.swift             ← SPM manifest (created in Week 1)
├── Sources/MacGuard/         ← All Swift sources
└── Resources/                ← Menu-bar icons (added in Week 3)
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
3. Confirm the next task with the user before writing any code.
4. Read `docs/BUGS.md` — pre-implementation findings (BUG-S01–BUG-S08) flag issues to fix while typing in the source from the spec.

### At the end of every session (or after any change)
1. Update `docs/DEVLOG.md` — add a dated entry with what was changed and which files were affected.
2. Update `docs/PROGRESS.md` — check off completed tasks AND rewrite the **SESSION BRIEFING** block.

### Never touch these files unless explicitly asked
- `README.md`
- `ROADMAP.md`
- `SECURITY.md`
- `MacGuard_Developer_Spec.docx`

---

## Code Commenting Rules

Every piece of Swift code you write or modify **must include a comment block** using one of these two formats:

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

---

## Privacy & Safety Rules

MacGuard runs entirely locally — there are no API keys or remote secrets. The safety surface is different from a typical web app: this app **kills processes** on the user's machine. Read `SECURITY.md` for the full inventory.

### Never do these things
- Never widen the kill path: only `Darwin.kill(pid, SIGKILL)` after the configured grace period AND only for processes not in the whitelist.
- Never invoke shell with user-supplied input. The only command launched is `/bin/ps` with hardcoded arguments.
- Never bypass the whitelist. The defaults (`kernel_task`, `WindowServer`, `launchd`) are load-bearing safety guards.
- Never auto-kill if notification permission was denied — the user has no way to cancel.
- Never add a network request, telemetry beacon, or analytics pixel.

### Always do these things
- Run `ps`/`Process` on a background `DispatchQueue`, never on the main thread.
- Honor `AppSettings.killDelay` and `AppSettings.cpuThreshold` — never hardcode them.
- Update the menu-bar icon and dashboard UI on the main thread only.
- When the user taps "Kill Now" in the notification, cancel the pending auto-kill timer.

---

## Debugging Best Practices

When fixing a bug, follow this process — do not skip steps.

### Step 1 — Read the full error before touching code
- Read the complete Swift compiler error or runtime crash log.
- Identify the exact file, line number, and function.
- For runtime crashes, check `Console.app` filtered by `MacGuard`.
- State out loud what the **expected** behavior was vs what **actually** happened.

### Step 2 — Isolate before fixing
- Do not change multiple things at once.
- For monitor/spike bugs, lower `cpuThreshold` to 5% and run `yes > /dev/null &`.
- For kill-path bugs, target a known harmless PID first (e.g., `sleep 9999 &`).

### Step 3 — Write the fix with a comment block
Every bug fix **must** have this comment directly above the changed code:
```swift
// ISSUE: <what was wrong — be specific about variable names and behavior>
// FIX APPLIED: <how the new code resolves it — reference the change made>
```

### Step 4 — Verify the fix
- Run `swift build` — must succeed with no warnings.
- Run `swift run` and exercise the changed path manually.
- Re-run `swift test` if a unit test exists for the area.
- Check that the fix did not break adjacent behavior.

### Step 5 — Document it
- Add an entry to `docs/DEVLOG.md` describing the bug, root cause, and fix.
- Update the matching entry in `docs/BUGS.md` — change 🔴 to ✅ and add the date fixed.

### Common Bug Categories in This Project
| Category | What to Check First |
|---|---|
| UI freezes / beach-balling | `runPS` or `parseLine` on main thread; `Logger` file I/O blocking |
| Process never gets killed | PID dropped from `spikeCounts` between alert and timer fire; whitelist match too aggressive |
| Notification never appears | Permission denied silently; `delegate` not set; category not registered |
| Notification action buttons do nothing | `userNotificationCenter(_:didReceive:withCompletionHandler:)` missing |
| `ProcessInfo` ambiguous error | Foundation's `ProcessInfo` collides with our model — see BUG-S01 |
| Settings reset on relaunch | `AppSettings.init` reading before `didSet` wired |
| Resources not loading | `Package.swift` resources directive outside target `path` — see BUG-S07 |

---

## Build & Run Commands

```bash
swift build              # compile
swift run                # build + launch the app (menu-bar icon appears)
swift test               # run XCTest suites
swift package clean      # nuke .build/ if SPM gets confused
```
