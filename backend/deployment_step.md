# DHAV Backend — Render Deployment Guide

**Live URL:** https://dhav-backend.onrender.com
**Platform:** Render (free tier — no credit card)
**Service name:** dhav-backend
**Deploys from:** GitHub repo `harshad-salunke/dhav-project`, branch `main`, via [render.yaml](../render.yaml)

> ⚠️ If Render added a random suffix to your URL (e.g. `dhav-backend-a1b2.onrender.com`),
> use that instead. The real URL is shown at the top of your service page in the
> Render dashboard. Update it everywhere in this file if it differs.

> 💡 We migrated off Railway (its free tier became a paid trial after 1 month).
> The old Railway guide is replaced by this file. Database is still **Supabase**
> (free) and Redis is still **optional** — only the FastAPI app moved.

---

## HOW RENDER WORKS (read this once)

Render is connected to your **GitHub repo**. It watches the `main` branch.
**Every time you push to `main`, Render automatically rebuilds and redeploys.**

There is no CLI command to learn. Your normal git workflow *is* the deploy.

```
  you: git push  ──►  GitHub  ──►  Render detects push  ──►  build + deploy  ──►  live
```

---

## ⭐ PUSHING AN UPDATE (do this every time you change backend code)

This is the whole workflow. After editing any backend code:

```powershell
cd "C:\Users\Harshad Salunke\Desktop\Kirana Project"

git add .
git commit -m "describe what you changed"
git push origin main
```

That's it. Render sees the push and **auto-deploys**. Build takes ~3–5 minutes.

Watch it happen: open the Render dashboard → **dhav-backend** service → **Logs**
(or the **Events** tab). When you see this line, the new code is live:

```
==> Build successful 🎉
INFO:     Application startup complete.
```

Then verify the new code is running:

```powershell
Invoke-WebRequest -Uri "https://dhav-backend.onrender.com/health" -UseBasicParsing | Select-Object StatusCode, Content
# Should return: 200  {"status":"ok","version":"...","db":"supabase_postgresql"}
```

### Manual redeploy (without a code change)

If you change an env var or just want to force a fresh deploy:
Dashboard → **dhav-backend** → top-right **Manual Deploy** → **Deploy latest commit**.

---

## ⚠️ FREE TIER: THE SLEEP BEHAVIOUR (important)

Render's free web service **spins down after 15 minutes with no traffic**.
The next request then takes **~1 minute to wake it up** (it will feel "stuck",
then work). While asleep, WebSockets drop and the background scheduler pauses.

This is normal for free hosting. Two things to know:

- **For demos / testing:** hit `/health` once a minute to keep it warm. You can
  set up a free pinger at [cron-job.org](https://cron-job.org) pointing at
  `https://dhav-backend.onrender.com/health` every 14 minutes.
- **Free quota:** 750 instance-hours per month per account (enough for one service).

---

## MANAGING ENVIRONMENT VARIABLES

Render env vars are set in the **dashboard** (not a CLI / not a script).

**To view or edit:** Dashboard → **dhav-backend** → left sidebar → **Environment**.

The secrets currently set (these came from your local `backend/.env`):

| Variable | Purpose |
|---|---|
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Full Firebase service-account JSON, on **one line** |
| `DATABASE_URL` | Supabase pooler URL (port 6543) — all app queries |
| `DIRECT_URL` | Supabase URL (port 5432) — migrations/DDL |
| `SUPABASE_SERVICE_KEY` | Supabase service_role key |
| `FIREBASE_PROJECT_ID` | `dhav-quick-commerce` (set automatically by render.yaml) |
| `PYTHON_VERSION` | `3.11.9` (set automatically by render.yaml) |
| `REDIS_URL` | Left blank → app runs single-worker mode |

**To add a new variable:**
1. Environment tab → **Add Environment Variable**.
2. Enter the **Key** and **Value** → **Save Changes**.
3. Render auto-redeploys with the new value.

**Adding the same var permanently to the blueprint** (optional, recommended for
non-secrets): add it under `envVars` in [render.yaml](../render.yaml), then
`git push`. For secrets, keep using `sync: false` in render.yaml and paste the
value in the dashboard so it's never committed.

### Pasting long secrets (like the Firebase JSON) — avoid the double-paste bug

The Firebase JSON is one long line (~2372 chars). When pasting it:
- **Clear the field completely first**, then paste **once** (single Ctrl+V).
- It must be **one line, no line breaks**, starting `{"type":"service_account"...`
  and ending with a single `}`.
- If you see `}{` or a second `{"type"` partway through, you pasted twice — clear
  and paste once. (This is the `JSONDecodeError: Extra data` error.)

To regenerate the one-line value onto your clipboard:
```powershell
cd "C:\Users\Harshad Salunke\Desktop\Kirana Project"
python -c "import json; print(json.dumps(json.load(open('backend/firebase-service-account.json'))))" | Set-Clipboard
```

---

## VIEWING LIVE LOGS (for debugging crashes)

Dashboard → **dhav-backend** → **Logs** tab (streams live in the browser).

If the service crashed on startup, the logs show the Python traceback — that's
how you find what went wrong. The **Events** tab shows deploy history.

---

## ROLLING BACK TO A PREVIOUS DEPLOY

Dashboard → **dhav-backend** → **Deploys** tab → find the last working deploy →
**...** menu → **Rollback to this deploy**.

(Or just revert the bad commit in git and `git push` — that triggers a clean redeploy.)

---

## COMMON ERRORS AND FIXES

| Error in logs | Cause | Fix |
|---|---|---|
| `json.JSONDecodeError: Extra data` | `FIREBASE_SERVICE_ACCOUNT_JSON` was pasted twice | Environment tab → edit the var → clear field → paste **once** → Save |
| `FileNotFoundError: firebase-service-account.json` | `FIREBASE_SERVICE_ACCOUNT_JSON` not set | Add it in the Environment tab (one-line JSON, see above) |
| `Application startup failed` | Any startup error | Open the **Logs** tab and read the full Python traceback |
| First request hangs ~1 min | Free service was asleep | Normal — it's waking up. Keep it warm with a pinger (see Free Tier section) |
| `connection refused` / DB errors | `DATABASE_URL` wrong or Supabase paused | Check the var; un-pause the Supabase project if it slept |
| Build fails on `pip install` | Bad dependency / Python version | Check `requirements.txt`; `PYTHON_VERSION` is pinned to 3.11.9 in render.yaml |

---

## QUICK REFERENCE

```
Live URL:     https://dhav-backend.onrender.com
Health check: https://dhav-backend.onrender.com/health
API docs:     https://dhav-backend.onrender.com/docs
Dashboard:    https://dashboard.render.com

Push update:  git add . ; git commit -m "..." ; git push origin main   (auto-deploys)
Manual deploy: Dashboard → Manual Deploy → Deploy latest commit
Live logs:    Dashboard → dhav-backend → Logs tab
Env vars:     Dashboard → dhav-backend → Environment tab
Rollback:     Dashboard → dhav-backend → Deploys tab → Rollback
```
