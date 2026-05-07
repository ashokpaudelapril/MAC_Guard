# Canvas AI — Progress Tracker

> **AI assistants: Read the SESSION BRIEFING block first. It tells you exactly where we are
> and what to do next. Do not start any task until you have read it.**

---

## SESSION BRIEFING
> This block is updated at the end of every session. It is the single source of truth
> for what happens next. Update all four fields whenever a task is completed.

### Last Completed Task
- **Task:** `frontend/.env.example` created — Week 1 complete
- **Completed:** 2026-03-16
- **What was done:** Created `frontend/.env.example` with `VITE_API_URL` documented. This completes the environment config pair (backend already had `.env.example`). All Week 1 scaffolding tasks are now done.

### Next Task — Start Here
- **Task:** Week 2 — Canvas OAuth2 Login: set up Canvas OAuth redirect → callback → token → JWT flow
- **Phase / Week:** Phase 1 / Week 2 — Canvas OAuth2 Login
- **What to do:**
  1. Register a Canvas developer key (Canvas Admin > Developer Keys) to get `CANVAS_CLIENT_ID` + `CANVAS_CLIENT_SECRET`
  2. Build the OAuth flow in `backend/src/routes/auth.ts`: GET `/auth/canvas` (redirect to Canvas) + GET `/auth/canvas/callback` (exchange code for token, encrypt token, issue JWT)
  3. Add AES-256-GCM token encryption in `backend/src/services/` (new file: `crypto.service.ts`)
  4. Build auth middleware in `backend/src/middleware/auth.ts` (validate JWT, attach `req.user`)
  5. Build the Login page in `frontend/src/pages/LoginPage.tsx`
- **Files to create:** `backend/src/services/crypto.service.ts`, `backend/src/middleware/auth.ts` (may already exist as stub)
- **Files to reference:** `backend/src/routes/auth.ts` (existing stub), `backend/src/index.ts` (to see how routes are wired), `backend/.env.example` (for required env vars)
- **Blockers / Prerequisites:** You need a Canvas developer account and a Canvas instance URL to get real OAuth credentials. Dev/test can use a sandbox Canvas instance.
- **⚠️ Read first:** `docs/BUGS.md` — a full bug audit was completed (40 issues). BUG-01, 02, 03, 04 are directly in the Week 2 auth flow and must be addressed during this task. BUG-29 (env var startup validation) is a quick win to do first.

### After That
- **Task:** Week 2 continued — token encryption, auth middleware, Login page UI

---

## Phase 1 — Foundation & Canvas Auth *(Weeks 1–4)*

### Week 1 — Project Scaffolding
- [x] Init React app (Vite + TypeScript + Tailwind + shadcn/ui)
- [x] Init Node backend (Express + TypeScript + health-check route)
- [x] Docker Compose (Postgres 15 + Redis 7)
- [x] ESLint + Prettier (frontend + backend)
- [x] Environment config (.env.example for frontend — backend already has one)

### Week 2 — Canvas OAuth2 Login
- [ ] Canvas OAuth setup (redirect → callback → token → JWT)
- [ ] Token encryption (AES-256-GCM at rest)
- [ ] Auth middleware (JWT validation, req.user, 401)
- [ ] Login page (React + Tailwind)
- [ ] Canvas developer account + API keys

### Week 3 — Canvas API Service
- [ ] Canvas API wrapper (CanvasService class)
- [ ] Content parser (PDF, DOCX, PPTX, HTML → plain text)
- [ ] Context builder (buildCourseContext, 80k char limit)
- [ ] Redis caching layer (30 min TTL per course)
- [ ] Canvas API routes (GET /api/courses, /api/courses/:id/context)

### Week 4 — Dashboard UI
- [ ] Course list page (cards + grid layout)
- [ ] Course detail page (sidebar + content area)
- [ ] React Query setup (useCanvasCourses, useCanvasCourse hooks)
- [ ] Auth state + routing (React Router v6 + protected routes)
- [ ] Phase 1 integration test

---

## Phase 2 — Core AI Features *(Weeks 5–8)*

### Week 5 — LLM-Agnostic AI Adapter
- [ ] AI adapter interface (TypeScript interface + OpenAI/Anthropic/Groq adapters)
- [ ] Provider factory (AIAdapterFactory + Groq fallback)
- [ ] Context injection (injectCourseContext, 100k token limit)
- [ ] Streaming support (SSE on /api/ai/chat)
- [ ] AI config endpoint (GET/POST /api/user/ai-config)

### Week 6 — Chat Interface
- [ ] Chat UI component (bubbles, input, EventSource streaming)
- [ ] Chat session backend (POST /api/chat)
- [ ] Chat history (GET /api/chat/history, Postgres persistence)
- [ ] Model selector dropdown (Groq/OpenAI/Claude/Gemini)
- [ ] Error handling + exponential backoff

### Week 7 — Quiz Generator
- [ ] Quiz prompt engineering (generateQuizPrompt, JSON output)
- [ ] Quiz generation endpoint (POST /api/quiz/generate)
- [ ] Quiz UI (config form → questions → score + explanations)
- [ ] Quiz results (POST /api/quiz/:id/submit)
- [ ] Retry / regenerate + useQuizGeneration hook

### Week 8 — Summaries, Notes & Learning Paths
- [ ] Smart summarizer (scope: full-course / module / topic)
- [ ] Detailed notes generator (cornell / outline / bullet styles)
- [ ] Learning path generator (week-by-week JSON plan)
- [ ] Tools page UI (tabs: Summary, Notes, Learning Path)
- [ ] Export to PDF

---

## Phase 3 — Instructor Tools & Assignments *(Weeks 9–12)*

### Week 9 — Instructor Dashboard
- [ ] Role-based access (student vs instructor in JWT)
- [ ] Instructor layout (sidebar: Courses, Quiz Manager, Content, Analytics)
- [ ] Course roster view
- [ ] Quiz manager page (list, preview, edit, delete, assign)
- [ ] Canvas quiz push (pushQuizToCanvas)

### Week 10 — Content Management
- [ ] Supplemental content (instructor notes/links → course_supplements table)
- [ ] Student content uploads (PDF/text → personal context)
- [ ] Content flagging (flag AI responses, instructor review)
- [ ] Instructor annotations (edit quiz questions, versioned)
- [ ] Context priority system (instructor > Canvas > student)

### Week 11 — Analytics
- [ ] Student analytics page (quiz scores, topics, weak areas)
- [ ] Instructor analytics page (class averages, histograms, flagged answers)
- [ ] Analytics backend endpoints
- [ ] Weak area detection (< 70% score threshold)
- [ ] Progress sidebar widget (completion %, streak, last score)

### Week 12 — Polish & Testing
- [ ] End-to-end tests (Playwright: login, quiz, submit)
- [ ] API rate limiting (20 AI req/min per user)
- [ ] React error boundaries (all major pages)
- [ ] Loading skeleton components
- [ ] Mobile responsiveness audit (< 768px)

---

## Phase 4 — LTI Embed, Multi-LLM & Production *(Weeks 13–16)*

### Week 13 — LTI 1.3 Integration
- [ ] LTI library setup (ltijs)
- [ ] LTI launch handler (extract user/course/role from id_token)
- [ ] LTI deep linking (Quiz Generator in Canvas modules)
- [ ] Grade passback (LTI AGS → Canvas gradebook)
- [ ] Iframe UI adjustments (?lti=1 minimal layout)

### Week 14 — Advanced AI Features
- [ ] Flashcard mode (generate + flip UI + mastery tracking)
- [ ] Spaced repetition scheduler (next_review_date in Postgres)
- [ ] Collaborative notes (versioned, student suggest / instructor approve)
- [ ] AI tutor mode (Socratic system prompt toggle)
- [ ] Citation mode (cite Canvas module/file in every response)

### Week 15 — Security & Performance
- [ ] Security audit (SQL injection, XSS, CSRF, IDOR)
- [ ] Database indexing (migration SQL)
- [ ] API response caching (Redis middleware)
- [ ] Canvas webhook listener (cache invalidation on course_updated)
- [ ] Bundle optimization (React.lazy code splitting)

### Week 16 — Deployment & Launch
- [ ] Production Dockerfiles (frontend nginx + backend node, multi-stage)
- [ ] Railway deployment guide
- [ ] DB migrations CI (GitHub Actions)
- [ ] Monitoring (error logging to DB + morgan)
- [ ] Canvas App Center submission prep

---

## Notes & Decisions Log

> Add any architectural decisions, tradeoffs, or important notes here.

| Date | Note |
|---|---|
| 2026-03-16 | Project initialized. Phase 1 scaffolding exists but no features wired yet. |
