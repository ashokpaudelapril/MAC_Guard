# Canvas AI Learning Platform

An AI-powered learning assistant that sits on top of Canvas LMS. Students get quizzes, summaries, notes, flashcards, and an AI chat — all powered by their course content.

## Quick Start

### Prerequisites
- Node.js 18+
- Docker Desktop
- A Canvas account (free sandbox at canvas.instructure.com)

---

### 1. Start the database

```bash
docker-compose up -d
```

This starts PostgreSQL on port 5432 and Redis on 6379.

---

### 2. Set up the backend

```bash
cd backend
cp .env.example .env
# Edit .env — add your Canvas client_id, client_secret, and at least one AI key
npm install
```

Run the database schema:
```bash
# Connect to Postgres and run the schema
psql postgresql://canvasai:canvasai_dev@localhost:5432/canvasai -f src/models/schema.sql
```

Start the backend:
```bash
npm run dev
# Runs on http://localhost:4000
```

---

### 3. Set up the frontend

```bash
cd frontend
npm install
npm run dev
# Runs on http://localhost:3000
```

---

### 4. Get Canvas credentials

1. Go to your Canvas instance (e.g. https://canvas.instructure.com)
2. Admin > Developer Keys > + Developer Key > API Key
3. Set redirect URI: `http://localhost:4000/auth/canvas/callback`
4. Copy client_id and client_secret into `backend/.env`

---

### 5. Get a free AI API key

Pick any one to start — Groq is fastest to set up:

- **Groq** (free): https://console.groq.com → Create API Key → add as `GROQ_API_KEY`
- **Gemini** (free): https://aistudio.google.com → Get API Key → add as `GEMINI_API_KEY`
- **Ollama** (local, free): Install from https://ollama.ai, run `ollama pull llama3.2`

---

## Project Structure

```
canvas-ai/
├── docker-compose.yml       # Postgres + Redis
├── frontend/                # React + TypeScript + Tailwind
│   └── src/
│       ├── pages/           # LoginPage, Dashboard, Chat, Quiz, Tools, Settings
│       ├── components/      # Layout, UI components
│       ├── hooks/           # useAuth
│       └── lib/             # api.ts (axios client)
└── backend/                 # Node.js + Express + TypeScript
    └── src/
        ├── routes/          # auth, courses, chat, quiz, tools, user
        ├── services/        # canvas.service, ai.service
        ├── middleware/      # auth, errorHandler
        └── models/          # db.ts, schema.sql
```

## Supported AI Providers

| Provider | Free | Setup |
|---|---|---|
| Groq | ✅ Yes | groq.com → API key |
| Google Gemini | ✅ Yes | aistudio.google.com |
| OpenRouter | ✅ Many free models | openrouter.ai |
| Ollama | ✅ Local | ollama.ai |
| OpenAI | ❌ Paid | platform.openai.com |
| Anthropic | ❌ Paid | console.anthropic.com |

## Docs

| File | Description |
|---|---|
| [ROADMAP.md](./ROADMAP.md) | Full 16-week build plan with exact prompt templates per task |
| [docs/DEVLOG.md](./docs/DEVLOG.md) | Running log of every change made to the project |

## Next Steps (Phase 2+)

See [ROADMAP.md](./ROADMAP.md) for the complete 16-week build plan with exact Claude Pro prompts.

Key upcoming features:
- Instructor dashboard + quiz assignment to Canvas
- LTI 1.3 embed (app lives inside Canvas)
- Analytics + progress tracking
- Grade passback to Canvas gradebook
