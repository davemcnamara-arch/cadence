# Cadence — Claude Code Notes
<!-- vercel deploy test 2 -->

## Auto-commit after every change

After making any code change, automatically run:
```
git add . && git commit -m "<brief description of changes>" && git push
```
Do this without being asked. Use a concise, descriptive commit message.

---

## Chatbot system prompt (`api/help.js`)

Whenever a feature is added, renamed, or removed from the app, update the chatbot system prompt in `api/help.js` to match.

Things that always need a prompt update:
- New buttons or UI labels visible to students or teachers
- Renamed actions or navigation items
- New sections, tabs, or modals
- Changed workflows (e.g. grading, exporting, class management)
- Removed features

Keep the prompt in sync with `js/app.js` and any HTML page changes. After updating `api/help.js`, commit it in the same PR or as a follow-up on the same branch.

---

## Project Overview

**Cadence** is a music learning platform: *student choice, teacher insight.* — a web app for classroom music programs where:

- **Students** self-track progress across 5 instruments through a structured 5-level system, grade songs, build a personal song library, and export reflections
- **Teachers** manage classes, monitor student progress, moderate a crowdsourced song library, and manage co-teachers and school membership
- **Schools** (School plan) centrally manage multiple teachers with unlimited students
- Students are always **free**; teachers/schools pay annual subscriptions (A$49 / A$199)

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Vanilla JavaScript (no framework), HTML5, CSS3 |
| Auth | Google OAuth 2.0 via Supabase Auth |
| Database | Supabase (PostgreSQL + RLS + JSONB) |
| Backend | Vercel Edge Functions (`api/` directory) |
| Payments | Stripe (hosted Checkout, annual subscriptions) |
| AI | Anthropic Claude API (`claude-opus-4-6`) |
| Hosting | Vercel (static + Edge Functions) |
| CDN imports | `https://esm.sh/@supabase/supabase-js@2` |

No build step. No bundler. `npm run dev` starts `live-server` on port 3000.

---

## Directory Structure

```
/cadence
├── index.html                  # Landing/marketing page
├── app.html                    # Main application shell
├── login.html                  # Google sign-in page
├── subscribe.html              # Subscription purchase page
├── subscribe-success.html      # Post-Stripe checkout landing
├── privacy.html                # Privacy policy
├── css/
│   └── style.css               # All styling (CSS custom properties, layout, components)
├── js/
│   ├── app.js                  # Main app logic (13,309 lines) — single CadenceApp class
│   ├── auth.js                 # AuthManager class with direct-fetch wrappers
│   ├── config.js               # Supabase client init + APP_CONFIG
│   ├── subscription.js         # checkSubscriptionStatus() helper (teachers only)
│   └── help-widget.js          # Self-contained floating chat assistant (IIFE)
├── api/                        # Vercel Edge/Serverless Functions
│   ├── create-checkout-session.js  # POST — initiate Stripe Checkout
│   ├── stripe-webhook.js           # POST — Stripe webhook receiver
│   └── help.js                     # POST — Claude AI SSE streaming chat
├── supabase/
│   └── migrations/             # 167 numbered SQL migration files (run in order)
├── sql/                        # Ad-hoc diagnostic/test queries (not migrations)
├── images/                     # Static assets
├── video-scripts/              # Marketing video scripts
├── vercel.json                 # Output dir + security headers + CSP
├── package.json                # Scripts: dev, build (no-op), deploy
└── SETUP.md                    # 6-step onboarding guide
```

---

## Architecture Decisions

### Single-file frontend
`js/app.js` is a single 13,309-line `CadenceApp` class. All views, state, and event handlers live here. This is intentional — no bundler, no modules splitting required, easy Vercel deployment.

### Direct fetch wrappers
`auth.js` exposes `fetchDirect`, `rpcDirect`, `insertDirect`, `patchDirect` — raw `fetch()` calls to the Supabase REST API that bypass the SDK client. These exist because the Supabase JS client can become stale after long idle periods (cached JWT). All have an 8-second `AbortController` timeout.

**Rule:** use these wrappers for any call that runs at auth time or in the grading flow. The main `supabase` client from `config.js` is fine for non-critical reads.

### No state library
All state lives on `this` in `CadenceApp`. Views are rendered by calling render functions that generate/update innerHTML. No virtual DOM.

### Supabase-first security
All access control is enforced via PostgreSQL RLS policies and `SECURITY DEFINER` stored functions. The frontend never trusts its own role checks for data access.

---

## Key Conventions

- **Soft deletes**: songs use `archived_at` timestamp instead of DELETE. Always filter `archived_at IS NULL` in queries (except admin views).
- **JSONB for structured data**: `skills_json`, `grading_checklist_json`, `checklist_responses_json` on levels/ratings store arrays/objects.
- **Idempotency**: Stripe webhook events are deduplicated via the `processed_webhook_events` table (`event_id` unique key). Always insert before processing.
- **Subscription check**: teachers are gated on page load. Students are **never** gated — they retain full access even if a school's subscription lapses.
- **Toast notifications**: user feedback uses `this.showToast(message, type)` — never `alert()`.
- **Modal system**: modals are hidden `<div>` elements in `app.html` revealed by CSS class changes. Never `display: block` directly.
- **No `console.log` in production paths**: only use for debugging. Auth errors use `console.error`.
- **Help prompt sync**: whenever you add/rename/remove a UI feature, update `api/help.js` `SYSTEM_PROMPT`.

---

## Database Schema (Core Tables)

All tables live in the default `public` schema. UUIDs are `uuid_generate_v4()`.

### Users & Auth
```sql
users (
  id UUID PK → auth.users(id),
  email TEXT UNIQUE,
  name TEXT,
  google_id TEXT UNIQUE,
  role TEXT CHECK IN ('student','teacher','admin'),
  created_at, updated_at
)
```

### Instruments & Levels
```sql
instruments (id, name, icon, description, display_order)

levels (
  id, instrument_id → instruments,
  level_number INT,
  name TEXT, description TEXT,
  skills_json JSONB,           -- array of skill strings
  grading_checklist_json JSONB, -- array of {question, points} objects
  example_songs TEXT[],
  is_branch BOOLEAN,           -- true for Level 4 specialisations
  branch_name TEXT,
  parent_level_id → levels,
  UNIQUE(instrument_id, level_number, branch_name)
)
```
Level 4 branches into 3 specialisation paths; Level 5 has advanced branches matching Level 4.

### Student Progress & Songs
```sql
student_progress (
  id, user_id, instrument_id,
  current_level INT,
  current_branch TEXT,         -- NULL for levels 1-3
  date_started, last_updated,
  UNIQUE(user_id, instrument_id)
)

student_songs (
  id, user_id, song_id, instrument_id,
  status TEXT CHECK IN ('learning','mastered'),
  date_started, date_completed,
  UNIQUE(user_id, song_id, instrument_id)
)

songs (
  id, title, artist,
  youtube_url, thumbnail,
  date_added, added_by_user_id,
  approved BOOLEAN,            -- false = pending moderation
  archived_at TIMESTAMPTZ      -- soft delete; NULL = visible
)

song_ratings (
  id, song_id, instrument_id, user_id,
  assessed_level INT,
  branch_name TEXT,
  checklist_responses_json JSONB,
  UNIQUE(song_id, instrument_id, user_id)
)
```

### Resources
```sql
song_tutorials (id, song_id, url, title, submitted_by_user_id, status IN ('pending','approved','rejected'))
student_resources (id, song_id, user_id, title, file_url, file_type, status)
pending_links (id, song_id, url, submitted_by_user_id, status)
resource_ratings (user_id, resource_id, rating, helpful_count)
```

### Classes & Schools
```sql
classes (id, class_code CHAR(6), name, teacher_id, year_level, archived BOOLEAN)
class_members (class_id, user_id, joined_at)
class_co_teachers (class_id, co_teacher_id, invited_by_user_id, status)
pending_class_co_teachers (class_id, invited_user_id)

schools (id, name, join_code, created_by)
school_members (school_id, user_id, school_role IN ('admin','teacher'))
school_hidden_songs (school_id, song_id)   -- blocklist mode
school_allowed_songs (school_id, song_id)  -- curated mode
```

### Subscriptions & Billing
```sql
subscriptions (
  id, teacher_id, school_id,
  plan_type IN ('individual','school'),
  status IN ('active','trialing','expired','cancelled'),
  stripe_subscription_id,
  current_period_start, current_period_end,
  archived_at
)

promo_codes (code, plan_type, status, redeemed_by, redeemed_at)
processed_webhook_events (event_id UNIQUE) -- Stripe idempotency
```

### Account Management
```sql
pre_registered_accounts (email, invited_by_teacher_id, role, name, school_id)
pending_enrollments (class_id, email)
dismissed_duplicates (song_id_1, song_id_2)
```

---

## Key RPC Functions

These are PostgreSQL stored functions called via `supabase.rpc()` or `auth.rpcDirect()`.

### Student
| Function | Purpose |
|---|---|
| `grade_song(...)` | Submit song rating with checklist; creates/updates `song_ratings` + `songs` |
| `get_popular_songs(instrument_id, limit)` | "Popular Right Now" strip — songs most students are currently learning |
| `next_song_suggestions(instrument_id)` | Songs other students learned after mastering the same songs as you |
| `find_similar_songs(title, artist)` | Duplicate prevention on song submission |
| `find_similar_instruments(name)` | Duplicate prevention on instrument addition |
| `process_pending_enrollments(p_user_id)` | Auto-enrol student in classes where their email was pre-added |

### Teacher
| Function | Purpose |
|---|---|
| `get_teacher_classes()` | All classes owned or co-taught by current teacher |
| `get_class_students(class_id)` | Roster with progress data |
| `get_student_detail(student_id)` | Full profile: progress + songs across all instruments |
| `get_all_teacher_students_with_progress()` | All students across all teacher's classes |
| `get_teacher_student_songs(...)` | All songs students are learning/mastered |
| `update_song_level(song_id, instrument_id, level)` | Teacher adjusts a flagged rating |
| `check_pre_registration(p_email)` | Lookup for pre-registered teacher accounts |
| `complete_pending_teacher_setup(p_email)` | Transfer pre-created classes to new teacher on first login |

### School
| Function | Purpose |
|---|---|
| `create_school(name)` | Create school + add creator as admin |
| `join_school(code)` | Teacher joins existing school via join code |
| `get_my_school()` | Current teacher's school info |
| `get_school_dashboard(school_id)` | Stats, teacher list, class list |
| `get_school_students(school_id)` | All students across all school classes |
| `leave_school(school_id)` | Teacher exits school |
| `update_school_member_role(...)` | Promote/demote school admins |
| `remove_from_school(...)` | Admin removes a teacher |
| `auto_join_school_by_id(p_school_id)` | Used during pre-registration onboarding |

### Subscriptions
| Function | Purpose |
|---|---|
| `get_my_subscription()` | Returns teacher's active subscription row |
| `redeem_promo_code(code)` | Activate 30-day trial; School plan triggers school onboarding |
| `admin_get_subscriptions()` | Admin: all subscription rows |
| `admin_upsert_subscription(...)` | Admin: create/update subscription |
| `restore_school_for_teacher(teacher_id)` | Unhide archived school on renewal |
| `archive_school_for_teacher(teacher_id)` | Hide school on subscription lapse |

---

## API Endpoints (Vercel Functions)

### `POST /api/create-checkout-session`
- **Runtime**: Serverless (Node.js)
- **Request**: `{ plan: 'individual'|'school', supabase_uid?: UUID }`
- **Response**: `{ url: string }` — Stripe Checkout URL
- **Pricing**: `individual` = A$49/year, `school` = A$199/year (AUD)
- **Security**: Origin/Host validation for CSRF; UUID v4 regex on `supabase_uid`
- **Stripe API version**: `2024-04-10`

### `POST /api/stripe-webhook`
- **Runtime**: Serverless (Node.js)
- **Auth**: Stripe signature verification (raw body required)
- **Events handled**: `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`, `invoice.payment_failed`
- **Idempotency**: inserts into `processed_webhook_events` before processing; skips duplicates
- **On subscription change**: calls `restore_school_for_teacher` / `archive_school_for_teacher` via service-role RPC

### `POST /api/help`
- **Runtime**: Edge
- **Request**: `{ messages: [{role, content}] }` — last 10 turns, content truncated to 4000 chars
- **Response**: SSE stream (`data: {"text": "..."}` chunks, ends with `data: [DONE]`)
- **Model**: `claude-opus-4-6` with prompt caching (`cache_control: { type: 'ephemeral' }`)
- **Max tokens**: 1024

---

## Frontend State (CadenceApp class)

Key properties on `this` in `app.js`:

```javascript
// Student state
currentInstrument        // instrument_id (UUID)
currentProgressId        // student_progress.id (for "Other" instrument rows)
instruments[]            // all instrument objects
levels[]                 // all level objects for currentInstrument
songs[]                  // loaded song library
studentProgress[]        // all student_progress rows for current user
studentSongs[]           // all student_songs rows for current user

// Teacher state
classes[]
currentClass             // selected class object
classStudents[]
allTeacherStudents
flaggedRatings[]
otherInstrumentCustomNames  // { student_progress_id: customName }

// School state
currentSchool
teacherSchools[]
schoolDashboardData
schoolStudents[]
schoolHiddenSongIds      // Set<uuid>
schoolAllowedSongIds     // Set<uuid>

// Subscription
subscription             // { plan_type, status, current_period_end, ... }

// Preview mode
previewMode: {
  active, studentId, studentName,
  originalUser, originalView,
  originalStudentProgress, ...
}
```

### Navigation Views
- **Student**: `pathway`, `songs`, `progress`
- **Teacher**: `classes`, `student-songs`, `flagged`, `school`
- **Admin**: `admin`, `accounts`

---

## Authentication Flow

1. `auth.init()` — calls `supabase.auth.getSession()` with 8s timeout
2. If session exists → `handleAuthSuccess(authUser)`
   - `fetchDirect('users', ...)` to check if user exists in `users` table
   - If new user: check `check_pre_registration(email)` → auto-create with pre-registered role, or default to `student`
   - If existing user with role switch (from `cadence_signup_role` in localStorage): `patchDirect` to update role
3. `processPendingEnrollments(userId)` — auto-joins classes where email was pre-added
4. For new teachers: `complete_pending_teacher_setup(email)` — transfers pre-created classes
5. Calls `auth.onAuthStateChange(user)` → `app.js` `onUserSignedIn(user)` → subscription check + render

**OAuth redirect**: After Google OAuth, Supabase redirects to `/app.html#access_token=...`. Auth cleans the hash with `history.replaceState` to prevent back-button issues.

**Sign out**: Direct `POST` to `${SUPABASE_URL}/auth/v1/logout` with 5s timeout, then `localStorage.removeItem` for the session key (`sb-*-auth-token`).

---

## Subscription Check Logic

`checkSubscriptionStatus(auth)` in `subscription.js`:
- Calls `get_my_subscription()` RPC
- Returns `{ hasSubscription, isActive, isExpired, status, currentPeriodEnd, sub }`
- `isActive = (status === 'active' || status === 'trialing') && periodEnd > now`
- Called on every teacher page load in `onUserSignedIn()`
- If not active → full-screen overlay with "Renew Subscription" button
- Students are **never** checked

---

## Instruments

Default instruments (seeded):
- Guitar (orange, `🎸`)
- Bass Guitar (purple, `🎸`)
- Piano/Keyboard (cyan, `🎹`)
- Drums (red, `🥁`)
- Vocals (magenta, `🎤`)

Students can also add **"Other Instrument"** — a special instrument row that stores a custom name in `student_progress`. The custom name appears throughout the UI. `find_similar_instruments()` prevents near-duplicate custom names.

---

## Level Structure

Each standard instrument has:
- **Levels 1–3**: Linear progression
- **Level 4**: Branches into 3 specialisation paths (`is_branch = true`)
- **Level 5**: Advanced techniques per Level 4 branch

Level data includes:
- `skills_json`: array of skill description strings shown on the pathway card
- `grading_checklist_json`: array of checklist items used in the "Grade a Song" wizard
- `example_songs`: text array of example songs at that level

---

## Deployment

### Environment Variables (Vercel)
```
STRIPE_SECRET_KEY              # Stripe secret key
STRIPE_WEBHOOK_SECRET          # Stripe webhook signing secret
SUPABASE_URL                   # Same as in js/config.js
SUPABASE_SERVICE_ROLE_KEY      # Service role key (server-only, never in frontend)
ANTHROPIC_API_KEY              # For api/help.js
```

### Supabase credentials in frontend
`js/config.js` has the **anon key** hard-coded (safe — anon key is public; RLS enforces access). The service role key is **only** in Vercel env vars, used by `api/stripe-webhook.js`.

### Commands
```bash
npm run dev     # live-server on :3000
npm run deploy  # vercel --prod
```

### vercel.json
- `outputDirectory: "."` — static files served from root
- CSP allows: `self`, `unsafe-inline` scripts/styles, `fonts.googleapis.com`, `*.supabase.co`, `wss://*.supabase.co`, `api.stripe.com`, `esm.sh`
- Security headers: `X-Content-Type-Options`, `X-Frame-Options: DENY`, `HSTS`, `Referrer-Policy`

---

## School Song Filtering (migrations 150–152)

Two modes controlled per school:

- **Blocklist mode** (default): all approved songs visible; teachers use "Hide from School" on a song card's `⋯` menu to add to `school_hidden_songs`
- **Curated mode**: only explicitly released songs visible; teachers use "Release to School" / "Remove from School" to manage `school_allowed_songs`

RLS for these tables has a known complexity: recursive policy patterns were fixed in migration 152 to avoid infinite loops.

---

## Stripe Webhook Details

File: `api/stripe-webhook.js`

- Uses `getRawBody()` to read the raw request body (required for Stripe signature verification; Vercel parses JSON by default)
- Idempotency: `INSERT INTO processed_webhook_events(event_id) VALUES($1)` — if unique constraint fails, event already processed, return 200 and skip
- After `checkout.session.completed`: creates/updates `subscriptions` row via service-role Supabase client
- After `customer.subscription.deleted`: sets status to `cancelled`, calls `archive_school_for_teacher`
- After `invoice.payment_failed`: sets status to `expired`
- After successful renewal: calls `restore_school_for_teacher`

---

## Help Widget (`js/help-widget.js`)

Self-contained IIFE — injects its own `<style>` and DOM nodes. No external dependencies. Features:

- Floating `💬` button, slides up panel
- Keeps last 10 message turns in memory (cleared on "🗑" button)
- Streams SSE from `POST /api/help`
- Renders markdown (bold, italic, bullets, code) after stream completes
- Uses CSS custom properties (`--primary`, `--bg-card`, etc.) from `style.css`

---

## Migration Numbering

167 files in `supabase/migrations/`. Key milestones:

| Range | Major Feature |
|---|---|
| 001–020 | Initial schema, RLS, grading, teacher dashboard, link moderation |
| 021–050 | Song resources, tutorials, admin tools, pre-registered accounts |
| 051–099 | Schools, school_members, subscriptions, trending, soft deletes |
| 100–120 | Webhook idempotency, song filtering, progress exports |
| 121–145 | Other instrument support, promo codes, co-teaching, class handoff |
| 146–152 | Peer roster access, school song filtering, RLS recursion fixes |

Files are run once in numbered order. To change schema, always create a new numbered file — never edit existing migrations.

---

## Common Gotchas

1. **Stale Supabase client**: After long idle, the JS client may not refresh tokens. Use `auth.rpcDirect()` / `auth.fetchDirect()` for critical paths.

2. **Auth timeout**: All direct fetch calls have 8s `AbortController` timeout. If Supabase is slow, the user sees a "Connection timeout" error. A 15s retry link appears on the loading screen.

3. **Soft deletes**: Songs with `archived_at IS NOT NULL` must be excluded from all non-admin queries. Forgetting this causes deleted songs to reappear.

4. **RLS recursion**: policies on `school_hidden_songs` and `school_allowed_songs` were rewritten in migration 152 to avoid recursive SELECT loops. Be careful adding policies that JOIN back to tables with other policies.

5. **Stripe raw body**: `api/stripe-webhook.js` reads `req` as a raw stream. If Vercel parses the body first, signature verification will fail.

6. **Subscription check timing**: In `completeSignupWithRole()`, if a teacher is pre-registered with a `school_id`, `auto_join_school_by_id` is called *before* `onAuthStateChange` fires — so the subscription check in `onUserSignedIn()` finds the school subscription correctly.

7. **`cadence_signup_role` in localStorage**: Set by `login.html` when user clicks "I'm a teacher". Auth reads this and either creates the account with that role or switches an existing user's role. Always `localStorage.removeItem('cadence_signup_role')` after reading to avoid stale state.

8. **`currentProgressId`**: Students can have multiple "Other Instrument" rows in `student_progress` (one per custom instrument). `currentProgressId` is needed to distinguish them, unlike standard instruments which use `currentInstrument` (instrument UUID).
