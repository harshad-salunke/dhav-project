# DHAV Admin Portal — Firebase Hosting Deployment Guide

**Live URL:** https://dhav-quick-commerce.web.app
**Platform:** Firebase Hosting (free Spark plan — global CDN)
**Firebase project:** `dhav-quick-commerce`
**Talks to backend:** https://dhav-backend.onrender.com (Render — see [../backend/deployment_step.md](../backend/deployment_step.md))

> 💡 This is the **admin dashboard** (a Flutter **web** app). It is separate from
> the backend. The backend lives on Render and auto-deploys on `git push`. This
> portal lives on Firebase Hosting and is deployed **manually** with two commands.

---

## HOW FIREBASE HOSTING WORKS (read this once)

Firebase Hosting serves **static files** (HTML/JS/CSS) from Google's CDN. It does
**not** run or compile your code. Deployment is always two steps:

```
  1. flutter build web   ──►  compiles Dart  ──►  writes static files to build/web/
  2. firebase deploy     ──►  uploads build/web/  ──►  live on the CDN
```

⚠️ **The most important thing to understand:** `firebase deploy` only **uploads
whatever is already in `build/web/`**. It does NOT rebuild. If you change code and
deploy without rebuilding first, you ship the **old** version. **Always build first.**

### The files that control deployment

| File | Purpose |
|---|---|
| `firebase.json` | What to upload (`"public": "build/web"`) + SPA rewrites + cache rules |
| `.firebaserc` | Which Firebase project to deploy to (`dhav-quick-commerce`) |
| `lib/core/config/api_config.dart` | Which backend the portal calls (baked in at build time) |

---

## ⭐ DEPLOYING AN UPDATE (do this every time you change the admin portal)

This is the whole workflow. Run it from **this** folder (`admin_dashboard`):

```powershell
cd "C:\Users\Harshad Salunke\Desktop\Kirana Project\admin_dashboard"

# 1. Compile the Flutter web app (points at the Render backend by default)
flutter build web

# 2. Upload it to Firebase Hosting
firebase deploy --only hosting
```

When it finishes you'll see:

```
+  Deploy complete!
Hosting URL: https://dhav-quick-commerce.web.app
```

Then open https://dhav-quick-commerce.web.app and **hard-refresh** (`Ctrl+Shift+R`)
to bypass the browser cache and see the new version.

---

## THE BACKEND URL (important)

The portal needs to know where the backend is. This is set in
[lib/core/config/api_config.dart](lib/core/config/api_config.dart):

```dart
static const String baseUrl = String.fromEnvironment('API_BASE_URL',
    defaultValue: 'https://dhav-backend.onrender.com');
```

- **Default (no flag):** uses the production Render backend. This is what you want
  for the deployed portal — just run `flutter build web`.
- **Override at build time** (e.g. to point at a different backend):

  ```powershell
  flutter build web --dart-define=API_BASE_URL=https://your-other-backend.com
  ```

> The URL is **baked into the build**. To change which backend the *deployed*
> portal talks to, you must rebuild and redeploy — you can't change it after the fact.

---

## IF YOU ALSO CHANGED BACKEND CODE

The portal and backend deploy **separately**:

| You changed… | Deploy with… |
|---|---|
| Files in `admin_dashboard/lib/**` | `flutter build web` + `firebase deploy --only hosting` (this guide) |
| Files in `backend/**` | `git push origin main` → Render auto-deploys ([guide](../backend/deployment_step.md)) |

If a change touches **both** (e.g. a new admin feature with a new API endpoint),
deploy the **backend first**, confirm `/health` is green, then build + deploy the
portal so it never calls an endpoint that isn't live yet.

---

## FIRST-TIME SETUP (already done — for reference only)

You only ever do this once per machine. It's already set up, but if you switch
computers:

```powershell
# Install the Firebase CLI (needs Node.js)
npm install -g firebase-tools

# Log in to your Google account (opens a browser)
firebase login

# Link this folder to the Firebase project (creates .firebaserc)
cd "C:\Users\Harshad Salunke\Desktop\Kirana Project\admin_dashboard"
firebase use dhav-quick-commerce
```

Check you're logged in and on the right project:

```powershell
firebase login:list                 # shows your account
firebase projects:list              # dhav-quick-commerce should be "(current)"
```

---

## VIEWING DEPLOYMENT HISTORY & ROLLING BACK

Firebase keeps every release, so you can roll back instantly if a deploy breaks
something:

**Firebase Console** → https://console.firebase.google.com/project/dhav-quick-commerce/hosting
→ **Hosting** → **Release history** → find the last good release → **⋮** → **Rollback**.

No rebuild needed — it re-serves the previous upload.

---

## COMMON ISSUES AND FIXES

| Symptom | Cause | Fix |
|---|---|---|
| Deployed site shows the **old** version | Deployed without rebuilding | Run `flutter build web` **before** `firebase deploy` |
| Changes still not visible after deploy | Browser cached the old `index.html`/JS | Hard refresh `Ctrl+Shift+R`, or open in an incognito window |
| `Error: Failed to get Firebase project` | Not logged in / wrong project | `firebase login` then `firebase use dhav-quick-commerce` |
| Portal loads but all data fails / "API error" | Backend asleep or wrong URL | Hit https://dhav-backend.onrender.com/health (free tier sleeps ~1 min); confirm `api_config.dart` URL |
| Login works locally but not on the live site | Auth domain not authorized | Firebase Console → Authentication → Settings → **Authorized domains** → ensure `dhav-quick-commerce.web.app` is listed |
| `firebase: command not found` | CLI not installed | `npm install -g firebase-tools` |
| Blank white page after deploy | Built with wrong `base href` | Rebuild with plain `flutter build web` (default base href `/` is correct for this project) |

---

## QUICK REFERENCE

```
Live URL:        https://dhav-quick-commerce.web.app
Firebase project: dhav-quick-commerce
Backend it calls: https://dhav-backend.onrender.com
Console:          https://console.firebase.google.com/project/dhav-quick-commerce/hosting

Deploy update:   cd admin_dashboard
                 flutter build web
                 firebase deploy --only hosting

Roll back:       Firebase Console → Hosting → Release history → Rollback
Check login:     firebase projects:list
```
