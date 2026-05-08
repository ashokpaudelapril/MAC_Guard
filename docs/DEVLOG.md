# MacGuard — Development Log

A running log of everything built, changed, or fixed. Read top-to-bottom for the full history, or jump to the latest entry at the bottom.

**Format per entry:**
- Date
- What was done
- Files affected
- Notes / decisions made

---

## 2026-05-06 — Project Documentation Tailored from References/

### What was done
- Inspected the spec at `MacGuard_Developer_Spec.docx` (extracted XML text for full review). Confirmed the project is local-only Swift/SPM with no network or DB surface.
- Inspected the 9 reference docs in `References/` (originally written for the Canvas AI Node/React project) and confirmed the SESSION BRIEFING harness is reusable.
- Created `docs/` directory.
- Wrote 9 tailored docs at the project root:
  - `README.md` — quick start (`swift build` / `swift run`), project layout, default config, docs index
  - `CLAUDE.md` — auto-loaded project context for Claude Code, with Swift-specific commenting + debugging conventions
  - `CODEX.md` — same context formatted for OpenAI Codex (paste-at-start, ask-the-user-to-paste-files workflow, includes XCTest snippet guidance since Codex can't run code)
  - `INSTRUCTIONS.md` — generic AI assistant version (ChatGPT, Gemini, etc.)
  - `SECURITY.md` — kill-path hard rules, whitelist integrity rules, shell-injection rules, permissions inventory, code-signing notes. Pointedly NOT about API keys (none exist) — about destructive process kills.
  - `ROADMAP.md` — 4-phase / ~6-week build plan derived from the spec, with prompt templates per task
  - `docs/PROGRESS.md` — SESSION BRIEFING + full task checklist mirroring ROADMAP
  - `docs/DEVLOG.md` — this file
  - `docs/BUGS.md` — pre-seeded with 10 spec-review findings (BUG-S01 through BUG-S10) identified by static read of the source code in the spec — these must be applied while typing the source, not after

### Files affected
| File | Change |
|---|---|
| `README.md` | Created — setup + project layout + docs index |
| `CLAUDE.md` | Created — Claude Code session context |
| `CODEX.md` | Created — Codex session context |
| `INSTRUCTIONS.md` | Created — generic AI session context |
| `SECURITY.md` | Created — safety rules tailored to local process-killing app |
| `ROADMAP.md` | Created — phased build plan |
| `docs/PROGRESS.md` | Created — SESSION BRIEFING + full task checklist |
| `docs/DEVLOG.md` | Created — this file |
| `docs/BUGS.md` | Created — 10 pre-implementation findings from static spec review |

### Notes
- **No Swift source has been written yet.** The next session should start at Week 1 of `ROADMAP.md` (Package.swift + main.swift + directory tree). The SESSION BRIEFING in `PROGRESS.md` has the exact step-by-step.
- **Major divergence from the spec to be aware of:** the spec's `struct ProcessInfo` collides with `Foundation.ProcessInfo`. We will rename it to `MonitoredProcess` everywhere — this is BUG-S01 and is mentioned in PROGRESS, ROADMAP, CLAUDE.md, and BUGS.md. Do not type the spec as-is; apply the rename first.
- **BUG-S07 is a footgun on day one:** the spec's `Package.swift` declares `path: "Sources/MacGuard"` but tells the user to create `Resources/` at the project root. SPM looks for resources relative to `path`, so the bundle would not contain the icons. The fix is to put `Resources/` at `Sources/MacGuard/Resources/`. Check this before running `swift build` for the first time.
- **`References/` is preserved untouched.** It contains the original Canvas-AI templates and is referenced in `CLAUDE.md` as "Ignore". Future contributors should not edit anything in there.
- **Commenting convention established:** `// ISSUE: … // FIX APPLIED: …` for bug fixes, `// TASK: … // HOW CODE SOLVES: …` for new code. Same as the Canvas-AI convention but using Swift `//` syntax (which is identical to TS).

<!-- Add new entries below this line -->

---

## 2026-05-07 — Week 6: Code Signing & Distribution Scaffolding

### What was done
- Created `Info.plist` at the project root — full `.app` bundle metadata:
  - `CFBundleIdentifier`: `com.ashokpaudel.MacGuard`
  - `LSUIElement = true` — suppresses the dock icon (menu-bar–only app)
  - `NSUserNotificationAlertStyle = alert` — keeps notification banners on screen until dismissed, which is required for the Kill Now / Ignore action buttons to remain reachable (auto-dismiss "banner" style drops the actions)
  - `CFBundleShortVersionString` / `CFBundleVersion` are stub values; `build-release.sh` stamps the real values via `PlistBuddy` at package time
- Created `MacGuard.entitlements` — hardened-runtime entitlements:
  - No App Sandbox (`com.apple.security.app-sandbox` absent) — sandboxing would block `/bin/ps` child-process execution and `Darwin.kill()` signal delivery to arbitrary PIDs
  - All three `cs.*` entitlements set to `false` (the secure defaults) — JIT, unsigned executable memory, and library-validation bypass are all disabled
  - Documented why no sandbox: the core kill path requires it; a future version could apply for a process-management temporary exception
- Created `scripts/build-release.sh` (executable `chmod +x`):
  - Step 1: `xcodebuild` universal arm64+x86_64 release build, with automatic fallback to `swift build -c release` for native arch when no `.xcodeproj` exists
  - Step 2: Assemble `.app` bundle (`MacOS/`, `Resources/`, `PkgInfo`, `Info.plist` stamped with version+build+bundleID via `PlistBuddy`)
  - Step 3: Code sign binary then bundle with `--options runtime` (hardened runtime required for notarization) and `--timestamp`
  - Step 4: Verify with `codesign --verify --deep --strict` + `spctl --assess` (assessment fails pre-notarization — script continues with a warning)
  - Step 5: `ditto -c -k --keepParent` packages the bundle into a zip for Notary Service submission
  - Step 6: `xcrun notarytool submit … --wait --timeout 300` — blocks until Apple returns a result
  - Step 7: `xcrun stapler staple` + `validate` — embeds the ticket so the app passes Gatekeeper offline
  - All configuration (DEVELOPER_ID, APP_VERSION, BUNDLE_ID, NOTARIZE_PROFILE) is at the top of the script as overrideable env vars
  - Includes one-time setup instructions in comments: `xcrun notarytool store-credentials` command with the keychain profile name
- Added `dist/` to `.gitignore` — release artifacts should not be checked in
- `swift build` — still clean (0.23 s — incremental, no Swift source changed)

### Files affected
| File | Change |
|---|---|
| `Info.plist` | Created — .app bundle metadata, LSUIElement, NSUserNotificationAlertStyle=alert |
| `MacGuard.entitlements` | Created — hardened runtime, no sandbox |
| `scripts/build-release.sh` | Created — 7-step build+sign+notarize+staple pipeline |
| `.gitignore` | Added `dist/` |

### Notes
- **What's needed to run the script:** (1) Apple Developer ID Application certificate in your keychain, (2) `xcrun notarytool store-credentials "macguard-notarize"` run once with your Apple ID + team ID + app-specific password, (3) Xcode installed.
- **Notarization takes 1–10 minutes** for a first submission. Subsequent builds of the same version may be faster once Apple has cached the binary hash.
- **After notarization is successful:** Run `swift run` to verify the app still works, then run `spctl --assess --type execute dist/MacGuard.app` — it should now print `dist/MacGuard.app: accepted` without the pre-notarization warning.
- **Launch at Login (Week 5) will now work** once the app runs from a signed `.app` bundle — `SMAppService.mainApp.register()` no longer throws.
- **UNUserNotificationCenter will now work** once the bundle identifier is present — the notification flow (spike → banner → Kill Now / Ignore) can be fully tested for the first time.

---

## 2026-05-07 — Week 5: CPU Sparkline, CSV Export, Launch at Login

### What was done
- **CPU Sparkline** (`Sources/MacGuard/Services/ProcessMonitor.swift`, `Sources/MacGuard/Views/DashboardView.swift`):
  - Added `cpuHistories: [pid_t: [Double]]` rolling 30-sample (60 s) history to `ProcessMonitor`. Not `@Published` — views read it during re-renders triggered by the `processes` update, so they always see the freshly-updated values.
  - Added `updateHistories(_:)` called before `self.processes = raw` in `poll()`. Caps each array at `maxHistoryLength = 30`, prunes dead PIDs in the same pass.
  - Added `cpuHistory(for pid: pid_t) -> [Double]` accessor (called from `DashboardView`).
  - Updated `ProcessRow` to accept `history: [Double]`. Shows a 52×20 pt `SparklineView` between the memory label and the CPU% number when `history.count >= 2`.
  - Added `SparklineView`: `GeometryReader` + `Path` stroked in `Color.googleBlue.opacity(0.55)` at 1.5 pt. Y-axis normalises against `max(threshold, peak)` so the line fills the available height and a spike exactly at threshold touches the top edge.
- **CSV Export** (`Sources/MacGuard/Utilities/Logger.swift`, `Sources/MacGuard/Views/HistoryView.swift`):
  - Added `Logger.exportCSV() -> String?` — reads `entries()`, reverses to chronological order, splits each entry on the ISO-8601 bracket into Timestamp + Event columns, doubles internal quotes per RFC 4180.
  - Added **Export** button to `HistoryView` toolbar (disabled when log is empty). Tapping it calls `Logger.shared.exportCSV()` then presents `NSSavePanel` defaulting to `macguard-history.csv`. Requires `import AppKit` + `import UniformTypeIdentifiers` for `UTType.commaSeparatedText`.
- **Launch at Login** (`Sources/MacGuard/Views/SettingsView.swift`):
  - Added `import ServiceManagement`. Added `launchAtLoginSection` card with a `Toggle` bound to `@State private var launchAtLogin`. Initialised from `SMAppService.mainApp.status == .enabled` at view creation.
  - `setLaunchAtLogin(_:)` calls `SMAppService.mainApp.register()` or `.unregister()`. If the call throws (expected during development without a signed bundle), the toggle reverts so the UI stays in sync with reality.
  - Shows a caption "Requires a signed .app bundle (Week 6)" when `Bundle.main.bundleIdentifier == nil`.
- `swift build` — `Build complete! (2.58s)`, zero warnings.
- `swift test` — 12/12 passed (6 ParseLine + 6 Whitelist), no regressions.

### Files affected
| File | Change |
|---|---|
| `Sources/MacGuard/Services/ProcessMonitor.swift` | Added cpuHistories, updateHistories, cpuHistory(for:) |
| `Sources/MacGuard/Views/DashboardView.swift` | ProcessRow updated with history param; SparklineView added |
| `Sources/MacGuard/Utilities/Logger.swift` | Added exportCSV() |
| `Sources/MacGuard/Views/HistoryView.swift` | Added Export button + NSSavePanel; import AppKit + UniformTypeIdentifiers |
| `Sources/MacGuard/Views/SettingsView.swift` | Added import ServiceManagement; launchAtLogin state + launchAtLoginSection |

### Notes
- `SMAppService.mainApp.register()` will throw `SMAppServiceErrorDomain` code 1 when running as a bare SPM executable (no bundle identifier). This is expected — the toggle reverts gracefully. The feature is fully wired and will work after Week 6 code-signing.
- SparklineView divides by `(values.count - 1)` for the x step — callers must guard `history.count >= 2` before rendering (handled in `ProcessRow`).

---

## 2026-05-07 — Week 4: Logger, Whitelist, CountdownBanner, History

### What was done
- Created `Sources/MacGuard/Utilities/Logger.swift`:
  - Singleton with serial `DispatchQueue(label: "macguard.logger", qos: .utility)` — all file I/O serialised so concurrent callers never interleave mid-line (BUG-S09 fix over spec's no-lock approach).
  - Log file at `~/Library/Application Support/MacGuard/history.log`. Directory created on first `Logger.init()`.
  - `log(_:)` appends ISO-8601-stamped lines asynchronously.
  - `entries()` reads synchronously newest-first (reversed) for the History view.
  - Rotates at 5 MB: moves to `history.log.1`, discards previous `.1`, lets next write create a fresh log.
- Created `Sources/MacGuard/Utilities/Whitelist.swift`:
  - `enum Whitelist` (no-instance) — `protectedDefaults`, `isProtected(_:)`, `merging(_:)` as static methods. Single source of truth for the three protected names (BUG-S10 fix — previously duplicated across AppSettings, SettingsView, and ProcessKiller).
- Created `Sources/MacGuard/Views/CountdownBannerView.swift`:
  - `SpikeAlertState: ObservableObject` singleton with `@Published var alerts: [SpikeAlert]` and `onCancel: ((pid_t) -> Void)?`.
  - `CountdownBannerView`: 1-second Timer publisher drives `@State private var now`, each `BannerRow` shows a progress bar (1.0→0.0) and a Cancel button.
  - `DashboardView` now shows `CountdownBannerView()` at the top of its `VStack`.
- Created `Sources/MacGuard/Views/HistoryView.swift`:
  - Reads `Logger.shared.entries()` on appear and Refresh button press.
  - Monospaced `.caption2` font, alternating white/googleSurface rows, empty-state clock icon.
  - Added as a third tab ("History", `clock` icon) in `ContentView`'s `TabView`.
- Updated `Sources/MacGuard/AppDelegate.swift`:
  - Wired `Logger.shared.log(...)` at all 5 event sites: ALERT, AUTO-KILL, KILL-NOW, IGNORED, SKIPPED.
  - Wired `SpikeAlertState.shared.add/remove` in `handleSpike`, `executeKill`, `cancelKill`.
  - Wired `SpikeAlertState.shared.onCancel` → `cancelKill(pid:)`.
- Updated `Sources/MacGuard/Models/AppSettings.swift`:
  - Replaced local `whitelistDefaults` with `Whitelist.merging(stored)`.
- Updated `Sources/MacGuard/Views/SettingsView.swift`:
  - Replaced local `protectedDefaults` constant with `Whitelist.isProtected(entry)`.
- Updated `Sources/MacGuard/Services/ProcessKiller.swift`:
  - Replaced hard-coded `systemProtected` array with `Whitelist.isProtected(name)`. Logs SKIPPED events via Logger.
- Created `Tests/MacGuardTests/WhitelistTests.swift` — 6 XCTest cases covering protected names, arbitrary names, case sensitivity, merging with defaults, merging empty list, deduplication.
- `swift build` — `Build complete!`, zero warnings.
- `swift test` — 12/12 passed (6 ParseLine + 6 Whitelist).

### Files affected
| File | Change |
|---|---|
| `Sources/MacGuard/Utilities/Logger.swift` | Created — serial-queue logger, 5 MB rotation, entries() |
| `Sources/MacGuard/Utilities/Whitelist.swift` | Created — protectedDefaults, isProtected, merging |
| `Sources/MacGuard/Views/CountdownBannerView.swift` | Created — SpikeAlertState + CountdownBannerView + BannerRow |
| `Sources/MacGuard/Views/HistoryView.swift` | Created — History tab, Logger.entries() reader |
| `Sources/MacGuard/AppDelegate.swift` | Updated — Logger calls + SpikeAlertState wiring |
| `Sources/MacGuard/Models/AppSettings.swift` | Updated — Whitelist.merging replaces local array |
| `Sources/MacGuard/Views/SettingsView.swift` | Updated — Whitelist.isProtected replaces local constant |
| `Sources/MacGuard/Services/ProcessKiller.swift` | Updated — Whitelist.isProtected + Logger.SKIPPED |
| `Tests/MacGuardTests/WhitelistTests.swift` | Created — 6 Whitelist test cases |

---

## 2026-05-07 — Bug Fix: Process monitor never populated (waitUntilExit RunLoop hang)

### What was done
- **Root cause:** `Foundation.Process.waitUntilExit()` internally spins a `RunLoop` to receive child-process termination notifications via kqueue/kevent. Background `DispatchQueue` threads have no active `RunLoop`, so the call blocked indefinitely. Every 2-second timer fired, added another work item to `pollQueue`, but the serial queue was permanently stuck on the first item. Result: `monitor.processes` was always empty, Monitor tab showed "Scanning processes…" forever.
- **Fix in `Sources/MacGuard/Services/ProcessMonitor.swift`:**
  - Set `task.terminationHandler = { _ in }` before `task.run()`. A non-nil handler causes Foundation to reap the child via kqueue internally (no RunLoop needed on the caller's thread).
  - Removed `task.waitUntilExit()` entirely. `pipe.fileHandleForReading.readDataToEndOfFile()` blocks on a plain POSIX `read()` syscall until ps closes stdout on exit — no RunLoop required.
- Removed all diagnostic `print` breadcrumbs added during investigation.
- `swift build` — clean, zero warnings. `swift test` — 6/6 passed.
- Manual verification: Monitor tab now populates immediately on first popover open.

### Files affected
| File | Change |
|---|---|
| `Sources/MacGuard/Services/ProcessMonitor.swift` | Removed `waitUntilExit()`, added `terminationHandler = { _ in }` |

### Notes
- This bug would affect any macOS app that calls `Foundation.Process.waitUntilExit()` from a `DispatchQueue` background thread. The fix pattern (`terminationHandler` + `readDataToEndOfFile()`) is the correct approach for polling subprocesses from GCD queues.
- `spikeConfirmSamples` was temporarily lowered to 5 (10 s) for testing. Restore to 15 (30 s) before shipping.

---

## 2026-05-07 — Week 3: Menu Bar, Dashboard, Settings, Alerts

### What was done
- Created `Sources/MacGuard/AppDelegate.swift` — real AppDelegate replacing the Week 2 placeholder:
  - `NSStatusItem` with SF Symbol `cpu`, tinted green/yellow/red via `NSButton.contentTintColor` (Google palette).
  - `NSPopover` (`.transient`, 380×480) anchored below the status-item button; hosts `ContentView` via `NSHostingController`.
  - `pendingKills: [pid_t: DispatchWorkItem]` — per-PID cancellable timers. `handleSpike` arms a timer using `AppSettings.shared.killDelay` (not hardcoded 60 s — BUG-S05 fix). `executeKill` and `cancelKill` cancel the work item before or instead of killing (BUG-S06 fix).
  - Auto-kill work item re-checks the live process list at fire time; skips if the process already exited naturally.
- Created `Sources/MacGuard/Services/AlertManager.swift`:
  - `UNUserNotificationCenter` delegate singleton.
  - Registers `CPU_SPIKE` category with **Kill Now** (destructive) and **Ignore** actions in `init`.
  - `notifySpike(_:)` sends a banner notification with PID + CPU%.
  - Implements `userNotificationCenter(_:didReceive:withCompletionHandler:)` — the spec omits this, leaving action buttons silently doing nothing (BUG-S06 fix). Extracts PID from identifier `"spike-<pid>"`, calls `onKillNow` or `onIgnore` closure on main queue.
  - `willPresent` delegate method ensures banners appear even while the app is in the foreground.
- Created `Sources/MacGuard/Services/ProcessKiller.swift`:
  - `static func kill(pid:name:) -> Bool` — defense-in-depth: checks both a hard-coded `systemProtected` array and `AppSettings.shared.whitelist` before calling `Darwin.kill(pid, SIGKILL)`. Kernel_task, WindowServer, and launchd can never be killed even if UserDefaults is cleared.
- Created `Sources/MacGuard/Views/DashboardView.swift`:
  - `Color` extensions for the Google Material palette (#4285F4 blue, #34A853 green, #FBBC05 yellow, #EA4335 red, #F8F9FA surface, #202124/#5F6368 text).
  - `ContentView` — root of the popover: Google Blue header bar with status chip (green/yellow/red dot + label) + `TabView` with Monitor and Settings tabs.
  - `DashboardView` — Monitor tab: scrollable `LazyVStack` of top 20 processes sorted by CPU%.
  - `ProcessRow` — single row with status dot, process name, PID, memory MB, and CPU% in monospaced font.
- Created `Sources/MacGuard/Views/SettingsView.swift`:
  - Three card sections (CPU Threshold, Auto-Kill Delay, Whitelist) each wrapped in `SettingsCardModifier` (white card + shadow).
  - Sliders bind directly to `AppSettings.shared` `@Published` properties — changes persist to `UserDefaults` immediately via `didSet`.
  - Remove button disabled for `kernel_task`, `WindowServer`, `launchd` — UI enforces the same invariant as `ProcessKiller.systemProtected`.
  - `TextField` + plus button to add arbitrary process names to the whitelist.
- Updated `Sources/MacGuard/Services/ProcessMonitor.swift`:
  - Added `@Published var cpuLevel: CPULevel = .normal` — computed and stored on every poll so `ContentView`'s header chip observes it directly via `@EnvironmentObject`.
- Updated `Sources/MacGuard/main.swift`:
  - Removed the Week 2 placeholder `AppDelegate` class. Only the 5-line entry point remains. Real AppDelegate is now in `AppDelegate.swift`.
- `swift build` — `Build complete! (2.60s)`, zero warnings.
- `swift test` — 6/6 passed in 0.002 s, no regressions.

### Files affected
| File | Change |
|---|---|
| `Sources/MacGuard/AppDelegate.swift` | Created — NSStatusItem, NSPopover, kill-timer wiring, BUG-S05/S06 applied |
| `Sources/MacGuard/Services/AlertManager.swift` | Created — UNUserNotification + didReceive handler (BUG-S06) |
| `Sources/MacGuard/Services/ProcessKiller.swift` | Created — Darwin.kill with double whitelist guard |
| `Sources/MacGuard/Views/DashboardView.swift` | Created — ContentView (popover root) + DashboardView + ProcessRow, Google palette |
| `Sources/MacGuard/Views/SettingsView.swift` | Created — threshold/delay sliders + whitelist editor, protected defaults locked |
| `Sources/MacGuard/Services/ProcessMonitor.swift` | Updated — added @Published cpuLevel |
| `Sources/MacGuard/main.swift` | Updated — placeholder AppDelegate class removed, entry point only |

### Notes
- **Notification permissions require a proper .app bundle.** `UNUserNotificationCenter.requestAuthorization` silently fails for SPM executables without a bundle ID. The notification code is correct — it will work in Week 6 once the app is code-signed with a bundle identifier. To test the spike detection path without notifications, run `swift run` in a terminal and watch the menu-bar icon tinting.
- **Manual integration test:** Run `swift run` in a terminal with WindowServer access (not inside the IDE Bash tool). Open the menu-bar icon → popover appears with Monitor/Settings tabs. Then run `yes > /dev/null &` in another tab — within ~30 s the icon should turn red and a notification should fire (requires bundle; icon tinting always works).
- **BUG-S05 and BUG-S06 are fully resolved** in AppDelegate (killDelay from settings, DispatchWorkItem stored in pendingKills) and AlertManager (didReceive implemented).

---

## 2026-05-07 — Week 2: Core Monitoring Engine

### What was done
- Created `Sources/MacGuard/Models/MonitoredProcess.swift`:
  - `struct MonitoredProcess: Identifiable, Equatable` — uses `var id: pid_t { pid }` for stable identity across polls (SwiftUI List diffing works correctly). Named `MonitoredProcess`, not `ProcessInfo`, to avoid collision with `Foundation.ProcessInfo` (BUG-S01 fix).
  - `enum CPULevel { case normal, warning, critical }` for menu-bar icon tinting.
- Created `Sources/MacGuard/Models/AppSettings.swift`:
  - `final class AppSettings: ObservableObject` with `static let shared` singleton.
  - Defaults loaded via `loadDouble(_:default:)` which checks `.object(forKey:)` for key presence before reading the value — preserves a legitimately stored `0.0` rather than treating it as "absent" (BUG-S08 fix over spec's `nonZeroOr` extension).
  - Whitelist always merges stored entries with the three protected defaults (`kernel_task`, `WindowServer`, `launchd`), so they cannot be absent even if UserDefaults was edited directly.
- Created `Sources/MacGuard/Services/ProcessMonitor.swift`:
  - `final class ProcessMonitor: ObservableObject` with `@Published var processes`.
  - `poll()` dispatches `/bin/ps` shell-out to a dedicated `DispatchQueue(label: "macguard.monitor.poll", qos: .utility)` then brings results back via `DispatchQueue.main.async` — main thread never blocks (BUG-S02 fix).
  - `parseLine(_:)` uses `split(separator:maxSplits:3:omittingEmptySubsequences:true)` so the comm column is the entire rest of the line, preserving names with spaces like `"Google Chrome Helper (Renderer)"` (BUG-S03 fix).
  - `reapDeadPIDs(in:)` called at the end of every `detectSpikes` — prunes `spikeCounts` and `alertedPIDs` for PIDs no longer in the current ps sample, preventing unbounded growth and false alerts from recycled PIDs (BUG-S04 fix).
  - Both `runPS()` and `parseLine()` are `static` — no instance state access, safe to call from background queue.
- Updated `Sources/MacGuard/main.swift` placeholder `AppDelegate`:
  - Instantiates `ProcessMonitor(settings: AppSettings.shared)`, registers `onSpike` (prints `⚠️ SPIKE:` line) and `onUpdate` (prints level changes only, not every 2 s), stores monitor as ivar.
- `swift build` — `Build complete!` in 1.31 s, zero warnings.
- Created `Tests/MacGuardTests/ParseLineTests.swift` — 6 XCTest cases covering: well-formed line, leading whitespace, name with spaces (BUG-S03 regression guard), missing comm field, empty/whitespace line, non-numeric fields.
- Updated `Package.swift` to declare the testTarget with dependency on MacGuard (commented out pending Xcode installation — see Note below).
- `swift test` — **6/6 passed** (2026-05-07, after Xcode install + `sudo xcodebuild -license accept`). All in 0.003 s.

### Files affected
| File | Change |
|---|---|
| `Sources/MacGuard/Models/MonitoredProcess.swift` | Created — MonitoredProcess struct + CPULevel enum |
| `Sources/MacGuard/Models/AppSettings.swift` | Created — UserDefaults settings singleton |
| `Sources/MacGuard/Services/ProcessMonitor.swift` | Created — ps polling, spike detection, BUG-S02/03/04 applied |
| `Sources/MacGuard/main.swift` | Updated — wires ProcessMonitor, prints SPIKE/STATUS to stdout |
| `Tests/MacGuardTests/ParseLineTests.swift` | Created — 6 XCTest cases for parseLine |
| `Package.swift` | Updated — testTarget declared (commented out; needs Xcode) |

### Notes
- **XCTest requires Xcode:** Install Xcode from the App Store (free, ~15 GB). Once installed, run `xcode-select -s /Applications/Xcode.app/Contents/Developer`, uncomment the `.testTarget` block in `Package.swift`, and `swift test` will run all 6 cases.
- **Spike test:** Run `swift run` in one terminal tab, then `yes > /dev/null &` in another. With default threshold of 80%, `yes` should push above it and trigger `⚠️ SPIKE:` within ~30 seconds. To trigger faster, lower the threshold: `defaults write macguard.MacGuard cpuThreshold 5` (restart the app to pick up the new value).
- **Swift 6 note:** Compiling under `swift-tools-version:5.9` uses Swift 5 language mode, so concurrency warnings are informational. The DispatchQueue + main.async pattern in ProcessMonitor is correct and will not cause data races given the single-threaded mutation invariant (all `spikeCounts`/`alertedPIDs` writes happen inside `DispatchQueue.main.async`).

---

## 2026-05-06 — Week 1: Project Scaffolding Complete

### What was done
- Confirmed Swift toolchain: 6.2.3 (arm64-apple-macosx15.0) — above the 5.9 minimum.
- Created the full source directory tree:
  - `Sources/MacGuard/Models/`, `Services/`, `Views/`, `Utilities/`, `Resources/`
  - `Tests/MacGuardTests/`
- Created `Package.swift`:
  - Target: `MacGuard`, platform `.macOS(.v13)`, `path: "Sources/MacGuard"`
  - Resources/ placed inside `Sources/MacGuard/Resources/` (BUG-S07 fix — spec had it at project root, which SPM cannot resolve)
  - Resources directive and test target commented out with TODO references — enabled in Weeks 3 and 2 respectively once their first file lands
- Created `Sources/MacGuard/main.swift`:
  - Instantiates `NSApplication.shared`, attaches a placeholder `AppDelegate`, sets `.accessory` activation policy, calls `app.run()`
  - Placeholder `AppDelegate` prints `"MacGuard launched"` in `applicationDidFinishLaunching`
  - Both the entry point and placeholder class are in the same file — `AppDelegate.swift` is written fresh in Week 3 when the real AppDelegate lands
- Created `.gitignore`: covers `.build/`, `.swiftpm/`, `.DS_Store`, `xcuserdata/`, `*.xcodeproj`, `DerivedData/`
- `swift build` succeeded: `Build complete! (14.94s)` — clean, zero warnings
- Binary confirmed: `MacGuard` Mach-O 64-bit arm64 at `.build/debug/MacGuard` (74 KB)
- `swift run` produces the binary correctly; runtime output (`"MacGuard launched"`) requires a real macOS session with WindowServer access — user to verify in a terminal tab outside the IDE sandbox

### Files affected
| File | Change |
|---|---|
| `Package.swift` | Created — SPM manifest, macOS 13+ target, BUG-S07 applied |
| `Sources/MacGuard/main.swift` | Created — app entry point + Week 1 placeholder AppDelegate |
| `.gitignore` | Created — SPM + macOS + Xcode coverage |
| `Sources/MacGuard/Models/` | Directory created (empty — Week 2) |
| `Sources/MacGuard/Services/` | Directory created (empty — Week 2) |
| `Sources/MacGuard/Views/` | Directory created (empty — Week 3) |
| `Sources/MacGuard/Utilities/` | Directory created (empty — Week 4) |
| `Sources/MacGuard/Resources/` | Directory created (empty — Week 3, correct BUG-S07 location) |
| `Tests/MacGuardTests/` | Directory created (empty — Week 2) |

### Notes
- BUG-S07 applied: `Resources/` lives at `Sources/MacGuard/Resources/`, NOT at the project root as the spec shows. The `Package.swift` resources directive is commented out until Week 3 to avoid SPM warnings about an empty directory.
- Swift 6 strict concurrency mode is active by default — Week 2 code (particularly `ProcessMonitor`) will need `@MainActor` annotations or `Sendable` conformances. Watch for concurrency warnings and treat them as errors from the start rather than accumulating them.
- BUG-S01 reminder for Week 2: model file must be `MonitoredProcess.swift` naming `struct MonitoredProcess`, NOT `ProcessInfo.swift` / `struct ProcessInfo`.
