# Canvas AI — Security Reference

This file documents every secret this project uses, where it lives, and what the rules are.
Read this before onboarding a collaborator or starting a new AI coding session.

---

## Secrets Inventory

| Secret | Where It Lives | Used For | How It's Protected |
|---|---|---|---|
| `CANVAS_CLIENT_ID` | `backend/.env` | Canvas OAuth2 identity | Env var only, never in code |
| `CANVAS_CLIENT_SECRET` | `backend/.env` | Canvas OAuth2 secret | Env var only, never in code |
| `JWT_SECRET` | `backend/.env` | Signing user JWTs | Env var only, min 32 chars |
| `ENCRYPTION_KEY` | `backend/.env` | AES-256-GCM for Canvas tokens | Env var only, exactly 32-char hex |
| `DATABASE_URL` | `backend/.env` | Postgres connection string | Env var only |
| `REDIS_URL` | `backend/.env` | Redis connection string | Env var only |
| `GROQ_API_KEY` | `backend/.env` | Groq AI requests | Env var only |
| `GEMINI_API_KEY` | `backend/.env` | Google Gemini AI requests | Env var only |
| `OPENAI_API_KEY` | `backend/.env` | OpenAI requests | Env var only |
| `ANTHROPIC_API_KEY` | `backend/.env` | Anthropic Claude requests | Env var only |
| Canvas OAuth tokens | PostgreSQL `users` table | Making Canvas API calls | AES-256-GCM encrypted before insert |

---

## Hard Rules — No Exceptions

1. **Never commit `.env` files.** `.gitignore` blocks them. `.env.example` files (no real values) are safe to commit.
2. **Never hardcode a secret in source code.** Always use `process.env.VAR_NAME`.
3. **Never log a secret.** No `console.log(token)`, no logging request headers that contain `Authorization`.
4. **Never expose secrets to the frontend.** The React app must never receive API keys, JWT secrets, or Canvas tokens — only the JWT issued to the user.
5. **Canvas OAuth tokens must be encrypted** with AES-256-GCM before writing to the database. They are decrypted only in memory, only when needed.
6. **User-uploaded files may contain PII.** The `backend/uploads/` folder is gitignored. Do not log file contents.

---

## What to Do If a Secret Is Accidentally Committed

1. **Revoke the secret immediately** — do not wait. Rotate the key in the provider's dashboard.
2. Remove the secret from the commit history using `git filter-repo` or BFG Repo Cleaner.
3. Force-push the cleaned history (coordinate with any collaborators first).
4. Generate a new secret and update `.env`.

### Rotate Secrets Here
| Secret | Where to Rotate |
|---|---|
| Canvas OAuth | Canvas Admin > Developer Keys > Edit |
| Groq API key | console.groq.com |
| Gemini API key | aistudio.google.com |
| OpenAI API key | platform.openai.com |
| Anthropic API key | console.anthropic.com |
| JWT_SECRET | Generate a new one: `openssl rand -hex 32` |
| ENCRYPTION_KEY | Generate a new one: `openssl rand -hex 32` |

---

## Generating Safe Secrets Locally

```bash
# JWT_SECRET or ENCRYPTION_KEY (32-byte hex = 64 hex chars)
openssl rand -hex 32
```

---

## AI Assistants — Security Rules

When any AI (Claude, Codex, ChatGPT, Gemini) works on this project it must follow these rules:

- Never read, print, or suggest logging the contents of any `.env` file
- Never write code that embeds a secret as a string literal
- When writing code examples that reference keys, always use `process.env.KEY_NAME` or the placeholder `YOUR_KEY_HERE`
- Never suggest `git add .env` or any command that would stage secret files
- If you notice a secret hardcoded in existing code, flag it as a security issue before doing anything else

---

## Files That Are Safe to Commit

| File | Why It's Safe |
|---|---|
| `backend/.env.example` | Contains variable names only, no real values |
| `frontend/.env.example` | Same — variable names only |
| `SECURITY.md` | This file — describes secrets but contains none |
| `docker-compose.yml` | Dev credentials only (`canvasai_dev`) — never used in production |
