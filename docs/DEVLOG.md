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
