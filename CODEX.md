# MacGuard — Instructions for OpenAI Codex

> **How to use this file:** At the start of every Codex session, paste the contents of this file
> as your first message (or as the system prompt if your interface supports it).
> This gives Codex full project context before writing any code.

---

## How AI Sessions Work in This Project

This project is built across many sessions using multiple AI assistants (Claude Code, Codex, ChatGPT). **No AI has memory between sessions.** The `docs/` folder is the shared memory.

Think of it as a relay race:
- The previous AI (or a previous session of you) left a trace in `docs/PROGRESS.md` and `docs/DEVLOG.md`
- You read that trace, orient yourself, do your work, and leave a clean trace for the next AI
- The next AI — whether it is you, Claude, Codex, or another tool — picks up exactly where you left off

**Your two responsibilities every session:**
1. **Read the trace** — ask the user to paste the `docs/PROGRESS.md` SESSION BRIEFING + latest `docs/DEVLOG.md` entry
2. **Write the trace** — at the end of every session, provide updated SESSION BRIEFING and DEVLOG content for the user to paste in

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
- No Xcode project file — SPM only

---

## Project File Map

```
MAC_Guard/
├── CODEX.md                  ← This file (paste for Codex sessions)
├── CLAUDE.md                 ← Same context, auto-loaded by Claude Code
├── INSTRUCTIONS.md           ← Same context, for ChatGPT / other AIs
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
- Ask the user to paste `docs/PROGRESS.md` and `docs/DEVLOG.md` to see exactly where we are.

---

## Rules — Follow These Every Session

### At the start of every session
1. Ask the user to paste `docs/PROGRESS.md`. Read the **SESSION BRIEFING** block at the top first — it tells you the last completed task and exactly what to do next. Do not scan the full checklist until you need to.
2. Ask the user to paste the latest entry from `docs/DEVLOG.md` to understand what changed most recently.
3. Confirm the next task with the user before writing any code — the SESSION BRIEFING is the default, but the user may want something different.
4. Ask for the relevant existing file(s) listed in the SESSION BRIEFING before writing any code — never guess at existing code.
5. Ask the user to paste any open entries in `docs/BUGS.md` that touch the file you're about to edit. Spec-review findings (BUG-S01–BUG-S08) flag issues to fix *while typing in* the source from the spec.

### At the end of every session (or after any change)
1. Provide an updated `docs/DEVLOG.md` entry for the user to paste in — dated, with files affected.
2. Provide an updated `docs/PROGRESS.md` **SESSION BRIEFING** block for the user to paste in — rewrite it with: what was just completed, what the next task is, which files to touch, and any blockers.

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

MacGuard runs entirely locally — there are no API keys or remote secrets. The safety surface is different from a web app: this app **kills processes** on the user's machine.

### Never do these things
- Never widen the kill path: only `Darwin.kill(pid, SIGKILL)` after the configured grace period AND only for processes not in the whitelist.
- Never invoke shell with user-supplied input. The only command launched is `/bin/ps` with hardcoded arguments.
- Never bypass the whitelist (`kernel_task`, `WindowServer`, `launchd` are load-bearing safety guards).
- Never auto-kill if notification permission was denied — the user has no way to cancel.
- Never add a network request, telemetry beacon, or analytics pixel.

### Always do these things
- Run `ps`/`Process` on a background `DispatchQueue` — the main queue belongs to the UI.
- Honor `AppSettings.killDelay` and `AppSettings.cpuThreshold` — never hardcode them.
- Update the menu-bar icon and dashboard UI on the main thread only.
- When the user taps "Kill Now" in the notification, cancel the pending auto-kill timer.

---

## Debugging Best Practices — Codex-specific

Codex cannot run code. So debugging means:

### Step 1 — Ask for the full error
- Ask the user to paste the complete `swift build` error output, the runtime crash log, or the relevant section of `Console.app`.
- For monitor/spike bugs, ask the user to lower `cpuThreshold` to 5% and run `yes > /dev/null &` to trigger a deterministic spike.

### Step 2 — Isolate
- Ask for one file at a time. Do not assume the rest of the project state.
- Ask the user to confirm `swift build` succeeded before they made the change you're inspecting.

### Step 3 — Write the fix with a comment block
Every bug fix must have:
```swift
// ISSUE: <what was wrong — be specific about variable names and behavior>
// FIX APPLIED: <how the new code resolves it — reference the change made>
```

### Step 4 — Verification instructions
Tell the user exactly what to do to confirm the fix:
- "Run `swift build` and confirm there are no warnings."
- "Run `swift run`, then `yes > /dev/null &` and watch the menu-bar icon turn red within 30 s."
- "Click 'Ignore' in the notification — confirm no log line appears 60 s later."

### Step 5 — Document it
- Provide a `docs/DEVLOG.md` entry in your response describing the bug, root cause, and fix.
- If a `BUGS.md` entry exists, provide the patched markdown for the user to paste over it.

### Common Bug Categories in This Project
| Category | What to Check First |
|---|---|
| UI freezes / beach-balling | `runPS` or `parseLine` running on main thread; file I/O in `Logger` blocking |
| Process never gets killed | PID dropped from `spikeCounts` between alert and timer fire; whitelist matched too aggressively |
| Notification never appears | Permission denied silently; `UNUserNotificationCenter.delegate` not set; category not registered |
| Notification action buttons do nothing | `userNotificationCenter(_:didReceive:withCompletionHandler:)` not implemented |
| `ProcessInfo` ambiguous error | Foundation's `ProcessInfo` collides with our model — see BUG-S01 |
| Settings reset on relaunch | `AppSettings.init` reading `UserDefaults` before `didSet` is wired |
| Resources not loading | `Package.swift` `resources:` directive points outside the target's `path` — see BUG-S07 |

---

## Testing Approach

| Layer | Tool | When |
|---|---|---|
| Manual smoke test | `swift run` + `yes > /dev/null &` | Every time the app starts |
| Unit tests | XCTest via `swift test` | Per pure function (parser, threshold logic, settings serialization) |
| Manual integration | Activity Monitor + observation | After AlertManager + ProcessKiller wiring |

**Codex workflow note:** Since Codex does not run code, after you write any pure function (e.g., `parseLine`, `overallLevel`, `nonZeroOr`), provide a small XCTest snippet for it alongside the source. The user can paste it into `Tests/MacGuardTests/` and run `swift test`.

---

## Build Commands the User Can Run

```bash
swift build              # compile
swift run                # build + launch
swift test               # run XCTest suites
swift package clean      # nuke .build/ if SPM gets confused
```
