# DHAV Backend — Railway Deployment Guide

**Live URL:** https://dhav-backend-production.up.railway.app
**Project ID:** 0dd77e8a-b889-4864-a314-a4184ecf51f0
**Service name:** dhav-backend

---

## FIRST TIME SETUP (already done — skip this)

These steps were done once. You do NOT need to repeat them.

```powershell
railway login                  # opens browser, click Authorize
cd backend
railway init                   # named it: dhav-backend
.\railway_env_setup.ps1        # set all 22 env vars
railway up                     # first deploy
railway domain                 # created the public URL
```

---

## PUSHING AN UPDATE (do this every time you change backend code)

This is the only command you need after making code changes:

```powershell
cd "C:\Users\Harshad Salunke\Desktop\Kirana Project\backend"
railway up
```

That's it. Railway rebuilds and redeploys automatically.
Build takes about 2–3 minutes. Check it finished:

```powershell
railway status
# Should show:  dhav-backend: ● Online
```

Verify the new code is live:

```powershell
Invoke-WebRequest -Uri "https://dhav-backend-production.up.railway.app/health" -UseBasicParsing | Select-Object StatusCode, Content
# Should return: 200  {"status":"ok",...}
```

---

## ADDING A NEW ENVIRONMENT VARIABLE

### Option A — Simple value (no special characters)

```powershell
cd "C:\Users\Harshad Salunke\Desktop\Kirana Project\backend"
railway variable set MY_NEW_VAR=my_value --service dhav-backend
```

Example:
```powershell
railway variable set RAZORPAY_KEY_ID=rzp_live_abc123 --service dhav-backend
railway variable set MAX_ORDERS_PER_HOUR=100 --service dhaw-backend
```

Railway **auto-redeploys** when you set a variable. If you want to set several at once without triggering a redeploy each time, add `--skip-deploys` and then run `railway up` at the end:

```powershell
railway variable set RAZORPAY_KEY_ID=rzp_live_abc123 --service dhav-backend --skip-deploys
railway variable set RAZORPAY_KEY_SECRET=secret_xyz --service dhav-backend --skip-deploys
railway up   # one redeploy with both vars
```

### Option B — Sensitive value with special characters (like JSON or private keys)

Use Python to pipe raw bytes — avoids PowerShell adding a BOM character that breaks JSON parsing:

```powershell
cd "C:\Users\Harshad Salunke\Desktop\Kirana Project\backend"

# Pipe value from Python (safe for any special characters)
python -c "import sys; sys.stdout.buffer.write(b'my secret value with special chars !@#$')" | railway variable set MY_SECRET --stdin --service dhav-backend
```

For a JSON file (like adding a new service account):
```powershell
python -c "import json,sys; sys.stdout.buffer.write(json.dumps(json.load(open('some-key.json'))).encode('utf-8'))" | railway variable set SOME_JSON_VAR --stdin --service dhav-backend
```

---

## VIEWING CURRENT ENVIRONMENT VARIABLES

See all vars set on the service:

```powershell
cd "C:\Users\Harshad Salunke\Desktop\Kirana Project\backend"
railway variable list --service dhav-backend
```

Check a specific variable's value:

```powershell
railway variable list --service dhav-backend --kv | Select-String "FIREBASE_PROJECT_ID"
```

---

## DELETING AN ENVIRONMENT VARIABLE

```powershell
railway variable delete MY_OLD_VAR --service dhav-backend
```

---

## VIEWING LIVE LOGS (for debugging crashes)

Stream live logs from the running service:

```powershell
cd "C:\Users\Harshad Salunke\Desktop\Kirana Project\backend"
railway logs --service dhav-backend
```

Press Ctrl+C to stop streaming.

If the service crashed, logs show the Python traceback — this is how you find what went wrong.

---

## ROLLING BACK TO A PREVIOUS DEPLOY

Go to the Railway dashboard in your browser:
https://railway.com/project/0dd77e8a-b889-4864-a314-a4184ecf51f0

1. Click the **dhav-backend** service
2. Click the **Deployments** tab
3. Find the last working deployment
4. Click the **three dots (...)** → **Rollback**

---

## COMMON ERRORS AND FIXES

| Error in logs | Cause | Fix |
|---|---|---|
| `FileNotFoundError: firebase-service-account.json` | `FIREBASE_SERVICE_ACCOUNT_JSON` var not set on service | Re-run: `python -c "import json,sys; sys.stdout.buffer.write(json.dumps(json.load(open('firebase-service-account.json'))).encode('utf-8'))" \| railway variable set FIREBASE_SERVICE_ACCOUNT_JSON --stdin --service dhav-backend` then `railway up` |
| `json.JSONDecodeError` on startup | BOM character crept into the JSON env var | Same fix as above (the Python pipe method avoids BOM) |
| `Application startup failed` | Any startup error | Run `railway logs --service dhav-backend` to see the full traceback |
| `railway: command not found` | Railway CLI not installed | Run: `npm install -g @railway/cli` |
| `Unauthorized` when running railway commands | Not logged in | Run: `railway login` |

---

## QUICK REFERENCE

```
Live URL:     https://dhav-backend-production.up.railway.app
Health check: https://dhav-backend-production.up.railway.app/health
API docs:     https://dhav-backend-production.up.railway.app/docs
Dashboard:    https://railway.com/project/0dd77e8a-b889-4864-a314-a4184ecf51f0

Push update:  railway up
Check status: railway status
Live logs:    railway logs --service dhav-backend
List vars:    railway variable list --service dhav-backend
```
