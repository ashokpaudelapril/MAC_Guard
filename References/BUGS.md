# Canvas AI — Bug & Issue Tracker

> Generated: 2026-03-16
> Source: Full codebase audit of backend/src/ and frontend/src/
> Status key: 🔴 Open · ✅ Fixed

---

## How to Use This File

Work through issues top-to-bottom by severity. For each fix, change the status emoji to ✅ and add the date fixed. When all items in a section are done, note it in `docs/DEVLOG.md`.

---

## CRITICAL — Fix Before Any Production Use

---

### BUG-01 · Canvas OAuth token stored in plaintext 🔴
**File:** `backend/src/routes/auth.ts` · **Line:** 63
**What's wrong:** The `access_token` from Canvas is inserted directly into the `canvas_token` DB column with no encryption. The schema comment says `-- encrypted` but no encryption is applied. A DB breach exposes every user's Canvas credentials.
**How to fix:**
1. Create `backend/src/services/crypto.service.ts` with AES-256-GCM encrypt/decrypt functions (this is already the Week 2 task).
2. Call `encrypt(access_token)` before the DB insert in `auth.ts:63`.
3. Call `decrypt(canvas_token)` wherever the token is read back (currently `courses.ts:14–15`).

---

### BUG-02 · User AI API keys stored in plaintext 🔴
**File:** `backend/src/routes/user.ts` · **Lines:** 24–27
**What's wrong:** User-supplied AI provider API keys are written to `ai_api_key` without encryption. The schema comment says `-- encrypted, user's own key` but no encryption is applied.
**How to fix:** Use the same `encrypt()`/`decrypt()` from `crypto.service.ts` (BUG-01) — encrypt on write in `user.ts`, decrypt on read before passing to `ai.service.ts`.

---

### BUG-03 · JWT sent as a URL query parameter 🔴
**File:** `backend/src/routes/auth.ts` · **Line:** 76
**What's wrong:** `res.redirect(\`${FRONTEND_URL}/auth/success?token=${jwtToken}\`)` puts the JWT in the URL. It appears in browser history, web server logs, CDN logs, and HTTP Referer headers sent to any third-party resource on the destination page.
**How to fix:** Set the JWT as an `httpOnly` cookie instead of a query param:
```ts
res.cookie('token', jwtToken, { httpOnly: true, sameSite: 'lax', secure: process.env.NODE_ENV === 'production' });
res.redirect(`${FRONTEND_URL}/auth/success`);
```
Then update the frontend to read the token from the cookie rather than the URL (also fixes BUG-32).

---

### BUG-04 · No CSRF state parameter in OAuth flow 🔴
**File:** `backend/src/routes/auth.ts` · **Lines:** 15–30
**What's wrong:** The `/auth/canvas` redirect generates no `state` parameter, and `/auth/canvas/callback` never validates one. An attacker can trick a victim into completing an OAuth login as the attacker's Canvas account.
**How to fix:**
1. On `/auth/canvas`: generate a random `state` value, store it in a short-lived session or signed cookie, and append `&state=<value>` to the Canvas authorization URL.
2. On `/auth/canvas/callback`: read `req.query.state`, compare to the stored value, and reject the request if they don't match.

---

## HIGH

---

### BUG-05 · Role assigned by email substring match 🔴
**File:** `backend/src/routes/auth.ts` · **Line:** 52
**What's wrong:** `profile.primary_email?.includes('instructor')` — anyone whose email contains the word "instructor" (e.g., `instructor_support@students.edu`) gets `instructor` role.
**How to fix:** Canvas provides a proper roles API. Use `GET /api/v1/courses/:id/enrollments?user_id=me` or the enrollments response from the OAuth token exchange to get the actual role. As a minimum interim fix, check the full Canvas `roles` array in the profile response instead of the email string.

---

### BUG-06 · No rate limiting on AI routes 🔴
**File:** `backend/src/index.ts` · **Line:** absent
**What's wrong:** `POST /api/chat`, `POST /api/quiz/generate`, and `POST /api/tools/*` all make outbound LLM API calls with no rate limiting. Any authenticated user can trigger unlimited AI calls against server-side API keys.
**How to fix:** Add `express-rate-limit` middleware scoped to AI routes:
```ts
import rateLimit from 'express-rate-limit';
const aiLimiter = rateLimit({ windowMs: 60_000, max: 20 }); // 20 req/min per IP
app.use('/api/chat', aiLimiter);
app.use('/api/quiz', aiLimiter);
app.use('/api/tools', aiLimiter);
```

---

### BUG-07 · AI provider sends `Bearer undefined` when env key is missing 🔴
**File:** `backend/src/services/ai.service.ts` · **Lines:** 32, 47, 62
**What's wrong:** `const key = params.apiKey || process.env.GROQ_API_KEY` — if neither is set, `key` is `undefined`. The Authorization header becomes `Bearer undefined` and hits the provider API, returning a confusing 401 with no internal warning.
**How to fix:** Add an explicit guard:
```ts
const key = params.apiKey || process.env.GROQ_API_KEY;
if (!key) throw new Error('No API key configured for provider: groq');
```

---

### BUG-08 · Null pointer crash — `GET /api/courses/:id` 🔴
**File:** `backend/src/routes/courses.ts` · **Lines:** 26–27
**What's wrong:** `userResult.rows[0].canvas_token` is accessed without checking `userResult.rows.length > 0`. If the user exists in the JWT but has been deleted from the DB, this throws an uncaught `TypeError`.
**How to fix:**
```ts
if (!userResult.rows[0]) return res.status(401).json({ error: 'User not found' });
```
Apply the same guard to `GET /:id/context` in the same file.

---

### BUG-09 · Null pointer crash — chat route 🔴
**File:** `backend/src/routes/chat.ts` · **Line:** 20
**What's wrong:** `const { ai_provider, ai_api_key } = userResult.rows[0]` — no null check before destructuring.
**How to fix:** Same pattern as BUG-08:
```ts
if (!userResult.rows[0]) return res.status(401).json({ error: 'User not found' });
```

---

### BUG-10 · Null pointer crash — quiz route 🔴
**File:** `backend/src/routes/quiz.ts` · **Line:** 15
**What's wrong:** Same pattern as BUG-09 — `userResult.rows[0]` accessed without null guard.
**How to fix:** Same fix as BUG-08.

---

### BUG-11 · Null pointer crash — tools route 🔴
**File:** `backend/src/routes/tools.ts` · **Line:** 11
**What's wrong:** Same pattern as BUG-09.
**How to fix:** Same fix as BUG-08.

---

### BUG-12 · courseId type mismatch between Canvas integer ID and DB UUID 🔴
**File:** `frontend/src/pages/ChatPage.tsx` · **Line:** 39 · `backend/src/routes/chat.ts` · **Line:** 39
**What's wrong:** The frontend passes the URL param `id` (a Canvas integer like `"12345"`) as `courseId`. The backend uses this value in a query against `chat_sessions.course_id`, which is a UUID foreign key referencing `courses.id`. PostgreSQL rejects the type or silently mismatches, so every chat session linked to a real course fails.
**How to fix:** The backend must look up the internal `courses.id` UUID from the `canvas_course_id` integer before using it in the `chat_sessions` query:
```ts
const courseRow = await query('SELECT id FROM courses WHERE canvas_course_id = $1', [canvasCourseId]);
const internalCourseId = courseRow.rows[0]?.id || null;
```
Then use `internalCourseId` in the chat session query.

---

### BUG-13 · No ownership check on quiz submit 🔴
**File:** `backend/src/routes/quiz.ts` · **Lines:** 82–83
**What's wrong:** `SELECT questions FROM quizzes WHERE id = $1` — any authenticated user can submit answers for any quiz by guessing/enumerating UUIDs.
**How to fix:** Add a `user_id` filter:
```ts
'SELECT questions FROM quizzes WHERE id = $1 AND user_id = $2', [req.params.id, req.user!.id]
```

---

### BUG-29 · No startup validation of required environment variables 🔴
**File:** `backend/src/index.ts` · **Line:** absent
**What's wrong:** The server starts successfully even if `JWT_SECRET`, `DATABASE_URL`, or Canvas OAuth env vars are missing. Individual routes silently fail or throw at runtime.
**How to fix:** Add a pre-flight check at the top of `index.ts`:
```ts
const REQUIRED_ENV = ['JWT_SECRET', 'DATABASE_URL', 'CANVAS_CLIENT_ID', 'CANVAS_CLIENT_SECRET', 'CANVAS_REDIRECT_URI', 'FRONTEND_URL'];
for (const key of REQUIRED_ENV) {
  if (!process.env[key]) { console.error(`FATAL: Missing env var ${key}`); process.exit(1); }
}
```

---

### BUG-31 · Gemini API key exposed in URL query string 🔴
**File:** `backend/src/services/ai.service.ts` · **Line:** 87
**What's wrong:** The API key is appended as `?key=<KEY>` in the URL. It appears in all server access logs, proxy logs, and the browser network panel.
**How to fix:** Pass it as an `x-goog-api-key` header instead:
```ts
headers: { 'x-goog-api-key': key, 'Content-Type': 'application/json' }
```
And remove the `?key=` from the URL.

---

### BUG-32 · JWT stored in `localStorage` (XSS risk) 🔴
**File:** `frontend/src/pages/AuthSuccess.tsx` · **Line:** 12 · `frontend/src/lib/api.ts` · **Line:** 7
**What's wrong:** `localStorage.setItem('token', token)` — any JavaScript running on the page (including XSS payloads or compromised third-party scripts) can read and exfiltrate the token.
**How to fix:** Switch to `httpOnly` cookies (see BUG-03). Remove the `localStorage` read/write from `AuthSuccess.tsx`, `api.ts`, and `useAuth.ts`, and instead rely on the cookie being sent automatically with every request.

---

### BUG-39 · Saving AI settings wipes existing API key 🔴
**File:** `frontend/src/pages/SettingsPage.tsx` · **Line:** 21 · `backend/src/routes/user.ts` · **Line:** 26
**What's wrong:** If a user changes only their AI provider and leaves the key input blank, `apiKey` is `undefined`. The backend receives `apiKey: undefined` → runs `SET ai_api_key = NULL`, deleting the previously saved key.
**How to fix:** On the backend in `user.ts`, only update `ai_api_key` if a new value is actually provided:
```ts
if (apiKey !== undefined) {
  await query('UPDATE users SET ai_provider = $1, ai_api_key = $2 WHERE id = $3', [provider, apiKey, req.user!.id]);
} else {
  await query('UPDATE users SET ai_provider = $1 WHERE id = $2', [provider, req.user!.id]);
}
```

---

## MEDIUM

---

### BUG-14 · Division by zero on empty questions array 🔴
**File:** `backend/src/routes/quiz.ts` · **Line:** 94
**What's wrong:** `(correct / questions.length) * 100` — if `questions` is empty, result is `NaN`, which is stored in the DB and returned to the client.
**How to fix:** Guard before the division:
```ts
if (!questions.length) return res.status(400).json({ error: 'Quiz has no questions' });
```

---

### BUG-15 · Unguarded `JSON.parse` on AI output — quiz 🔴
**File:** `backend/src/routes/quiz.ts` · **Line:** 63
**What's wrong:** LLMs frequently return non-JSON text (especially when context is too large or the model refuses). `JSON.parse` throws, and the raw AI output is exposed in `detail: err.message`.
**How to fix:** Wrap in try/catch with a user-friendly error:
```ts
let quizData;
try { quizData = JSON.parse(cleaned); }
catch { return res.status(422).json({ error: 'AI returned an invalid response. Please try again.' }); }
```

---

### BUG-16 · Unguarded `JSON.parse` on AI output — tools 🔴
**File:** `backend/src/routes/tools.ts` · **Lines:** 121, 153
**What's wrong:** Same issue as BUG-15 for the learning-path and flashcard routes.
**How to fix:** Same pattern as BUG-15.

---

### BUG-17 · Brittle AI response parsing — all providers 🔴
**File:** `backend/src/services/ai.service.ts` · **Lines:** 42, 57, 73, 91, 106, 121
**What's wrong:** Every provider reads deeply chained properties without null guards (e.g., `res.data.choices[0].message.content`, `res.data.candidates[0].content.parts[0].text`). Any rate-limit response, safety refusal, or quota error that changes the response shape causes an unhandled crash.
**How to fix:** Add a null-safe helper:
```ts
function extractContent(data: any, provider: string): string {
  try {
    if (provider === 'groq' || provider === 'openai') return data.choices[0].message.content;
    if (provider === 'anthropic') return data.content[0].text;
    if (provider === 'gemini') return data.candidates[0].content.parts[0].text;
    if (provider === 'ollama') return data.message.content;
  } catch {}
  throw new Error(`Unexpected response shape from provider: ${provider}`);
}
```

---

### BUG-19 · Internal `err.message` returned to clients 🔴
**Files:** `backend/src/routes/courses.ts` (lines 19, 35, 100), `chat.ts` (81, 95, 110), `quiz.ts` (74, 105), `tools.ts` (49, 80, 125, 158)
**What's wrong:** All catch blocks return `detail: err.message`. In production, DB error messages, column names, and internal paths can leak.
**How to fix:** Strip `detail` from production error responses:
```ts
const detail = process.env.NODE_ENV !== 'production' ? (err as Error).message : undefined;
res.status(500).json({ error: 'Something went wrong', detail });
```

---

### BUG-20 · Global error handler leaks `err.message` in production 🔴
**File:** `backend/src/middleware/errorHandler.ts` · **Line:** 7
**What's wrong:** `res.status(status).json({ error: message })` — `message` is `err.message` with no environment check.
**How to fix:**
```ts
const message = process.env.NODE_ENV === 'production' ? 'Internal Server Error' : err.message;
```

---

### BUG-23 · No validation on `provider` field in `POST /api/user/ai-config` 🔴
**File:** `backend/src/routes/user.ts` · **Lines:** 21–32
**What's wrong:** Any arbitrary string is accepted as `ai_provider` and written directly to the DB.
**How to fix:** Validate against an allowlist before the DB write:
```ts
const VALID_PROVIDERS = ['groq', 'gemini', 'openai', 'anthropic', 'ollama', 'openrouter'];
if (provider && !VALID_PROVIDERS.includes(provider)) {
  return res.status(400).json({ error: 'Invalid AI provider' });
}
```

---

### BUG-24 · Prompt injection via unvalidated quiz fields 🔴
**File:** `backend/src/routes/quiz.ts` · **Lines:** 11, 30–33
**What's wrong:** `topic`, `difficulty`, and `type` are inserted directly into the AI system prompt without any sanitization. A user can inject instructions to hijack the AI response.
**How to fix:**
- Validate `difficulty` against an allowlist: `['easy', 'medium', 'hard']`
- Validate `type` against an allowlist: `['multiple-choice', 'true-false', 'short-answer']`
- Sanitize `topic` by stripping special characters and capping length (e.g., 200 chars max).

---

### BUG-28 · `courseId` not validated as UUID before DB query 🔴
**File:** `backend/src/routes/quiz.ts` · **Lines:** 113–116
**What's wrong:** `courseId` from `req.query` is used directly in a DB query. If it's not a valid UUID, PostgreSQL throws a type error at runtime.
**How to fix:** Validate UUID format before use:
```ts
const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
if (courseId && !UUID_REGEX.test(courseId as string)) {
  return res.status(400).json({ error: 'Invalid courseId format' });
}
```

---

### BUG-30 · Non-null assertion `!` on critical env vars 🔴
**File:** `backend/src/routes/auth.ts` · **Lines:** 9–11 · `backend/src/middleware/auth.ts` · **Line:** 21
**What's wrong:** `process.env.CANVAS_CLIENT_ID!` suppresses TypeScript errors but doesn't prevent `undefined` from propagating silently at runtime.
**How to fix:** Replace `!` assertions with explicit runtime guards (this will be handled by BUG-29's startup validation block, which runs before routes load).

---

### BUG-33 · `clearHistory` has no error handling 🔴
**File:** `frontend/src/pages/ChatPage.tsx` · **Lines:** 49–52
**What's wrong:** If the delete API call fails, the UI still clears `messages`. The user thinks history is deleted when it is not.
**How to fix:**
```ts
const clearHistory = async () => {
  try {
    await api.delete(`/chat/history?courseId=${id}`);
    setMessages([]);
  } catch {
    alert('Failed to clear history. Please try again.');
  }
};
```

---

## LOW

---

### BUG-21 · OAuth error log may expose sensitive data 🔴
**File:** `backend/src/routes/auth.ts` · **Line:** 78
**What's wrong:** `console.error('Canvas OAuth error:', err?.response?.data)` — `response.data` can contain OAuth error details including codes that reveal system internals.
**How to fix:** Log only the error status and message, not the full response body: `console.error('Canvas OAuth error:', err?.response?.status, err?.message)`.

---

### BUG-22 · Dead code — duplicate `notFound` export 🔴
**File:** `backend/src/middleware/errorHandler.ts` · **Lines:** 10–12
**What's wrong:** `errorHandler.ts` exports a `notFound` function that is never imported — `notFound.ts` is used instead. Causes confusion about which file to edit.
**How to fix:** Remove the `notFound` export from `errorHandler.ts`.

---

### BUG-34 · Chat history load failure is silently swallowed 🔴
**File:** `frontend/src/pages/ChatPage.tsx` · **Line:** 24
**What's wrong:** `.catch(console.error)` — user sees an empty chat with no indication of a failure.
**How to fix:** Set an error state and display an inline error message to the user.

---

### BUG-35 · Silent auth failure in `useAuth` 🔴
**File:** `frontend/src/hooks/useAuth.ts` · **Lines:** 22–24
**What's wrong:** If `/auth/me` fails (network error), the token is silently removed and the user is logged out with no message.
**How to fix:** Distinguish between a 401 (intentional logout) and a network error (show a "Could not reach server" message).

---

### BUG-36 · `ProtectedRoute` passes expired/malformed tokens 🔴
**File:** `frontend/src/App.tsx` · **Lines:** 13–17
**What's wrong:** The guard only checks `localStorage.getItem('token') !== null` — an expired token passes, causing a flash of protected content before the first API call triggers a redirect.
**How to fix:** Use the `user` state from `useAuth` (which calls `/auth/me` to validate the token) as the guard condition, not just token presence.

---

### BUG-37 · `alert()` used for errors in QuizPage and ToolsPage 🔴
**File:** `frontend/src/pages/QuizPage.tsx` · **Lines:** 28, 38 · `frontend/src/pages/ToolsPage.tsx` · **Line:** 35
**What's wrong:** `alert()` blocks the JavaScript thread and is visually inconsistent with the rest of the UI.
**How to fix:** Replace with an inline error state rendered as a styled error banner.

---

### BUG-38 · Missing `useEffect` dependency — `AuthSuccess.tsx` 🔴
**File:** `frontend/src/pages/AuthSuccess.tsx` · **Line:** 17
**What's wrong:** `useEffect(() => { ... }, [])` uses `params` and `navigate` inside but doesn't list them as deps. ESLint will warn; React may behave unexpectedly if values change.
**How to fix:** Add the deps: `useEffect(() => { ... }, [params, navigate])`.

---

### BUG-40 · Courses typed as `any` in `DashboardPage` 🔴
**File:** `frontend/src/pages/DashboardPage.tsx` · **Line:** 67
**What's wrong:** `courses.map((course: any) => ...)` — no type safety on Canvas course objects.
**How to fix:** Define an interface:
```ts
interface CanvasCourse { id: number; name: string; course_code: string; }
```
And type the state as `CanvasCourse[]`.

---

## Summary

| Severity | Count | Fixed |
|---|---|---|
| 🔴 CRITICAL | 4 | 0 |
| 🟠 HIGH | 11 | 0 |
| 🟡 MEDIUM | 9 | 0 |
| 🔵 LOW | 8 | 0 |
| **Total** | **40** | **0** |

---

## Suggested Fix Order

1. **BUG-01, 02** — Encryption (this is Week 2's crypto.service.ts task, do these together)
2. **BUG-03, 04, 32** — JWT delivery method + CSRF (all related to auth flow, fix in one pass)
3. **BUG-29** — Startup env var validation (quick win, catch missing config at startup)
4. **BUG-08, 09, 10, 11** — Null pointer crashes (one-liner fix per route, do all four together)
5. **BUG-12** — courseId UUID mismatch (fix when wiring up chat sessions)
6. **BUG-39** — Settings wiping API key (fix when building SettingsPage)
7. **BUG-13, 14, 15, 16, 17** — Quiz/tools hardening (fix when building those features)
8. **BUG-05, 06** — Role logic + rate limiting (fix before any real users)
9. All MEDIUM + LOW — address as features are built
