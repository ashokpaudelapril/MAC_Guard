# MacGuard — Build Roadmap

> **Swift 5.9+ • SwiftUI + AppKit • Swift Package Manager • macOS 13+**
>
> A native menu-bar app that monitors processes, alerts on CPU spikes, and force-kills runaway processes after a configurable grace period.

---

## Overview

| | |
|---|---|
| **Total Timeline** | ~6 weeks |
| **Phases** | 4 phases (mostly 1 week each, Phase 1 spans 2) |
| **Source of truth** | `MacGuard_Developer_Spec.docx` at the project root |
| **Build** | `swift build` / `swift run` (no Xcode required) |
| **Distribution** | Local for Phases 1–3; signed + notarized in Phase 4 |

The spec already contains the full source for the v1.0 app. The roadmap's job is to **sequence** that work so each week ends in a buildable, demoable state — and to give the AI sessions natural checkpoints to write/read SESSION BRIEFINGs.

---

## How to Use This Roadmap

Each week lists tasks, the owner, and an exact prompt template to give Claude/Codex/ChatGPT. Follow these rules:

**Golden Rules for Prompting**
- Always paste the relevant existing file before asking the AI to edit it — the AI has no memory between sessions.
- Be specific: include file names, line numbers, and the exact behavior you want.
- Ask for one feature at a time — do not bundle unrelated changes in one prompt.
- After each response, ask the AI to review its own output for the issues listed in `docs/BUGS.md` BUG-S01–BUG-S08 before you run it.
- Update `docs/PROGRESS.md` and `docs/DEVLOG.md` at the end of every session.

**Session Structure (per task)**
1. Open a fresh AI session
2. Paste `CLAUDE.md` (or `INSTRUCTIONS.md`) + the SESSION BRIEFING + relevant existing source
3. State the task clearly
4. Copy the output, run `swift build`, fix errors
5. Smoke-test the change manually
6. Update DEVLOG + PROGRESS

---

## Phase 1 — Foundation *(Weeks 1–2)*

**Goal:** Get from an empty folder to a running menu-bar app that polls processes and prints spike events to stdout. By the end of Phase 1 the app builds, runs, has a status item in the menu bar, and the monitor reports spikes — but no UI panels yet.

### Week 1 — Project Scaffolding

| Task | Owner | Prompt |
|---|---|---|
| Create `Package.swift` | Claude | *"Create `Package.swift` for a macOS 13+ executable target named `MacGuard` with `path: \"Sources/MacGuard\"` and a resources directive that points at `Sources/MacGuard/Resources` (NOT the project-root `Resources/` — see BUG-S07). Show me the full file."* |
| Create source directory tree | You / Terminal | `mkdir -p Sources/MacGuard/{Models,Services,Views,Utilities} Sources/MacGuard/Resources Tests/MacGuardTests` |
| Stub `main.swift` | Claude | *"Write a minimal `Sources/MacGuard/main.swift` that creates `NSApplication.shared`, attaches a placeholder `AppDelegate`, sets activation policy to `.accessory`, and runs the app. The placeholder AppDelegate just prints `MacGuard launched` on `applicationDidFinishLaunching`."* |
| Verify build | You / Terminal | `swift build && swift run` — confirm `MacGuard launched` prints and the process stays alive (ctrl-C to quit). |
| `.gitignore` | Claude | *"Write a `.gitignore` for an SPM Swift project on macOS: `.build/`, `.swiftpm/`, `*.xcodeproj` (in case anyone generates one), `.DS_Store`, `Package.resolved` debate (keep it), `xcuserdata/`. Show the full file."* |

### Week 2 — Core Monitoring (no UI yet)

| Task | Owner | Prompt |
|---|---|---|
| `Models/MonitoredProcess.swift` | Claude | *"Create `Sources/MacGuard/Models/MonitoredProcess.swift`. Define `struct MonitoredProcess: Identifiable, Equatable` with fields `id: UUID`, `pid: pid_t`, `name: String`, `cpuPercent: Double`, `memoryMB: Double`, `spikeDuration: TimeInterval`. ⚠️ Name it `MonitoredProcess` not `ProcessInfo` — see BUG-S01. Also define `enum CPULevel { case normal, warning, critical }`."* |
| `Models/AppSettings.swift` | Claude | *"Create `Sources/MacGuard/Models/AppSettings.swift` based on the spec section 4.4, but: (1) read defaults via a static helper instead of `nonZeroOr` so threshold=0 from the user is preserved (see BUG-S08), (2) make `init` private and expose `AppSettings.shared`, (3) ensure the whitelist defaults always include `kernel_task`, `WindowServer`, `launchd` even after a load."* |
| `Services/ProcessMonitor.swift` | Claude | *"Create `Sources/MacGuard/Services/ProcessMonitor.swift` based on spec section 4.5, but apply BUG-S02 (run `ps` on a background queue), BUG-S03 (parse `comm` as the rest-of-line, not whitespace-split), and BUG-S04 (reap dead PIDs from `spikeCounts` and `alertedPIDs` after each poll). Include `start()`, `stop()`, `isStillSpiking(pid:)`, `onSpike`, `onUpdate`."* |
| Wire monitor into `main.swift` | Claude | *"Update `Sources/MacGuard/main.swift` (or `AppDelegate`) to instantiate `ProcessMonitor(settings: .shared)` and start it. On `onSpike`, just `print(\"SPIKE: \\(p.name) [\\(p.pid)] \\(Int(p.cpuPercent))%\")` for now. We will add the alert + UI in Phase 2."* |
| First spike test | You / Terminal | Run `swift run` in one tab, `yes > /dev/null &` in another, lower `cpuThreshold` to 5% via UserDefaults (`defaults write …`), confirm SPIKE prints within ~30 s. |
| Unit tests for `parseLine` | Claude | *"Write XCTest cases for `ProcessMonitor.parseLine` in `Tests/MacGuardTests/ParseLineTests.swift`. Cover: well-formed line, line with leading whitespace, process name with spaces, process at a long path, malformed line returns nil. Show the full test file and the public/internal access modifier change needed on `parseLine`."* |

---

## Phase 2 — UI & Alerts *(Week 3)*

**Goal:** Install the menu-bar icon with the green/yellow/red CPU indicator, bring up the dashboard table, the settings panel, and wire spike events to a real `UNUserNotification` with Kill Now / Ignore actions.

### Week 3 — Menu Bar, Dashboard, Settings, Alerts

| Task | Owner | Prompt |
|---|---|---|
| `Resources/` icons | You + Claude | *"Tell me how to add three SF Symbols-based menu-bar templates: `shield.fill` tinted green, orange, red. Should they be image assets or rendered at runtime via `NSImage.SymbolConfiguration`? Pick one and explain why."* (Spec uses runtime tinting — go with that.) |
| `AppDelegate.swift` | Claude | *"Create `Sources/MacGuard/AppDelegate.swift` based on spec section 4.2, but apply BUG-S05 (use `settings.killDelay`, not 60 hardcoded), BUG-S06 (cancel the pending kill via `DispatchWorkItem` if `monitor.isStillSpiking(pid:)` is false at fire time, OR if user clicked Kill/Ignore). Include menu items: Open Dashboard, Settings, Quit."* |
| `Views/DashboardView.swift` | Claude | *"Create `Sources/MacGuard/Views/DashboardView.swift` based on spec section 4.8. Show me the full file. Include the `ProcessRow` substruct. Use `MonitoredProcess` (not `ProcessInfo`) per BUG-S01."* |
| `Views/SettingsView.swift` | Claude | *"Create `Sources/MacGuard/Views/SettingsView.swift` based on spec section 4.9. Add a guard so the three default whitelist entries (`kernel_task`, `WindowServer`, `launchd`) cannot be removed via the Remove button — show me the disabled-button or filter approach."* |
| `Services/AlertManager.swift` | Claude | *"Create `Sources/MacGuard/Services/AlertManager.swift` based on spec section 4.7. ALSO implement `userNotificationCenter(_:didReceive:withCompletionHandler:)` to handle the KILL and IGNORE action identifiers — KILL invokes `ProcessKiller.kill`, IGNORE cancels the pending auto-kill (via a callback). Spec section 4.7 omits this handler — see BUG-S06."* |
| `Services/ProcessKiller.swift` | Claude | *"Create `Sources/MacGuard/Services/ProcessKiller.swift` from spec section 4.6. Add a guard: refuse to kill if the process name is in `AppSettings.shared.whitelist`, and log a warning instead. This is defense-in-depth on top of the monitor's whitelist filtering."* |
| Manual integration test | You | Run `swift run`, trigger a spike with `yes > /dev/null &`, confirm: (a) menu bar icon turns red within 30 s, (b) notification fires with Kill Now / Ignore buttons, (c) clicking Kill kills the process and turns icon green, (d) ignoring lets the auto-kill fire after `killDelay` seconds. |

---

## Phase 3 — Persistence & Polish *(Week 4)*

**Goal:** Wire the history log, expose it in a History window, harden the spike→kill→log flow, and make the app survive a relaunch with settings intact.

### Week 4 — Logger, History UI, Hardening

| Task | Owner | Prompt |
|---|---|---|
| `Utilities/Logger.swift` | Claude | *"Create `Sources/MacGuard/Utilities/Logger.swift` based on spec section 4.10. Add: (a) a serial `DispatchQueue` so concurrent writes can't corrupt the file (see BUG-S09), (b) log rotation — when the file exceeds 5 MB, rename to `history.log.old` and start fresh."* |
| `Utilities/Whitelist.swift` | Claude | *"Create `Sources/MacGuard/Utilities/Whitelist.swift`. Expose `Whitelist.protectedDefaults: [String]` (`kernel_task`, `WindowServer`, `launchd`), `Whitelist.isProtected(_ name: String) -> Bool` (case-sensitive exact match), and `Whitelist.merging(_ user: [String]) -> [String]` to combine user entries with the immutable defaults. Use this everywhere the whitelist is checked."* |
| `Views/CountdownBannerView.swift` | Claude | *"Create `Sources/MacGuard/Views/CountdownBannerView.swift` — a SwiftUI view that shows a countdown bar from `killDelay` to 0 seconds with a Cancel button. Bind to a `@Published var remainingSeconds: TimeInterval` on the AppDelegate. The countdown UI is referenced in the spec's directory layout (section 2.1) but never implemented — see BUG-S10."* |
| History window | Claude | *"Add a 'History' menu item in `AppDelegate` and a SwiftUI `HistoryView` that reads `~/Library/Application Support/MacGuard/history.log` and shows it as a list, newest first. Refresh on window-open."* |
| Settings persistence test | You | Quit the app, change `cpuThreshold` to 50%, relaunch — confirm value is retained. Repeat for `killDelay` and adding a whitelist entry. |
| Wire `Logger.log` into `AlertManager` and `AppDelegate` | Claude | *"Add `Logger.shared.log(...)` calls at: (a) every notification fired (`ALERT: …`), (b) every successful kill (`AUTO-KILL: …` or `MANUAL-KILL: …`), (c) every cancelled kill (`CANCELLED: …`), (d) every kill-path abort due to whitelist or missing notification permission (`SKIPPED: …`)."* |

---

## Phase 4 — Distribution & Extensions *(Week 5+)*

**Goal:** Optional polish, extension features, and shipping.

### Week 5 — Optional Extensions (pick 2–3)

| Task | Owner | Prompt |
|---|---|---|
| Launch on login | Claude | *"Add a `LaunchAgent` plist and a Settings toggle that registers/unregisters MacGuard with `SMAppService` (macOS 13+). When toggled on, MacGuard starts automatically at login. Show me the plist contents and the Swift integration."* |
| CSV export of history | Claude | *"Add an Export CSV button to the History window. Parse the log file (lines like `[ISO8601] EVENT: name [PID n]`) into a CSV with columns: timestamp, event, name, pid. Use `NSSavePanel` to choose the destination."* |
| Live CPU chart | Claude | *"Add a small 60-second CPU history sparkline to the dashboard top bar using SwiftUI Charts. Track the system-wide max-CPU value per poll in a ring buffer of 30 samples (= 60 s)."* |
| Memory pressure alerts | Claude | *"Extend `ProcessMonitor` to also read `host_statistics(HOST_VM_INFO)` and emit a separate `onMemoryPressure` callback when free memory drops below a configurable threshold. Show the Mach-port boilerplate."* |
| Per-app CPU budget | Claude | *"Add a 'budget' field per whitelist entry: a process may exceed `cpuThreshold` for up to N minutes per hour before a kill is allowed. Update `AppSettings`, the spike state machine, and the Settings UI."* |

### Week 6 — Code Signing, Notarization, Distribution

| Task | Owner | Prompt |
|---|---|---|
| Apple Developer ID | You | Enroll in Apple Developer Program, generate a Developer ID Application certificate. |
| Build script | Claude | *"Write a `scripts/build-release.sh` shell script that: (1) runs `swift build -c release`, (2) wraps the binary into an `.app` bundle, (3) runs `codesign` with the Developer ID, (4) submits to `xcrun notarytool`, (5) staples the ticket. Show the full script."* |
| Hardened runtime | Claude | *"Add an entitlements plist for the hardened runtime — minimal entitlements, no sandboxing for v1. List the keys and explain why each is or is not needed."* |
| Update `SECURITY.md` | You | Add the production code-signing identity reference to `SECURITY.md` once obtained. |
| README updates | You | Add a Releases section with download link once the first signed build is available. |

---

## Quick Reference

### Key Files (End State)

| Path | Role |
|---|---|
| `Package.swift` | SPM manifest |
| `Sources/MacGuard/main.swift` | App entry, sets activation policy |
| `Sources/MacGuard/AppDelegate.swift` | Menu bar, window orchestration, kill timer |
| `Sources/MacGuard/Models/MonitoredProcess.swift` | Per-process value type |
| `Sources/MacGuard/Models/AppSettings.swift` | UserDefaults-backed settings singleton |
| `Sources/MacGuard/Services/ProcessMonitor.swift` | `ps` polling + spike detection |
| `Sources/MacGuard/Services/ProcessKiller.swift` | `Darwin.kill` wrapper with whitelist guard |
| `Sources/MacGuard/Services/AlertManager.swift` | UNUserNotification + Kill/Ignore actions |
| `Sources/MacGuard/Views/DashboardView.swift` | Live process table |
| `Sources/MacGuard/Views/SettingsView.swift` | Threshold sliders + whitelist editor |
| `Sources/MacGuard/Views/CountdownBannerView.swift` | Visible auto-kill countdown |
| `Sources/MacGuard/Utilities/Logger.swift` | Append-only history log |
| `Sources/MacGuard/Utilities/Whitelist.swift` | Default-protected names + merge helper |

### Build Commands

```bash
swift build              # compile
swift run                # build + launch the app
swift test               # run XCTest suites
swift package clean      # nuke .build/ if SPM gets confused
```

### Manual Smoke Test (run after every phase)

```bash
# Terminal 1
swift run

# Terminal 2 — generate a guaranteed spike
yes > /dev/null &

# Wait ~30 s, observe:
#   - Menu bar icon turns red
#   - Notification appears with Kill Now / Ignore
#   - Clicking Kill removes the `yes` process
#   - Or, doing nothing for `killDelay` seconds auto-kills it

kill %1   # only if it survived (it shouldn't)
```

---

### Reusable Prompt Templates

**New File**
```
I am building MacGuard, a macOS menu-bar process monitor.
Tech stack: Swift 5.9+, SwiftUI + AppKit, Swift Package Manager (no Xcode).
Current task: [DESCRIBE TASK IN ONE SENTENCE].

Here is the relevant spec section:
[PASTE SPEC SECTION FROM MacGuard_Developer_Spec.docx]

Here are the related existing files:
[PASTE FILE CONTENTS]

Please: [SPECIFIC INSTRUCTIONS]. Apply the relevant findings from docs/BUGS.md if any. Return the complete file, no placeholders.
```

**Debugging an Error**
```
I am getting this error when running MacGuard:
[PASTE swift build OUTPUT or runtime crash log]

This is the relevant code:
[PASTE FILE]

This is what I expected to happen vs what actually happened:
[STATE BOTH]

What is causing this? Fix the code with an `// ISSUE: … // FIX APPLIED: …` comment block above the changed lines.
```

**Code Review**
```
Please review this code for bugs, kill-path safety, threading correctness, and Swift style.
Context: this is part of MacGuard, a macOS app that force-kills runaway processes.
[PASTE CODE]
List issues by severity (critical, medium, low) and show fixed versions. Pay special attention to: kill-path preconditions, whitelist matching exactness, main-thread blocking, ProcessInfo name collisions.
```

**Writing Tests**
```
Write XCTest cases for this Swift function:
[PASTE FUNCTION]
Cover: happy path, edge cases (empty input, malformed input), and the regressions called out in docs/BUGS.md if relevant.
Show the full test file, including imports and the access-modifier change required to test internal members.
```

---

*Start with Phase 1, Week 1. Build incrementally. Run `swift build` after every change. The most important rule: every kill is a destructive operation — verify the kill-path preconditions in `SECURITY.md` after every change that touches monitor, killer, alerts, or settings.*
