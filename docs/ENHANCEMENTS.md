# 🚀 DHAV — Enhancement Tracker (the post-phases era)

> **This file replaces phase tracking.** All build phases (0–8) in `BUILD_PLAN.md` are
> **code-complete** — the project is now in **Enhancement Mode**: improving UI/UX, adding
> features, changing earlier decisions, and filling gaps missed during the phases.
>
> **Rule:** at the end of every session, log what changed here (newest first) and keep the
> "Current Architecture" section truthful. Detailed dev-journal entries still go in
> `SESSION_NOTES.md`; this file is the *summary + truth* so nobody re-reads stale docs.

---

## 🏗️ CURRENT ARCHITECTURE — single source of truth (2026-06-13)

> ⚠️ `docs/ARCHITECTURE.md` and `backend/ARCHITECTURE.md` describe the OLD
> Firebase-RTDB-on-Railway design. **This section is the current truth.**

| Layer | Technology | Notes |
|---|---|---|
| Backend | FastAPI (Python) on **Render** free tier | `https://dhav-backend.onrender.com` — sleeps after 15 min idle (~1 min cold start); use a cron-job.org `/health` pinger for demos. Deploy = `git push origin main` (auto). |
| Database | **Supabase PostgreSQL** via asyncpg (`backend/services/db.py`) | ALL app data. Transaction pooler :6543 for queries, session pooler :5432 for migrations. Schema: `backend/migrations/*.sql`. Firebase RTDB **removed**. |
| File storage | **Supabase Storage** | Firebase Storage removed. |
| Auth | Firebase Auth (Google + Email/Password) | Unchanged — backend verifies ID tokens. |
| Push | Firebase FCM | Unchanged — HIGH-priority order alerts, push-driven customer UI. |
| Dynamic UI | **Firebase Remote Config** (customer app, added 2026-06-13) | Home greeting/banners/deal section changeable from console, in-app defaults as fallback. |
| Realtime tracking | WebSocket `/ws/order/{id}/location`, in-memory + optional Redis Pub/Sub | Redis OFF (no `REDIS_URL`) → **run 1 worker only**. |
| Scheduler | APScheduler in-process | Settlements, suspensions, auto-fail crons. Pauses while Render sleeps. |
| Customer app | Flutter (`com.dhav.customer`) | Points to Render URL ✅ |
| Store app | Flutter (`com.dhav.store`, store owner + delivery roles) | Points to Render URL ✅ |
| Admin dashboard | Flutter Web on Firebase Hosting | LIVE: `https://dhav-quick-commerce.web.app`, points to Render URL ✅ |

---

## ✅ ENHANCEMENT LOG (newest first)

### 2026-06-13 — Customer home UI revamp + default address + Remote Config
- Home screen rebuilt to compete with Zepto/Blinkit/LoveLocal: mascot greeting
  ("कसं काय पुणेकर! 🙏" with `welcome_charactor.png`), two-line location header, white
  search bar with mascot chip, bigger banner carousel, Deal-of-the-Day with live
  countdown, rich "Shops in Your Area" cards. New files in `customer_app/lib/features/home/`.
- Default-address rules implemented (`address_provider.dart` + shared_preferences):
  last selected address persists across restarts and drives catalog loading; no address
  → GPS; "Use current location" remembered as a mode (fresh GPS each launch).
- Firebase Remote Config added (`ui_config_provider.dart`) — home text/banners/deal
  changeable from console without APK rebuild. Concepts 21–22 in SYSTEM_DESIGN_NOTES.md.
- **Status: code-complete, analyzer clean. NOT yet device-verified, APK not rebuilt.**

### ~2026-06-08 — Admin coverage map + store fixes (commit `de0ab32`)
- Admin dashboard: store verify/name alignment fixed; coverage map (Leaflet,
  `web/coverage_map.html`) showing store coverage — adapted for Postgres backend.
- ⚠️ Working tree still has uncommitted admin_dashboard changes (coverage_screen,
  firebase.json, web/) — commit or clean up.

### ~2026-06-06 — PostgreSQL migration 🔴→🟢 (BUILD_PLAN "Phase D" — actually done)
- ALL data moved Firebase RTDB → **Supabase PostgreSQL** (asyncpg pool, JSONB codecs,
  PgBouncer-aware). Firebase kept ONLY for Auth + FCM. Supabase Storage replaces
  Firebase Storage. Migrations in `backend/migrations/`.
- This supersedes: Firebase `.indexOn` work (Concept 19), RTDB security rules, and the
  "keep Firebase, don't migrate" decision in SYSTEM_DESIGN_IMPLEMENTATION.md.

### 2026-06-05 — Hosting: Railway → Render (free, no card)
- `render.yaml` blueprint; deploy = `git push origin main`. Guide: `backend/deployment_step.md`.
- All three Flutter clients updated to the Render URL (done, verified in api_config.dart).

### 2026-05-30 — Production scaling (Phase A+/B code)
- Event-loop unblocking, WS leak fix, event-driven broadcasting, optional Redis bus,
  push-driven customer UI. See SYSTEM_DESIGN_NOTES.md Concepts 9–20.

---

## 🚧 IN PROGRESS / NEEDS VERIFICATION

- [ ] Device-verify the new home screen + address flow (`cd customer_app && flutter run`)
- [ ] Rebuild customer APK (carries home revamp + push-driven UI from 2026-05-30)
- [ ] Commit or clean the uncommitted admin_dashboard working-tree changes
- [ ] (Optional) Create the Remote Config keys in Firebase Console to test live UI change

---

## 📋 KNOWN GAPS — missed during the phases (fill these during enhancements)

**Testing / QA**
- [ ] Real-device FCM verification: store popup rings on silent mode + background/killed wake-up
- [ ] Flutter widget tests (none exist)
- [ ] Manual QA checklist (PRD §24.4) + 15 end-to-end use cases (PRD §26)
- [ ] Backend tests after Postgres migration — re-run `pytest` (last known 39/39 was pre-Postgres)

**Launch (old Phase 7.3 / 7.4 — still pending)**
- [ ] Pilot: onboard 3 test stores in Kothrud, 10 end-to-end orders, 3 friend-testers
- [ ] Soft launch: 20 stores, flyers, daily monitoring
- [ ] Set up the `/health` keep-warm pinger before any demo/pilot day

**Ops (only when scaling)**
- [ ] Redis (Upstash/Render Redis) + `REDIS_URL` + `--workers N` — code ready, ops pending

**Stale docs (rewrite only if/when needed)**
- `docs/ARCHITECTURE.md`, `backend/ARCHITECTURE.md` — pre-Postgres/pre-Render (banners added)
- `docs/API_SPECIFICATIONS.md`, `docs/FIREBASE_SETUP.md` — partially pre-Postgres
- `docs/PRD.md` §4 data models / §23 security rules — describe RTDB, DB is now Postgres

---

## 💡 ENHANCEMENT BACKLOG (ideas, not committed)

- Store app UI polish to match the new customer-app quality
- Search screen: trending searches, voice search (mic is decorative today)
- Cart: delivery-fee transparency, savings strip, suggested add-ons
- Order Again: real item images + one-tap reorder of a full past order
- Customer app localization toggle (EN/MR/HI) — models already carry name_mr/name_hi
- Festival theming via Remote Config (Ganeshotsav/Diwali banners + greeting)
- Store ratings shown in nearby-stores API payload (rating exists in detail only)

---

*Created 2026-06-13 — after this date, update THIS file (not BUILD_PLAN.md) at session end.*
