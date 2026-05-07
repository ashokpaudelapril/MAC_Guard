# MacGuard — Security & Safety Reference

This file documents the safety-relevant surfaces of MacGuard: the permissions it requests, the destructive operations it can perform, and the rules every contributor (human or AI) must follow.

Read this before onboarding a collaborator or starting a new AI coding session.

---

## Threat Model — What's Different About This App

Unlike a typical web project, MacGuard has **no API keys, no remote secrets, and no database**. There is no breach surface for credentials.

But MacGuard has a different sharp edge: **it sends `SIGKILL` to user processes on the local machine.** A bug in the spike detector, the whitelist matcher, or the timer logic can kill processes the user is actively using and lose their unsaved work.

The security work here is therefore about:
1. Keeping the kill path narrow and intentional
2. Keeping the whitelist load-bearing and honest
3. Never executing user-supplied data as a shell command
4. Never sending data off the device

---

## Permissions Inventory

| Permission | Required For | Where It's Requested |
|---|---|---|
| User Notifications | Showing the spike alert with Kill Now / Ignore action buttons | `AlertManager.requestPermission()` on first launch |
| Sending signals (`kill(2)`) | Force-quitting a runaway process | Always allowed for processes the user owns; macOS itself blocks SIGKILL on protected system processes (`kernel_task`, `WindowServer`, etc.) |
| Reading process list (`/bin/ps`) | Building the dashboard and detecting spikes | Always allowed — `ps` is a public binary, no entitlement needed |
| Writing to `~/Library/Application Support/MacGuard/` | Persisting `history.log` | Always allowed — this is the user's own home directory |
| `UserDefaults` access | Persisting settings (`cpuThreshold`, `killDelay`, `whitelist`) | Always allowed |

**Permissions NOT used:**
- Full Disk Access — not needed
- Accessibility — not needed
- Network — not used at all (no `URLSession`, no sockets)
- Camera / Microphone / Location — never
- File-system bookmarks outside `~/Library/Application Support/MacGuard/` — never

---

## The Kill Path — Hard Rules

The destructive code path is `Darwin.kill(pid, SIGKILL)`. Every call to it must satisfy ALL of these conditions:

1. The process appeared in **at least 15 consecutive `ps` samples** (= 30 s) with CPU% above `AppSettings.cpuThreshold`. No exceptions.
2. The process name is **not** in `AppSettings.whitelist`. The default whitelist (`kernel_task`, `WindowServer`, `launchd`) must always be present — the Settings UI must refuse to remove these defaults.
3. **At least `AppSettings.killDelay` seconds elapsed** since the alert notification was delivered, OR the user explicitly tapped "Kill Now" in the notification.
4. The process **is still spiking** at the moment the timer fires — re-check `spikeCounts[pid] > 0` immediately before the kill, and abort if it has dropped below threshold.
5. Notification permission was **granted**. If denied, the auto-kill timer must not fire — instead, log a single-line warning and skip the kill.

If any of those preconditions cannot be checked, **do not kill**. Log the abort reason and surface it in the dashboard.

---

## Whitelist Integrity Rules

The whitelist is the single most important safety guard. These rules apply whenever the whitelist is read or written:

- The default entries (`kernel_task`, `WindowServer`, `launchd`) are **immutable defaults** — the Settings UI must allow adding more, never removing these three.
- Whitelist matching is **exact case-sensitive equality** on the `comm` value reported by `ps`. Substring matching is forbidden — it would let a malicious process named `kernel_task_helper` trip a false-positive match in the wrong direction.
- A whitelist write that produces an empty array is a bug — replace with the defaults and log the recovery.
- Future feature: also pre-whitelist the user's foreground process (the one currently focused) so the active app cannot be auto-killed mid-keystroke.

---

## Shell-Injection Rules

The only external command MacGuard executes is `/bin/ps`. The launch must always look exactly like this:

```swift
let task = Process()
task.launchPath = "/bin/ps"
task.arguments  = ["-axo", "pid=,pcpu=,rss=,comm="]
```

- `launchPath` is always the literal `"/bin/ps"`. Never `process.launchPath = someVar`.
- `arguments` is always a literal array of literal strings. Never built from user input or process names.
- Do not switch to `Process.run()` with a shell (`/bin/sh -c`) — that opens a shell-injection door.
- Do not add a fallback to `top`, `iostat`, or any other binary without an entry in this file.

---

## Data Persistence — What Lives On Disk

| Path | Contents | Sensitivity |
|---|---|---|
| `~/Library/Application Support/MacGuard/history.log` | Timestamped alerts and kill events: `[ISO8601] AUTO-KILL: <name> [PID <n>]` | Local-only. Process names are visible to anyone with read access to the user's home directory — same threat model as `~/.zsh_history`. |
| `UserDefaults` (per-app plist in `~/Library/Preferences/`) | `cpuThreshold`, `killDelay`, `whitelist` array | Local-only, not sensitive. |

**Rules for the log file:**
- Never write a process's full command line — `comm` (basename only) is sufficient and avoids leaking file paths.
- Never write to `os_log` at `.public` level for any field that came from a process name — those go to the unified log and may be visible to other users on the system.
- Add log rotation when `history.log` exceeds 5 MB (Phase 3, Week 5 task).

---

## Code Signing & Distribution

For local development you do **not** need to sign or notarize the app — `swift run` produces a debug binary that runs as the current user.

For distribution:
1. **Code signing** — Required by Gatekeeper. Use an Apple Developer ID Application certificate.
2. **Notarization** — Required for distribution outside the Mac App Store. Submit via `xcrun notarytool`.
3. **Hardened runtime + entitlements** — Required for notarization. The minimum entitlement set is empty (no special capabilities). Do NOT add `com.apple.security.cs.disable-library-validation` or other relaxed entitlements unless a future feature genuinely needs it.
4. **App Sandbox** — Optional. If enabled, you must add the `process-info` and `process-control` entitlements; sandboxing process killing is rare and may require extra capabilities.

A future Phase 4 task covers signing + notarization in detail. Until then, distribution is local-only.

---

## AI Assistants — Safety Rules

When any AI (Claude, Codex, ChatGPT, Gemini) works on this project it must follow these rules:

- **Never widen the kill path** — every condition under "The Kill Path — Hard Rules" must remain satisfied after every change.
- **Never weaken whitelist matching** — substring/regex matching is forbidden; the defaults (`kernel_task`, `WindowServer`, `launchd`) must always be present.
- **Never invoke a shell** with user-supplied input. The only `Process` launch is `/bin/ps` with literal arguments.
- **Never add network code.** No `URLSession`, no `Network.framework`, no analytics SDK, no crash reporter that uploads.
- **Never log full command lines** to either the local log file or `os_log`.
- **Never hardcode** `cpuThreshold` (80) or `killDelay` (60) in source — always read from `AppSettings`.
- If you see existing code that violates any of these rules (including in `MacGuard_Developer_Spec.docx`), flag it as a security/safety issue before doing anything else.

---

## Files That Are Safe to Commit

| File | Why It's Safe |
|---|---|
| `Package.swift` | Build manifest, no secrets |
| All sources under `Sources/MacGuard/` | Application code, no secrets |
| `Resources/Assets.xcassets/` | Icon assets, no secrets |
| All Markdown in the project root and `docs/` | Documentation, no secrets |
| `MacGuard_Developer_Spec.docx` | Original spec, no secrets |

**There are no `.env` files in this project** — there are no environment-driven secrets to manage.

---

## Quick Self-Check Before Merging

Before merging or shipping a change, walk through:

- [ ] Does this change call `Darwin.kill`? If yes, do all 5 hard-rule preconditions still hold?
- [ ] Does this change touch the whitelist? If yes, are the three defaults still preserved?
- [ ] Does this change add a `Process` launch? If yes, is `launchPath` a literal and `arguments` a literal array?
- [ ] Does this change add a network call? If yes, **revert it** — that is out of scope.
- [ ] Does this change log process information? If yes, is it `comm` only (no full command lines)?
- [ ] Does this change touch `cpuThreshold` or `killDelay`? If yes, is the value still read from `AppSettings`?
