# MacGuard — Progress Tracker

> **AI assistants: Read the SESSION BRIEFING block first. It tells you exactly where we are
> and what to do next. Do not start any task until you have read it.**

---

## SESSION BRIEFING
> This block is updated at the end of every session. It is the single source of truth
> for what happens next. Update all four fields whenever a task is completed.

### Last Completed Task
- **Task:** Project documentation initialized — 9 reference templates tailored from `References/` to MacGuard's stack (Swift / SPM / SwiftUI / macOS — local-only)
- **Completed:** 2026-05-06
- **What was done:** Wrote `README.md`, `CLAUDE.md`, `CODEX.md`, `INSTRUCTIONS.md`, `SECURITY.md`, `ROADMAP.md`, `docs/PROGRESS.md`, `docs/DEVLOG.md`, `docs/BUGS.md` at the project root. `BUGS.md` is pre-seeded with 10 spec-review findings (BUG-S01–BUG-S10) that must be applied while typing in source from `MacGuard_Developer_Spec.docx`. No Swift source has been written yet.

### Next Task — Start Here
- **Task:** Week 1 — Project Scaffolding: create `Package.swift`, the `Sources/MacGuard/` directory tree, a stub `main.swift`, and verify the project builds and runs as a menu-bar accessory app.
- **Phase / Week:** Phase 1 / Week 1 — Project Scaffolding
- **What to do:**
  1. Create `Package.swift` at the project root for a macOS 13+ executable target named `MacGuard`. Use `path: "Sources/MacGuard"` and resources `[.process("Resources")]` — and ⚠️ make sure the `Resources/` folder lives at `Sources/MacGuard/Resources/`, NOT at the project root, or SPM will fail to find it. See **BUG-S07**.
  2. Create the directory tree: `mkdir -p Sources/MacGuard/{Models,Services,Views,Utilities} Sources/MacGuard/Resources Tests/MacGuardTests`.
  3. Write a stub `Sources/MacGuard/main.swift`: instantiate `NSApplication.shared`, attach a placeholder `AppDelegate`, set `setActivationPolicy(.accessory)`, call `app.run()`. The placeholder `AppDelegate` should `print("MacGuard launched")` in `applicationDidFinishLaunching`.
  4. Write a `.gitignore` covering `.build/`, `.swiftpm/`, `.DS_Store`, `xcuserdata/`. Keep `Package.resolved` checked in.
  5. Run `swift build` then `swift run` — confirm `MacGuard launched` prints and the process stays alive (Ctrl-C to quit).
- **Files to create:** `Package.swift`, `Sources/MacGuard/main.swift`, `.gitignore`
- **Files to reference:** `MacGuard_Developer_Spec.docx` sections 3 (Package.swift) and 4.1 (main.swift); `docs/BUGS.md` BUG-S07
- **Blockers / Prerequisites:** Confirm `swift --version` reports 5.9+. If it reports an older version, run `xcode-select --install` to refresh the toolchain.
- **⚠️ Read first:** `docs/BUGS.md` — BUG-S07 directly affects the `Package.swift` you are about to write. The other findings (BUG-S01 through BUG-S10) become relevant in Week 2 onward but are worth scanning now.

### After That
- **Task:** Week 2 — Core Monitoring: `Models/MonitoredProcess.swift`, `Models/AppSettings.swift`, `Services/ProcessMonitor.swift`. End state: spikes print to stdout when `yes > /dev/null &` runs.

---

## Phase 1 — Foundation *(Weeks 1–2)*

### Week 1 — Project Scaffolding
- [ ] `Package.swift` (SPM manifest with `.macOS(.v13)` and resources directive — apply BUG-S07)
- [ ] Source directory tree (`Sources/MacGuard/{Models,Services,Views,Utilities,Resources}`, `Tests/MacGuardTests`)
- [ ] Stub `main.swift` (creates app, attaches placeholder AppDelegate, accessory activation policy)
- [ ] `.gitignore` (`.build/`, `.swiftpm/`, `.DS_Store`, `xcuserdata/`)
- [ ] `swift build && swift run` succeeds and prints "MacGuard launched"

### Week 2 — Core Monitoring (no UI yet)
- [ ] `Models/MonitoredProcess.swift` (use `MonitoredProcess`, NOT `ProcessInfo` — BUG-S01)
- [ ] `Models/AppSettings.swift` (private init + `.shared`, immutable whitelist defaults — BUG-S08)
- [ ] `Services/ProcessMonitor.swift` (background queue for `ps` — BUG-S02; rest-of-line `comm` parse — BUG-S03; reap dead PIDs — BUG-S04)
- [ ] Wire monitor into `main.swift` so spikes print to stdout
- [ ] Manual spike test: `yes > /dev/null &` triggers a SPIKE log within ~30 s
- [ ] XCTest cases for `parseLine` (`Tests/MacGuardTests/ParseLineTests.swift`)

---

## Phase 2 — UI & Alerts *(Week 3)*

### Week 3 — Menu Bar, Dashboard, Settings, Alerts
- [ ] Menu-bar status item with green/yellow/red SF Symbol tint (`AppDelegate.updateMenuBarIcon`)
- [ ] `AppDelegate.swift` (use `settings.killDelay`, not 60 — BUG-S05; cancellable `DispatchWorkItem` — BUG-S06)
- [ ] `Views/DashboardView.swift` + `ProcessRow` (use `MonitoredProcess` per BUG-S01)
- [ ] `Views/SettingsView.swift` (Remove button disabled for the three protected defaults)
- [ ] `Services/AlertManager.swift` (with `userNotificationCenter(_:didReceive:withCompletionHandler:)` for KILL/IGNORE — BUG-S06)
- [ ] `Services/ProcessKiller.swift` (defense-in-depth whitelist guard before `Darwin.kill`)
- [ ] Manual integration test: yes spike → red icon → notification → Kill Now/Ignore both behave correctly

---

## Phase 3 — Persistence & Polish *(Week 4)*

### Week 4 — Logger, History UI, Hardening
- [ ] `Utilities/Logger.swift` (serial dispatch queue — BUG-S09; 5 MB log rotation)
- [ ] `Utilities/Whitelist.swift` (`protectedDefaults`, `isProtected`, `merging` — BUG-S10)
- [ ] `Views/CountdownBannerView.swift` (referenced in spec layout but never implemented — BUG-S10)
- [ ] History window (`HistoryView` reads `~/Library/Application Support/MacGuard/history.log`)
- [ ] Settings persistence smoke test (quit + relaunch retains values)
- [ ] `Logger.shared.log(...)` calls wired at: alert, manual kill, auto-kill, cancelled kill, skipped kill

---

## Phase 4 — Distribution & Extensions *(Weeks 5+)*

### Week 5 — Optional Extensions (pick 2–3)
- [ ] Launch on login via `SMAppService` toggle in Settings
- [ ] CSV export of history (parse log file, `NSSavePanel`)
- [ ] 60-second CPU sparkline on the dashboard
- [ ] Memory-pressure alerts via `host_statistics(HOST_VM_INFO)`
- [ ] Per-app CPU budgets (extend `AppSettings` + spike state machine)

### Week 6 — Code Signing & Distribution
- [ ] Apple Developer ID Application certificate
- [ ] `scripts/build-release.sh` (release build + `.app` wrap + codesign + notarize + staple)
- [ ] Hardened runtime entitlements plist (minimal — no sandbox for v1)
- [ ] `SECURITY.md` updated with production signing identity reference
- [ ] README "Releases" section pointing at signed download

---

## Notes & Decisions Log

> Add any architectural decisions, tradeoffs, or important notes here.

| Date | Note |
|---|---|
| 2026-05-06 | Project initialized with documentation only. References/ contained Canvas-AI templates (Node/React stack) that were re-shaped for MacGuard's Swift/SPM/macOS stack. References/ retained for reference; never edit. |
| 2026-05-06 | Decision: keep the project as SPM-only (no `.xcodeproj` checked in). VS Code with the Swift extension is the primary editing environment. Xcode users can `swift package generate-xcodeproj` locally without committing the result. |
| 2026-05-06 | Decision: rename the spec's `ProcessInfo` struct to `MonitoredProcess` to avoid collision with `Foundation.ProcessInfo` — see BUG-S01. All future references in source must use `MonitoredProcess`. |
