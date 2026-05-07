# Canvas AI — Development Log

A running log of everything built, changed, or fixed. Read top-to-bottom for the full history, or jump to the latest entry at the bottom.

**Format per entry:**
- Date
- What was done
- Files affected
- Notes / decisions made

---

## 2026-03-16 — Project Setup & Documentation

### What was done
- Explored the initial project structure (frontend, backend, docker-compose, README)
- Removed an accidental empty folder `{frontend` that was created by a malformed `mkdir -p` brace expansion command
- Converted `Canvas_AI_Platform_Roadmap.docx` → `ROADMAP.md` using pandoc, then rewrote it with clean markdown formatting
- Created `docs/` folder and this `DEVLOG.md` file
- Updated `README.md` to link to `ROADMAP.md` and `DEVLOG.md`

### Files affected
| File | Change |
|---|---|
| `{frontend/` | Deleted (accidental artifact) |
| `ROADMAP.md` | Created — converted from Canvas_AI_Platform_Roadmap.docx |
| `docs/DEVLOG.md` | Created — this file |
| `README.md` | Updated — added links to ROADMAP and DEVLOG |

### Notes
- Project is currently at **Phase 1** (Foundation & Canvas Auth)
- The existing codebase already has the scaffolding in place (routes, services, pages) — ready to start wiring up features
- `Canvas_AI_Platform_Roadmap.docx` kept in root as original source; `ROADMAP.md` is the canonical reference going forward

---

## 2026-03-16 — Documentation & AI Instructions Setup

### What was done
- Created `docs/PROGRESS.md` — full task checklist for all 4 phases / 16 weeks with checkboxes
- Created `CLAUDE.md` — auto-loaded by Claude Code at every session start; contains project context, file map, session rules, and code commenting conventions
- Created `INSTRUCTIONS.md` — same content as CLAUDE.md, for pasting into Codex/ChatGPT/other AI sessions
- Deleted `Canvas_AI_Platform_Roadmap.docx` — no longer needed, content lives in ROADMAP.md

### Files affected
| File | Change |
|---|---|
| `docs/PROGRESS.md` | Created — task checklist per phase/week |
| `CLAUDE.md` | Created — AI session instructions (auto-loaded by Claude Code) |
| `INSTRUCTIONS.md` | Created — AI session instructions (paste for other AIs) |
| `Canvas_AI_Platform_Roadmap.docx` | Deleted — converted content lives in ROADMAP.md |

### Notes
- Commenting convention established: use `ISSUE` / `FIX APPLIED` for bug fixes, `TASK` / `HOW CODE SOLVES` for new code
- README and ROADMAP are locked — AI should never edit them unless explicitly asked

<!-- Add new entries below this line -->

---

## 2026-03-16 — Full Codebase Bug Audit → docs/BUGS.md

### What was done
- Performed a full static audit of all files in `backend/src/` and `frontend/src/`
- Identified 40 issues across 4 severity levels (4 Critical, 11 High, 9 Medium, 8 Low)
- Created `docs/BUGS.md` — a standalone issue tracker with: description, file + line, and concrete code-level fix for every issue

### Files affected
| File | Change |
|---|---|
| `docs/BUGS.md` | Created — full bug tracker with 40 issues and suggested fix order |

### Notes
- Most critical issues are in the OAuth/token flow (BUG-01 through BUG-04) — these overlap directly with the Week 2 task and should be fixed during that work
- BUG-08 through BUG-11 are the same null-pointer pattern repeated across 4 routes — fix all four in one pass
- BUG-12 (courseId UUID mismatch) will silently break all chat sessions — high priority when wiring chat
- BUG-39 (settings wipe) is a data-loss bug — fix before SettingsPage goes live

---

## 2026-03-16 — Week 1 Complete: frontend/.env.example + SESSION BRIEFING Updated

### What was done
- Created `frontend/.env.example` — documents `VITE_API_URL` as the only required frontend env var
- Noted that `frontend/src/lib/api.ts` uses a relative `/api` base URL (Vite dev proxy handles routing to backend), so `VITE_API_URL` is only needed for production builds
- Updated `docs/PROGRESS.md` SESSION BRIEFING — marked Week 1 done, set Week 2 (Canvas OAuth2 Login) as the next task with full step-by-step instructions

### Files affected
| File | Change |
|---|---|
| `frontend/.env.example` | Created — `VITE_API_URL` with explanation of Vite proxy behavior |
| `docs/PROGRESS.md` | SESSION BRIEFING updated — Week 1 closed, Week 2 queued |

### Notes
- **Week 1 is fully complete.** All five scaffolding tasks are checked off.
- Next session starts at Week 2: Canvas OAuth2 Login. The SESSION BRIEFING has the full task breakdown.
- Before starting Week 2, the user should: (1) run `npm install` in `frontend/` and `backend/` to install ESLint/Prettier packages, (2) confirm `npm run lint` passes in both packages

---

## 2026-03-16 — SESSION BRIEFING System Added to PROGRESS.md

### What was done
- Redesigned the top of `docs/PROGRESS.md` — replaced the thin "Current Focus" block with a full **SESSION BRIEFING** block containing: last completed task, next task with specific instructions, files to create/reference, and blockers
- Updated session start rules in `CLAUDE.md`, `INSTRUCTIONS.md`, and `CODEX.md` — all three now instruct the AI to read the SESSION BRIEFING first, not scan the full checklist
- Updated session end rules in all three files — the AI must now rewrite the SESSION BRIEFING block at the end of every session, not just check off tasks

### Files affected
| File | Change |
|---|---|
| `docs/PROGRESS.md` | Redesigned top section — added SESSION BRIEFING block |
| `CLAUDE.md` | Updated session start + end rules to use SESSION BRIEFING |
| `INSTRUCTIONS.md` | Updated session start + end rules to use SESSION BRIEFING |
| `CODEX.md` | Updated session start + end rules to use SESSION BRIEFING |

### Notes
- The SESSION BRIEFING is the "you are here + go here next" marker. Every AI session should open and close by reading/writing this block.
- The full checklist below it is still maintained for historical tracking, but the AI should not need to scan it to get started

---

## 2026-03-16 — Privacy, Security & Codex Setup

### What was done
- Created root `.gitignore` — blocks `.env` files, `node_modules`, build artifacts, OS junk, and `backend/uploads/` from version control
- Created `SECURITY.md` — full secrets inventory (what each secret is, where it lives, how it's protected), rotation instructions, rules for AI assistants, and a list of files safe to commit
- Updated `CLAUDE.md` — added **Privacy & Security Rules** section and **Debugging Best Practices** section; updated file map to include new files
- Updated `INSTRUCTIONS.md` — same additions as CLAUDE.md
- Created `CODEX.md` — full project context formatted specifically for OpenAI Codex sessions; includes a note that Codex should always provide Bruno `.bru` files alongside new routes since it cannot run code itself

### Files affected
| File | Change |
|---|---|
| `.gitignore` | Created — root-level, covers both frontend and backend |
| `SECURITY.md` | Created — secrets inventory + security rules + rotation guide |
| `CLAUDE.md` | Updated — added Privacy/Security + Debugging sections; updated file map |
| `INSTRUCTIONS.md` | Updated — same additions as CLAUDE.md |
| `CODEX.md` | Created — full context for OpenAI Codex sessions |

### Notes
- `.gitignore` uses `!.env.example` to explicitly allow example files while blocking real `.env` files
- `SECURITY.md` is marked READ ONLY in all AI instruction files — AI assistants should not edit it
- `CODEX.md` differs from `CLAUDE.md` in one important way: it instructs Codex to always ask the user to paste existing files before writing code (since Codex has no file access), and to always provide Bruno `.bru` files alongside new routes

---

## 2026-03-16 — ESLint + Prettier + Bruno Testing Setup

### What was done
- Established a testing baseline: manual smoke test → Bruno API testing → Jest+supertest integration tests (later) → Playwright e2e (Phase 3)
- Added ESLint + Prettier to both frontend and backend
- Created a shared `.prettierrc` at the project root (inherited by both packages)
- Created `frontend/.eslintrc.cjs` (must use `.cjs` extension because frontend has `"type": "module"`)
- Created `backend/.eslintrc.js`
- Added `lint`, `lint:fix`, and `format` scripts to both `package.json` files
- Added all ESLint + Prettier packages to `devDependencies` in both packages
- Created `bruno/canvas-ai-api/` collection with first request: `GET /api/health` (smoke test gate #1 for every feature)

### Files affected
| File | Change |
|---|---|
| `.prettierrc` | Created — shared Prettier config (singleQuote, semi, tabWidth: 2, printWidth: 100) |
| `frontend/.eslintrc.cjs` | Created — React + TypeScript ESLint rules |
| `frontend/package.json` | Updated — added eslint/prettier devDeps + lint:fix + format scripts |
| `backend/.eslintrc.js` | Created — Node.js + TypeScript ESLint rules |
| `backend/package.json` | Updated — added eslint/prettier devDeps + lint + lint:fix + format scripts |
| `bruno/canvas-ai-api/bruno.json` | Created — Bruno collection config |
| `bruno/canvas-ai-api/health-check.bru` | Created — GET /api/health smoke test request |

### Notes
- `eslint-config-prettier` is last in every `extends` array — this is intentional and critical; it disables ESLint formatting rules that would conflict with Prettier
- Testing strategy decided: Bruno for manual API testing (one saved request per route), Jest+supertest for automated backend tests, Playwright for e2e in Phase 3
- Run `npm install` in both `frontend/` and `backend/` before using lint/format scripts
