# Canvas AI Platform — Build Roadmap

> **React • Node.js • Canvas API / LTI • LLM-Agnostic AI**
>
> A web application that sits on top of Canvas LMS and gives students an AI-powered learning assistant with full course context automatically injected.

---

## Overview

| | |
|---|---|
| **Total Timeline** | 16 Weeks |
| **Phases** | 4 phases × 4 weeks each |
| **AI** | LLM-agnostic — swap any provider |
| **Stack** | React + TypeScript, Node.js + Express, PostgreSQL + Redis, Canvas REST API + LTI 1.3 |
| **Hosting** | Railway or Render |

---

## How to Use This Roadmap

Each phase lists tasks, the owner, and an exact prompt template to give Claude. Follow these rules:

**Golden Rules for Prompting**
- Always paste your current file before asking Claude to edit it — Claude has no memory between sessions
- Be specific: include file names, line numbers, and the exact behavior you want
- Ask for one feature at a time — do not bundle unrelated changes in one prompt
- After each response, ask Claude to review its own output for bugs before you run it
- Keep a `/docs` folder in your project and ask Claude to update it as you build

**Session Structure (per feature)**
1. Open a fresh Claude chat
2. Paste relevant existing code
3. State the task clearly
4. Copy the output, test it
5. Come back with errors if any
6. Ask Claude to write a test for it

---

## Phase 1 — Foundation & Canvas Auth *(Weeks 1–4)*

**Goal:** Get the app running locally, connect to Canvas via OAuth2, pull course data, and show it in a basic React UI. By the end of Phase 1 you should be able to log in with Canvas and see your courses.

### Week 1 — Project Scaffolding

| Task | Owner | Prompt |
|---|---|---|
| Init React app | Claude + Terminal | *"Create a React TypeScript app using Vite with Tailwind CSS and shadcn/ui configured. Show me the full setup commands and base file structure."* |
| Init Node backend | Claude + Terminal | *"Create a Node.js Express backend with TypeScript, dotenv, cors, helmet, and a basic health-check route GET /api/health. Show folder structure."* |
| Docker Compose | Claude | *"Write a docker-compose.yml that runs: postgres 15, redis 7, the backend on port 4000, and the frontend on port 3000 with hot reload."* |
| ESLint + Prettier | Claude | *"Add ESLint and Prettier to both frontend and backend with a shared config. Show .eslintrc and .prettierrc."* |
| Environment config | Claude | *"Create .env.example files for both frontend and backend listing every env var we will need for Canvas OAuth, JWT, Postgres, and Redis."* |

### Week 2 — Canvas OAuth2 Login

| Task | Owner | Prompt |
|---|---|---|
| Canvas OAuth setup | Claude | *"Write a Canvas OAuth2 flow in Express. Steps: redirect to Canvas /login/oauth2/auth, handle callback at /auth/canvas/callback, exchange code for token, store encrypted token in Postgres, return JWT to frontend."* |
| Token encryption | Claude | *"Show me how to encrypt/decrypt Canvas tokens at rest using AES-256-GCM in Node.js before saving to the database."* |
| Auth middleware | Claude | *"Write Express middleware that validates our JWT, attaches user to req.user, and returns 401 if invalid."* |
| Login page | Claude | *"Create a React LoginPage component with a 'Log in with Canvas' button that redirects to our backend /auth/canvas route. Use Tailwind for styling."* |
| Canvas dev account | You | Sign up at canvas.instructure.com (free), create a Developer Key under Admin > Developer Keys to get client_id and client_secret. |

### Week 3 — Canvas API Service

| Task | Owner | Prompt |
|---|---|---|
| Canvas API wrapper | Claude | *"Write a CanvasService class in Node.js that wraps the Canvas REST API. Methods: getCourses(), getCourseModules(courseId), getModuleItems(courseId, moduleId), getFiles(courseId), getAssignments(courseId). Use axios, handle pagination."* |
| Content parser | Claude | *"Write a parser service that takes a Canvas file URL, downloads it, and extracts plain text. Support: PDF (use pdf-parse), DOCX (use mammoth), PPTX, plain HTML."* |
| Context builder | Claude | *"Write a buildCourseContext(courseId, userId) function that fetches all modules + files for a course and concatenates their text into a single context string, truncated to 80,000 chars."* |
| Caching layer | Claude | *"Add Redis caching to CanvasService. Cache each course's context for 30 minutes with key canvas:course:{courseId}:context. Show invalidation strategy."* |
| Canvas API routes | Claude | *"Create Express routes: GET /api/courses, GET /api/courses/:id/context. Both protected by auth middleware."* |

### Week 4 — Dashboard UI

| Task | Owner | Prompt |
|---|---|---|
| Course list page | Claude | *"Create a React CoursesPage that calls GET /api/courses and displays course cards with name, course code, and an 'Open' button. Use Tailwind grid layout."* |
| Course detail page | Claude | *"Create a CoursePage that shows the modules and files for a course. Sidebar navigation on the left, content area on the right. Fetch from /api/courses/:id."* |
| React Query setup | Claude | *"Set up React Query (TanStack Query) in our frontend. Create useCanvasCourses() and useCanvasCourse(id) hooks that call our backend API."* |
| Auth state + routing | Claude | *"Set up React Router v6 with protected routes. If no JWT in localStorage, redirect to /login. Show me App.tsx and router config."* |
| Phase 1 integration test | Claude + You | *"Review this code and write an integration test using Jest + supertest that: 1) mocks Canvas OAuth, 2) creates a user, 3) calls GET /api/courses, 4) asserts 200 response."* |

---

## Phase 2 — Core AI Features *(Weeks 5–8)*

**Goal:** Add the AI layer. Students can chat with their course, generate quizzes, summaries, notes, and learning paths. The LLM is pluggable — any provider can be swapped in.

### Week 5 — LLM-Agnostic AI Adapter

| Task | Owner | Prompt |
|---|---|---|
| AI adapter interface | Claude | *"Design a TypeScript interface AIAdapter with method: generate(params: {provider, systemPrompt, userMessage, stream}): Promise\<string\>. Then implement OpenAIAdapter, AnthropicAdapter, and GroqAdapter (free tier). Each reads its API key from env."* |
| Provider factory | Claude | *"Write an AIAdapterFactory.create(provider: string) function that returns the correct adapter. Fall back to Groq if no key found for requested provider."* |
| Context injection | Claude | *"Write injectCourseContext(adapter, courseContext, userMessage) that prepends the course context as a system message before calling adapter.generate(). Enforce a 100k token limit."* |
| Streaming support | Claude | *"Add server-sent events (SSE) streaming to our /api/ai/chat endpoint so the frontend receives tokens in real time as the LLM generates them."* |
| AI config endpoint | Claude | *"Create GET/POST /api/user/ai-config endpoints so users can set their preferred provider and (optionally) their own API key. Store keys encrypted."* |

### Week 6 — Chat Interface

| Task | Owner | Prompt |
|---|---|---|
| Chat UI component | Claude | *"Build a React ChatPanel component: message history display (user bubbles right, AI bubbles left), text input with send button, streaming token rendering using EventSource. Use Tailwind."* |
| Chat session backend | Claude | *"Create POST /api/chat endpoint: takes {courseId, message}, loads course context, injects it, calls AI adapter, saves message to chat_sessions table, streams response back."* |
| Chat history | Claude | *"Add GET /api/chat/history?courseId=X to load the last 20 messages for a course session. Persist in Postgres. Show DB migration."* |
| Model selector | Claude | *"Add a small dropdown in the chat UI to switch between Groq (free), OpenAI, Claude, Gemini. Update user's preference via POST /api/user/ai-config."* |
| Error handling | Claude | *"Add graceful error handling to the chat: if the AI call fails or rate-limits, show a friendly retry message. Add exponential backoff to the adapter."* |

### Week 7 — Quiz Generator

| Task | Owner | Prompt |
|---|---|---|
| Quiz prompt engineering | Claude | *"Write a generateQuizPrompt(courseContext, options) function. Options: numQuestions (5-20), difficulty (easy/medium/hard), type (MCQ/short-answer/mixed). Return ONLY valid JSON: { questions: [{id, question, options?, answer, explanation}] }."* |
| Quiz generation endpoint | Claude | *"Create POST /api/quiz/generate: takes {courseId, options}, calls AI adapter with quiz prompt, parses JSON response, saves to quizzes table with status=draft."* |
| Quiz UI | Claude | *"Build a QuizPage React component: configuration form (# questions, difficulty, type), generate button with loading state, then display questions one at a time with answer selection, submit, and show score + explanations."* |
| Quiz results | Claude | *"Create POST /api/quiz/:id/submit that takes student answers, calculates score, saves to quiz_attempts table, returns score + per-question feedback."* |
| Retry / regenerate | Claude | *"Add a Regenerate Quiz button that calls the endpoint again with the same config. Add a useQuizGeneration() React hook that manages loading/error/data state."* |

### Week 8 — Summaries, Notes & Learning Paths

| Task | Owner | Prompt |
|---|---|---|
| Smart summarizer | Claude | *"Write a summarize(courseContext, scope) function where scope is 'full-course', 'module', or 'topic:X'. Return a structured summary with: overview, key concepts, important terms. Return as JSON."* |
| Detailed notes generator | Claude | *"Write a generateNotes(courseContext, style) function. Styles: 'cornell', 'outline', 'bullet'. Returns markdown-formatted notes. Save to Postgres and allow editing."* |
| Learning path generator | Claude | *"Write a generateLearningPath(courseContext, goal, currentKnowledge) function. Returns a JSON week-by-week study plan with topics, resources, and milestones."* |
| Tools page UI | Claude | *"Create a ToolsPage in React with tabs: Summary, Notes, Learning Path. Each tab has a config panel, generate button, and displays results in a nicely formatted card."* |
| Export to PDF | Claude | *"Add an Export to PDF button on the Notes and Summary views using the browser print API or jsPDF. Generate a clean print-friendly layout."* |

---

## Phase 3 — Instructor Tools & Assignments *(Weeks 9–12)*

**Goal:** Build the instructor side of the app. Instructors can generate quizzes and push them back to Canvas as assignments. Students and instructors can add supplemental content.

### Week 9 — Instructor Dashboard

| Task | Owner | Prompt |
|---|---|---|
| Role-based access | Claude | *"Update our auth system to detect Canvas role (student vs instructor) from the OAuth token. Add role to JWT claims. Add requireRole('instructor') middleware."* |
| Instructor layout | Claude | *"Create an InstructorLayout React component with a sidebar: My Courses, Quiz Manager, Content, Analytics. Protected by instructor role check."* |
| Course roster view | Claude | *"Create a RosterPage that calls GET /api/instructor/courses/:id/students (use Canvas API to fetch enrollment list) and displays students in a table with name and email."* |
| Quiz manager | Claude | *"Build a QuizManagerPage for instructors: list all quizzes for a course, show status (draft/assigned), preview questions, edit, delete, assign buttons."* |
| Canvas quiz push | Claude | *"Write a pushQuizToCanvas(quizData, courseId, canvasToken) function that creates a Canvas Quiz via POST /api/v1/courses/:id/quizzes and adds each question via the Canvas Quiz Questions API."* |

### Week 10 — Content Management

| Task | Owner | Prompt |
|---|---|---|
| Supplemental content | Claude | *"Create a ContentPage for instructors to add supplemental notes or links. POST /api/instructor/courses/:id/content saves to a course_supplements table. This content is injected into the AI context alongside Canvas data."* |
| Student content uploads | Claude | *"Allow students to upload their own notes (PDF, text) for a course. POST /api/student/content/upload. Parse and add to their personal context. Store in S3 or local /uploads."* |
| Content flagging | Claude | *"Add a flag button on AI responses. POST /api/chat/:messageId/flag saves a report. Instructors see flagged responses in their dashboard and can mark them resolved."* |
| Instructor annotations | Claude | *"Allow instructors to add inline corrections to AI-generated quiz questions. PATCH /api/quiz/:id/question/:qid updates the question text. Versioned in DB."* |
| Context priority system | Claude | *"Update buildCourseContext() to weight content: instructor supplements (highest), Canvas official content (medium), student uploads (context only)."* |

### Week 11 — Analytics

| Task | Owner | Prompt |
|---|---|---|
| Student analytics | Claude | *"Create a StudentAnalyticsPage showing: quiz scores over time (line chart), topics attempted, weak areas (lowest scoring topics). Use recharts for charts."* |
| Instructor analytics | Claude | *"Create an InstructorAnalyticsPage showing: class average per quiz, distribution of scores (histogram), most-generated topics, most flagged AI answers."* |
| Analytics backend | Claude | *"Write GET /api/analytics/student/:id and GET /api/analytics/course/:id endpoints that query quiz_attempts and chat_sessions and return aggregated stats."* |
| Weak area detection | Claude | *"Write a detectWeakAreas(studentId, courseId) function that analyzes quiz_attempts and returns a list of topics where the student scored below 70%."* |
| Progress widget | Claude | *"Add a progress sidebar widget to the student dashboard showing: course completion %, last quiz score, study streak (days in a row). Fetch from /api/student/progress."* |

### Week 12 — Polish & Testing

| Task | Owner | Prompt |
|---|---|---|
| End-to-end tests | Claude | *"Write Playwright e2e tests for: student login flow, generating a quiz, submitting answers. Show playwright.config.ts and the test files."* |
| API rate limiting | Claude | *"Add rate limiting to all /api/ai/* endpoints using express-rate-limit. Limits: 20 AI requests/min per user. Return 429 with retry-after header."* |
| Error boundaries | Claude | *"Add React error boundaries around every major page component. Show a friendly error card with a Retry button. Log errors to console."* |
| Loading skeletons | Claude | *"Replace all loading spinners with skeleton loaders (animated gray boxes). Use a SkeletonCard component for the course list and quiz list."* |
| Mobile responsive | Claude | *"Audit every page for mobile responsiveness. Fix layout issues for screens < 768px. Sidebar should collapse to a hamburger menu on mobile."* |

---

## Phase 4 — LTI Embed, Multi-LLM & Production *(Weeks 13–16)*

**Goal:** Embed the app inside Canvas via LTI 1.3, add advanced AI features, and deploy to production.

### Week 13 — LTI 1.3 Integration

| Task | Owner | Prompt |
|---|---|---|
| LTI library setup | Claude | *"Install ltijs npm package. Write an lti.service.ts that configures the LTI provider with our platform URL, client_id, and deployment_id. Show the full setup."* |
| LTI launch handler | Claude | *"Write the LTI launch handler: when Canvas launches our tool via LTI, extract the user's Canvas ID, course ID, and role from the id_token JWT. Create or update the user in our DB. Return a redirect to the correct app page."* |
| LTI deep linking | Claude | *"Implement LTI Deep Linking so instructors can insert our Quiz Generator tool directly into a Canvas module. Show the deep link response message."* |
| Grade passback | Claude | *"Implement LTI AGS (Assignment and Grade Services) to post quiz scores back to Canvas gradebook. Write a submitGrade(score, userId, lineItemUrl) function."* |
| Iframe UI adjustments | Claude | *"When running inside Canvas LTI iframe, hide our top navigation bar. Detect iframe mode via a query param ?lti=1 and conditionally render a minimal layout."* |

### Week 14 — Advanced AI Features

| Task | Owner | Prompt |
|---|---|---|
| Flashcard mode | Claude | *"Add a Flashcards feature. POST /api/flashcards/generate uses AI to create term/definition pairs from course content. React FlashcardPage flips cards on click. Track which cards the user has mastered."* |
| Spaced repetition | Claude | *"Implement a simple spaced repetition scheduler: cards due today are shown first, mastered cards resurface in 7 days. Store next_review_date per card in Postgres."* |
| Collaborative notes | Claude | *"Allow instructor and students to co-edit course notes using a simple versioned approach (not real-time). Show latest version, allow students to suggest edits, instructor approves."* |
| AI tutor mode | Claude | *"Add a 'Tutor Mode' to chat: the AI asks the student questions about the course instead of just answering. The system prompt changes to Socratic mode. Add a toggle button in ChatPanel."* |
| Citation mode | Claude | *"Update the AI system prompt to always cite which Canvas module or file the answer came from. Parse these citations in the frontend and render them as clickable links back to Canvas."* |

### Week 15 — Security & Performance

| Task | Owner | Prompt |
|---|---|---|
| Security audit | Claude | *"Review this backend codebase for security issues. Check for: SQL injection (use parameterized queries), XSS (sanitize inputs), CSRF (add csrf tokens), insecure direct object refs."* |
| Database indexing | Claude | *"Add database indexes to our Postgres schema. Which columns should be indexed? Write the migration SQL."* |
| API response caching | Claude | *"Add Redis caching to expensive endpoints: GET /api/courses (cache 5min), GET /api/courses/:id/context (cache 30min). Show the cache middleware."* |
| Canvas webhook | Claude | *"Set up a Canvas webhook listener for course_updated events. When fired, invalidate the Redis cache for that course's context. Show the webhook route and signature verification."* |
| Bundle optimization | Claude | *"Run a Vite bundle analysis on our frontend. What are the biggest dependencies? Show me how to code-split the quiz and notes pages using React.lazy()."* |

### Week 16 — Deployment & Launch

| Task | Owner | Prompt |
|---|---|---|
| Dockerfile | Claude | *"Write production Dockerfiles for the frontend (nginx) and backend (node). Multi-stage builds, no dev dependencies in production image."* |
| Railway deployment | Claude | *"Write a step-by-step deployment guide for Railway.app: create Postgres + Redis add-ons, set environment variables, connect GitHub repo for auto-deploy."* |
| DB migrations CI | Claude | *"Set up node-pg-migrate for database migrations. Write a GitHub Actions workflow that runs migrations on every deploy before the app starts."* |
| Monitoring | Claude | *"Add basic monitoring: log all API errors to a logs table in Postgres. Add GET /api/admin/logs endpoint. Use morgan for HTTP request logging to stdout."* |
| Canvas App Center | Claude + You | Prepare the LTI configuration XML and privacy policy needed to submit to Canvas's app directory. |

---

## Quick Reference

### Key API Endpoints (End State)

| Route | Method | Description |
|---|---|---|
| `/auth/canvas` | GET | Redirect to Canvas OAuth login |
| `/auth/canvas/callback` | GET | OAuth callback, returns JWT |
| `/api/courses` | GET | List current user courses |
| `/api/courses/:id/context` | GET | Full course text context |
| `/api/chat` | POST | Send message, returns SSE stream |
| `/api/quiz/generate` | POST | Generate quiz from course content |
| `/api/quiz/:id/submit` | POST | Submit answers, returns score |
| `/api/tools/summary` | POST | Generate course summary |
| `/api/tools/notes` | POST | Generate structured notes |
| `/api/tools/learning-path` | POST | Generate learning path |
| `/api/user/ai-config` | GET/POST | Get/set user LLM preferences |
| `/api/analytics/student/:id` | GET | Student performance stats |
| `/api/analytics/course/:id` | GET | Instructor course analytics |

### Supported AI Providers

| Provider | Free | Best For | Env Var |
|---|---|---|---|
| Groq | Yes — very generous | Dev & testing (fast) | `GROQ_API_KEY` |
| Google Gemini | Yes — Flash model | Production free tier | `GEMINI_API_KEY` |
| Anthropic Claude | No (paid) | Best reasoning | `ANTHROPIC_API_KEY` |
| OpenAI | No (pay per token) | GPT-4o option | `OPENAI_API_KEY` |
| Ollama (local) | Free (self-hosted) | Privacy / offline | `OLLAMA_BASE_URL` |

### Canvas API Credentials Setup

1. Go to your Canvas instance (e.g. `canvas.instructure.com`)
2. Admin > Developer Keys > + Developer Key > API Key
3. Set redirect URI to: `http://localhost:4000/auth/canvas/callback`
4. Copy the `client_id` and `client_secret` to your `.env`
5. For LTI (Phase 4): Create a separate LTI key under Developer Keys > + LTI Key

> Free Canvas sandbox: sign up at canvas.instructure.com (free teacher account)

---

### Reusable Prompt Templates

**New Feature**
```
I am building a Canvas LMS + AI learning platform.
Tech stack: React + TypeScript frontend, Node.js + Express backend, PostgreSQL, Redis.
Current task: [DESCRIBE TASK IN ONE SENTENCE].

Here is the relevant existing code:
[PASTE FILE CONTENTS]

Please: [SPECIFIC INSTRUCTIONS]. Return complete file(s), no placeholders.
```

**Debugging an Error**
```
I am getting this error in my Canvas AI app:
[PASTE FULL ERROR + STACK TRACE]

This is the relevant code:
[PASTE FILE]

What is causing this? Fix the code and explain what was wrong.
```

**Code Review**
```
Please review this code for: bugs, security issues, performance problems, and code style.
Context: this is part of a student-facing learning app with Canvas integration.
[PASTE CODE]
List issues by severity (critical, medium, low) and show fixed versions.
```

**Writing Tests**
```
Write Jest + supertest tests for this Express route:
[PASTE ROUTE CODE]
Cover: happy path, missing auth (401), invalid input (400), Canvas API failure (502).
Mock the Canvas API calls and database queries. Show the full test file.
```

---

*Start with Phase 1, Week 1. Run every Claude output before moving on. The most important rule: build incrementally and test often.*
