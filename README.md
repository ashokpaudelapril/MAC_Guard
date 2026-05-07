# 🛡️ MacGuard

A lightweight native macOS menu-bar app that watches running processes in real time, alerts you when one misbehaves, and force-quits it after a 60-second grace period.

| | |
|---|---|
| **Platform** | macOS 13 Ventura+ (Apple Silicon + Intel) |
| **Language** | Swift 5.9+ |
| **UI** | SwiftUI + AppKit |
| **Build** | Swift Package Manager (no Xcode required) |
| **Status** | Phase 1 — scaffolding (no source files yet) |

---

## Quick Start

### Prerequisites
- macOS 13 Ventura or later
- Swift 5.9+ (`xcode-select --install` is enough — no full Xcode needed)
- VS Code with the [Swift extension](https://marketplace.visualstudio.com/items?itemName=sswg.swift-lang) (optional — Xcode also works)

### Build & Run

```bash
# From the project root
swift build              # compile
swift run                # launch the menu-bar app
```

The app installs an icon in the menu bar (no Dock icon — `.accessory` activation policy). Click the icon to open the dashboard or settings.

### First Run
On first launch, macOS will ask for **Notification permission**. Grant it — without notifications, you cannot see or cancel pending auto-kills.

---

## Project Layout

```
MAC_Guard/
├── README.md                 ← this file (READ ONLY — do not edit)
├── ROADMAP.md                ← phased build plan (READ ONLY — do not edit)
├── CLAUDE.md                 ← auto-loaded by Claude Code
├── CODEX.md                  ← paste at start of Codex sessions
├── INSTRUCTIONS.md           ← paste for ChatGPT / other AIs
├── SECURITY.md               ← privacy + permissions reference (READ ONLY)
├── docs/
│   ├── PROGRESS.md           ← task checklist + SESSION BRIEFING
│   ├── DEVLOG.md             ← chronological log of every change
│   └── BUGS.md               ← issue tracker (spec-review findings live here)
├── Package.swift             ← SPM manifest (created in Week 1)
├── Sources/
│   └── MacGuard/             ← all Swift sources (created in Week 1)
│       ├── main.swift
│       ├── AppDelegate.swift
│       ├── Models/           ← MonitoredProcess, AppSettings
│       ├── Services/         ← ProcessMonitor, ProcessKiller, AlertManager
│       ├── Views/            ← DashboardView, SettingsView, CountdownBannerView
│       └── Utilities/        ← Logger, Whitelist
└── Resources/                ← menu-bar icons (green / yellow / red)
```

The source tree under `Sources/MacGuard/` is the target layout — the actual files are added phase by phase per `ROADMAP.md`.

---

## Default Configuration

All defaults are tunable from the in-app Settings panel. They persist via `UserDefaults`.

| Setting | Default | Notes |
|---|---|---|
| `cpuThreshold` | 80% | Process must exceed this CPU% to count as a spike |
| `killDelay` | 60 s | Time between alert and SIGKILL if user does not respond |
| `whitelist` | `kernel_task`, `WindowServer`, `launchd` | Never auto-killed |
| Poll interval | 2 s (hardcoded) | `ps` is sampled every 2 s |
| Spike confirmation | 15 samples = 30 s (hardcoded) | Prevents false positives from short bursts |

---

## Docs Index

| File | Purpose |
|---|---|
| [`ROADMAP.md`](./ROADMAP.md) | 4-phase build plan with prompt templates per task |
| [`docs/PROGRESS.md`](./docs/PROGRESS.md) | Live task checklist + SESSION BRIEFING for AI handoff |
| [`docs/DEVLOG.md`](./docs/DEVLOG.md) | Dated log of every change made |
| [`docs/BUGS.md`](./docs/BUGS.md) | Open issues + spec-review findings |
| [`SECURITY.md`](./SECURITY.md) | Permissions, kill safety, code-signing notes |
| [`CLAUDE.md`](./CLAUDE.md) | Project context auto-loaded by Claude Code |

---

## Known Limitations

- SIGKILL on system processes (`kernel_task`, `WindowServer`) is blocked by macOS — they are pre-whitelisted.
- `ps`-based polling is approximate — Activity Monitor uses private APIs for tighter accuracy.
- Killing a process with unsaved state (e.g. Safari) may cause data loss — the user is warned in the notification banner.
- Code signing + notarization are required for distribution but not for local development. See `SECURITY.md`.
