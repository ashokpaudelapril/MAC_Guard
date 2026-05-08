# MacGuard — Progress Tracker

> **AI assistants: Read the SESSION BRIEFING block first. It tells you exactly where we are
> and what to do next. Do not start any task until you have read it.**

---

## SESSION BRIEFING
> This block is updated at the end of every session. It is the single source of truth
> for what happens next. Update all four fields whenever a task is completed.

### Last Completed Task
- **Task:** Week 6 — Code Signing & Distribution Scaffolding complete
- **Completed:** 2026-05-07
- **What was done:** Created `Info.plist` (LSUIElement=true, NSUserNotificationAlertStyle=alert, bundleID=com.ashokpaudel.MacGuard), `MacGuard.entitlements` (hardened runtime, no sandbox — sandboxing blocks /bin/ps and Darwin.kill), `scripts/build-release.sh` (7-step: universal build → .app assembly → codesign → verify → zip → notarytool submit → stapler staple). Added `dist/` to `.gitignore`. `swift build` still clean (0.23s incremental).

### Next Task — Start Here
- **Task:** Run the release build once you have a Developer ID cert
- **Phase / Week:** Phase 4 / Week 6 (final step)
- **What to do:**
  1. Obtain an Apple Developer ID Application certificate from developer.apple.com (requires paid $99/year Apple Developer Program membership).
  2. Store notarization credentials: `xcrun notarytool store-credentials "macguard-notarize" --apple-id "you@example.com" --team-id "TEAMID" --password "app-specific-password"`
  3. Edit the `DEVELOPER_ID` variable at the top of `scripts/build-release.sh` to match your certificate CN (check with `security find-identity -v -p codesigning`).
  4. Run `./scripts/build-release.sh` from the project root.
  5. Verify `dist/MacGuard.app` passes: `spctl --assess --type execute dist/MacGuard.app`
  6. Test the full notification flow for the first time: spike → banner → Kill Now / Ignore (bundle ID now present).
  7. Test Launch at Login toggle in Settings (SMAppService now works with signed bundle).
  8. Update `SECURITY.md` with the production signing identity.
  9. Update `README.md` "Releases" section.
- **Files to modify:** `scripts/build-release.sh` (DEVELOPER_ID variable), `SECURITY.md`, `README.md`
- **Blockers / Prerequisites:** Apple Developer account. All app logic is complete and tested.

### After That
- **Task:** Post-distribution extensions — memory-pressure alerts, per-app CPU budgets, CSV export filtering

---

## Phase 1 — Foundation *(Weeks 1–2)*

### Week 1 — Project Scaffolding ✅
- [x] `Package.swift` (SPM manifest with `.macOS(.v13)`, BUG-S07 applied — Resources/ inside target path)
- [x] Source directory tree (`Sources/MacGuard/{Models,Services,Views,Utilities,Resources}`, `Tests/MacGuardTests`)
- [x] Stub `main.swift` (creates app, attaches placeholder AppDelegate, `.accessory` activation policy)
- [x] `.gitignore` (`.build/`, `.swiftpm/`, `.DS_Store`, `xcuserdata/`, `*.xcodeproj`)
- [x] `swift build` → `Build complete! (14.94s)`, zero warnings. Binary: arm64 Mach-O, 74 KB.

### Week 2 — Core Monitoring (no UI yet) ✅
- [x] `Models/MonitoredProcess.swift` (`MonitoredProcess` + `CPULevel`, pid-as-id, BUG-S01 applied)
- [x] `Models/AppSettings.swift` (key-presence defaults, whitelist merge with protected defaults, BUG-S08 applied)
- [x] `Services/ProcessMonitor.swift` (background pollQueue + main dispatch, split maxSplits:3, reapDeadPIDs — BUG-S02/S03/S04 applied)
- [x] `main.swift` updated — wires ProcessMonitor, prints SPIKE/STATUS lines to stdout
- [x] `swift build` — `Build complete!` zero warnings
- [x] `Tests/MacGuardTests/ParseLineTests.swift` written — 6 cases (well-formed, whitespace, spaces in name, missing comm, empty, malformed numerics)
- [x] `swift test` — 6/6 passed in 0.003 s (2026-05-07, Xcode installed)

---

## Phase 2 — UI & Alerts *(Week 3)*

### Week 4 — Logger, History UI, Hardening ✅
- [x] `Utilities/Logger.swift` (serial DispatchQueue, 5 MB rotation — BUG-S09)
- [x] `Utilities/Whitelist.swift` (single source of truth for protected names — BUG-S10)
- [x] `Views/CountdownBannerView.swift` + `SpikeAlertState` (live countdown with Cancel — BUG-S10)
- [x] `Views/HistoryView.swift` (History tab, reads log newest-first, Refresh button)
- [x] Logger wired at all 5 event sites: ALERT, AUTO-KILL, KILL-NOW, IGNORED, SKIPPED
- [x] `swift build` — clean, zero warnings
- [x] `swift test` — 12/12 passed (6 ParseLine + 6 Whitelist)

### Week 3 — Menu Bar, Dashboard, Settings, Alerts ✅
- [x] Menu-bar status item with green/yellow/red SF Symbol tint (`AppDelegate.updateMenuBarIcon`)
- [x] `AppDelegate.swift` (use `settings.killDelay`, not 60 — BUG-S05; cancellable `DispatchWorkItem` — BUG-S06)
- [x] `Views/DashboardView.swift` + `ProcessRow` (use `MonitoredProcess` per BUG-S01) + Google Material theme
- [x] `Views/SettingsView.swift` (Remove button disabled for the three protected defaults)
- [x] `Services/AlertManager.swift` (with `userNotificationCenter(_:didReceive:withCompletionHandler:)` for KILL/IGNORE — BUG-S06)
- [x] `Services/ProcessKiller.swift` (defense-in-depth whitelist guard before `Darwin.kill`)
- [ ] Manual integration test: yes spike → red icon → notification → Kill Now/Ignore both behave correctly (notification requires signed .app — defer to Week 6; icon tinting testable now)

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

### Week 5 — Optional Extensions ✅
- [x] Launch on login via `SMAppService` toggle in Settings (reverts gracefully when unsigned)
- [x] CSV export of history (`Logger.exportCSV()` + `NSSavePanel` in HistoryView)
- [x] 60-second CPU sparkline on the dashboard (`SparklineView`, 30-sample rolling history)
- [ ] Memory-pressure alerts via `host_statistics(HOST_VM_INFO)`
- [ ] Per-app CPU budgets (extend `AppSettings` + spike state machine)

### Week 6 — Code Signing & Distribution
- [ ] Apple Developer ID Application certificate (requires $99/year Apple Developer account)
- [x] `scripts/build-release.sh` (release build + `.app` wrap + codesign + notarize + staple)
- [x] `Info.plist` (LSUIElement, NSUserNotificationAlertStyle=alert, bundleID)
- [x] `MacGuard.entitlements` (hardened runtime, no sandbox — documented why)
- [ ] Run `build-release.sh` end-to-end with a real certificate
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
