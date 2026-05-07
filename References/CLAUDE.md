# Canvas AI — AI Instructions

This file gives you full project context. Read it before doing anything else.

---

## How AI Sessions Work in This Project

This project is built across many sessions using multiple AI assistants (Claude Code, Codex, ChatGPT).
**No AI has memory between sessions.** The docs folder is the shared memory.

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

An AI-powered learning assistant built on top of Canvas LMS. Students get quizzes, summaries, notes, flashcards, and AI chat — all powered by their actual course content pulled from Canvas.

**Stack:**
- Frontend: React + TypeScript + Tailwind (Vite) — port 3000
- Backend: Node.js + Express + TypeScript — port 4000
- Database: PostgreSQL (port 5432) + Redis (port 6379) via Docker
- Auth: Canvas OAuth2 + JWT
- AI: LLM-agnostic adapter layer (Groq, Gemini, OpenRouter, Ollama, OpenAI, Anthropic)

---

## Project File Map

```
canvas-ai/
├── CLAUDE.md                  ← This file (auto-loaded by Claude Code)
├── CODEX.md                   ← Same context, formatted for OpenAI Codex sessions
├── INSTRUCTIONS.md            ← Same context, paste this for ChatGPT / other AIs
├── SECURITY.md                ← Secrets inventory + security rules. READ ONLY — do not edit.
├── ROADMAP.md                 ← Full 16-week build plan. READ ONLY — do not edit.
├── README.md                  ← Setup guide. READ ONLY — do not edit.
├── .gitignore                 ← Blocks .env files and secrets from version control
├── .prettierrc                ← Shared Prettier formatting config
├── docker-compose.yml         ← Postgres + Redis
├── bruno/canvas-ai-api/       ← Bruno API test collection (one .bru file per route)
├── docs/
│   ├── PROGRESS.md            ← Task checklist per phase/week. Update as tasks complete.
│   └── DEVLOG.md              ← Chronological log of every change made. Update every session.
├── frontend/src/
│   ├── pages/                 ← LoginPage, DashboardPage, CoursePage, ChatPage, QuizPage, ToolsPage, SettingsPage
│   ├── components/            ← Reusable UI components
│   ├── hooks/                 ← useAuth and other custom hooks
│   └── lib/api.ts             ← Axios client
└── backend/src/
    ├── index.ts               ← Express entry point
    ├── routes/                ← auth.ts, courses.ts, chat.ts, quiz.ts, tools.ts, user.ts
    ├── services/              ← canvas.service.ts, ai.service.ts
    ├── middleware/            ← auth middleware, error handler
    └── models/                ← db.ts, schema.sql
```

---

## Current Status

- **Active Phase:** Phase 1 — Foundation & Canvas Auth
- **Active Week:** Week 1 — Project Scaffolding
- Check `docs/PROGRESS.md` for the full task checklist and what has been completed.
- Check `docs/DEVLOG.md` for a log of everything that has been changed so far.

---

## Rules — Follow These Every Session

### At the start of every session
1. Read `docs/PROGRESS.md` — go straight to the **SESSION BRIEFING** block at the top. It tells you the last completed task and exactly what to do next. Do not scan the full checklist until you need to.
2. Read the latest entry in `docs/DEVLOG.md` to understand what changed most recently
3. Confirm the next task with the user before writing any code — the SESSION BRIEFING is the default, but the user may want something different

### At the end of every session (or after any change)
1. Update `docs/DEVLOG.md` — add a dated entry with what was changed and which files were affected
2. Update `docs/PROGRESS.md` — check off completed tasks AND rewrite the **SESSION BRIEFING** block with: what was just completed, what the next task is, which files to touch, and any blockers

### Never touch these files unless explicitly asked
- `README.md`
- `ROADMAP.md`

---

## Code Commenting Rules

Every piece of code you write or modify **must include a comment block** using one of these two formats:

### For bug fixes / debugging
```ts
// ISSUE: <describe what was wrong with the previous code>
// FIX APPLIED: <describe how the new code resolves the issue>
```

### For new code / new features
```ts
// TASK: <describe what this code is supposed to do>
// HOW CODE SOLVES: <explain how/why this implementation achieves the task>
```

**Rules for comments:**
- Be specific — reference variable names, function names, or behavior
- Place the comment block directly above the function, block, or line it describes
- Do not add vague comments like `// updated` or `// fixed`
- Every changed or newly written function must have its own comment block

**Example — Bug Fix:**
```ts
// ISSUE: Token was stored as plain text in the database, exposing credentials if DB is breached
// FIX APPLIED: Token is now encrypted with AES-256-GCM before saving; decrypted only when needed
function encryptToken(token: string): string { ... }
```

**Example — New Feature:**
```ts
// TASK: Build course context string to inject into AI prompts as background knowledge
// HOW CODE SOLVES: Fetches all modules and files for the course, extracts plain text from each,
//                  and concatenates them up to 80,000 chars to stay within LLM context limits
async function buildCourseContext(courseId: string, userId: string): Promise<string> { ... }
```

---

## Privacy & Security Rules

These rules apply to every line of code written in this project. Read `SECURITY.md` for the full secrets inventory.

### Never do these things
- Never hardcode a secret, key, token, or password in source code — always use `process.env.VAR_NAME`
- Never log secrets, tokens, or sensitive user data (`console.log(token)` is a security bug)
- Never read, print, or suggest staging `.env` files — they are gitignored for a reason
- Never expose backend secrets (API keys, JWT_SECRET, ENCRYPTION_KEY) to the React frontend
- Never write code examples with real-looking API keys — always use `process.env.KEY_NAME` or `YOUR_KEY_HERE`
- Never store Canvas OAuth tokens in plain text — they must be AES-256-GCM encrypted before DB insert

### Always do these things
- Access all config via `process.env` on the backend, `import.meta.env` on the frontend
- Validate and sanitize all user input before using it in DB queries or API calls
- Use parameterized queries (never string-interpolated SQL)
- Return generic error messages to the client — never leak stack traces or internal details in production
- If you spot a hardcoded secret in existing code, flag it as a `CRITICAL` issue before proceeding

---

## Debugging Best Practices

When fixing a bug, follow this process — do not skip steps:

### Step 1 — Read the full error before touching code
- Read the complete error message and stack trace
- Identify the exact file, line number, and function where it originates
- State out loud (in a comment or response) what the **expected** behavior was vs what **actually** happened

### Step 2 — Isolate before fixing
- Do not change multiple things at once — change one thing, verify it, then move on
- Check logs first: browser console, terminal output, network tab
- If the bug is in a route, test it with Bruno before changing code

### Step 3 — Write the fix with a comment block
Every bug fix **must** have this comment directly above the changed code:
```ts
// ISSUE: <what was wrong — be specific about variable names and behavior>
// FIX APPLIED: <how the new code resolves it — reference the change made>
```

### Step 4 — Verify the fix
- Re-run the failing request in Bruno (or refresh the page) and confirm it now works
- Check that the fix did not break anything adjacent (e.g., if you changed auth middleware, test a protected route)
- If you wrote a test for this route before, re-run it

### Step 5 — Document it
- Add an entry to `docs/DEVLOG.md` describing the bug, root cause, and fix
- If this bug reveals a pattern (e.g., "we were not handling null from the DB"), note it in DEVLOG so we don't repeat it

### Common Bug Categories in This Project
| Category | What to Check First |
|---|---|
| Auth / 401 errors | JWT secret mismatch, token expired, missing `Authorization` header |
| Canvas API errors | Token expired or not decrypted correctly, wrong `CANVAS_BASE_URL` |
| AI provider errors | Missing or wrong env var, rate limit hit, malformed prompt |
| DB errors | Missing migration, wrong column name, NULL constraint violation |
| CORS errors | `FRONTEND_URL` env var not set correctly in backend |
| Redis errors | Docker not running, wrong `REDIS_URL`, key TTL expired unexpectedly |

---

## AI Provider Notes

| Provider | Free | Env Var |
|---|---|---|
| Groq | Yes | `GROQ_API_KEY` |
| Google Gemini | Yes | `GEMINI_API_KEY` |
| Anthropic | No | `ANTHROPIC_API_KEY` |
| OpenAI | No | `OPENAI_API_KEY` |
| Ollama | Local | `OLLAMA_BASE_URL` |

Default/fallback provider is **Groq** (free tier, fastest for dev).
