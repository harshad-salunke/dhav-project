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
| Dynamic UI | **Firebase Remote Config** (customer app, added 2026-06-13) | Home header colours/greeting/search/banners/deal — editable from the **admin dashboard "Home UI"** screen (backend `/admin/home-config` → RC REST API) OR the Firebase console; in-app defaults as fallback. |
| Realtime tracking | WebSocket `/ws/order/{id}/location`, in-memory + optional Redis Pub/Sub | Redis OFF (no `REDIS_URL`) → **run 1 worker only**. |
| Scheduler | APScheduler in-process | Settlements, suspensions, auto-fail crons. Pauses while Render sleeps. |
| Customer app | Flutter (`com.dhav.customer`) | Points to Render URL ✅ |
| Store app | Flutter (`com.dhav.store`, store owner + delivery roles) | Points to Render URL ✅ |
| Admin dashboard | Flutter Web on Firebase Hosting | LIVE: `https://dhav-quick-commerce.web.app`, points to Render URL ✅ |

---

## ✅ ENHANCEMENT LOG (newest first)

### 2026-06-13 (#3) — Admin-controlled home top-section, end to end (Remote Config CMS)
- **You can now edit the customer home top-section from the admin dashboard** (no Firebase
  console, no APK rebuild): header gradient colours, greeting title/subtitle, search hint,
  Deal toggle/title, and the full promo-banner carousel (title/subtitle/cta/badge/emoji/
  image URL/colours) — with a **live phone preview**. New "Home UI" sidebar item.
- **Backend** `services/remote_config.py` talks to the Firebase Remote Config **REST API**,
  minting an OAuth2 token (`firebase.remoteconfig` scope) from the existing service account.
  New admin endpoints `GET/PUT /admin/home-config` (read merges only the 8 home keys, publish
  uses `If-Match` etag concurrency). `firebase_init.py` gained `get_service_account_info()`.
  `requirements.txt` pins `google-auth==2.53.0`.
- **Customer app**: header gradient is now remote-driven too (`home_header_color_start/_end`,
  default DHAV teal). Concept 23 added to SYSTEM_DESIGN_NOTES.md.
- **Cached** like catalog: the admin read is served from the shared `TTLCache`
  (`home_config` key, 5-min TTL) so the Home UI screen loads instantly; **publish does a
  write-through + cross-worker `cache.invalidate("home_config")`**, so a new value updates the
  cache immediately (no stale reads). Firebase is only hit on a cold cache or a console-side edit.
- ⚠️ **One-time setup**: if `Publish` returns 403, enable the **Firebase Remote Config API**
  in Google Cloud + grant the service account **Firebase Remote Config Admin** role.
- **Status: code-complete; backend boots (87 routes, both home-config routes present); all
  changed Dart files analyzer-clean (0 errors). NOT yet run against live Firebase / device.**

### 2026-06-13 (#2) — Image promo banners + Romanized Marathi (LoveLocal-style top section)
- **Hero banner now supports background photos** (`hero_banner.dart` rewritten): each
  Remote Config banner can set `image_url` → full-bleed promo photo with a left→right
  dark scrim for text legibility + an optional `badge` chip ("up to 20% OFF"), matching
  the LoveLocal "Meaty Delights" reference. No `image_url` → falls back to the old
  gradient + floating-emoji card. Banner height 152→168px. Whole card is tappable.
- **Remote Config schema extended** (`ui_config_provider.dart`): `HomeBannerConfig` gained
  `image_url` + `badge` fields (back-compatible — both optional). Default banner set now
  ships one image banner (Unsplash veggies) + two gradient banners.
- **All home-screen Marathi de-Devanagari'd → Romanized English** per request: greeting
  "कसं काय पुणेकर" → "Kasa kay, Punekar!", subtitle Romanized, search chip "झटपट" → "Zatpat".
  Fonts switched `notoSansDevanagari`→`inter` in greeting + banner + chip. (Language-PICKER
  labels "मराठी"/"हिंदी" left in native script — that's correct UX.)
- To change a banner live: Firebase Console → Remote Config → `home_banners` JSON array
  (set `image_url`/`badge`/`title`/`cta`/colors). Editing this from the admin Flutter app
  is NOT wired yet — see backlog.
- **Status: code-complete, analyzer clean (0 errors; only 4 pre-existing deprecation infos).
  NOT yet device-verified, APK not rebuilt.**

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
- [ ] **Grant the service account "Firebase Remote Config Admin" + enable the RC API** so the
      admin "Home UI" → Publish works (else 403). Then test: edit a banner → Publish → confirm
      the customer app reflects it after a fetch.
- [ ] Rebuild + redeploy admin dashboard (`flutter build web` → `firebase deploy --only hosting`)
      to ship the new "Home UI" editor.

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
- Festival theming via Remote Config (Ganeshotsav/Diwali banners + greeting) — NOTE: the
  admin "Home UI" editor (2026-06-13 #3) already makes this a 10-second non-dev action.
- Store ratings shown in nearby-stores API payload (rating exists in detail only)
- Admin "Home UI" editor polish: drag-reorder banners, image upload to Supabase Storage
  (today it's an image-URL field), a colour-picker widget (today it's a hex field).

---

*Created 2026-06-13 — after this date, update THIS file (not BUILD_PLAN.md) at session end.*
