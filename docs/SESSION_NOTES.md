# 📓 DHAV — Session Notes (Dev Journal)

**Purpose:** This file is your memory across days. Update it at the END of every dev session. Read it at the START of every dev session.

**How Claude CLI uses this:** When you say "Read SESSION_NOTES.md and continue", Claude reads this and picks up exactly where you stopped.

---

## 📝 HOW TO USE THIS FILE

### Template for each session entry:

```markdown
## Session [DATE] — [TOPIC]

**Started:** [TIME]
**Stopped:** [TIME]
**Current Phase:** Phase X.Y
**Files modified:** list files

### What I did today:
- thing 1
- thing 2

### What worked:
- ...

### What broke / blockers:
- ...

### Code I'm uncertain about:
- file path : reason

### NEXT TIME — START HERE:
[Exact next task. Be specific. Include the Claude CLI prompt to use.]
```

---

## 🔖 CURRENT STATUS (Always update this at top)

**Current Phase:** Phase 0 — Project Setup
**Last task completed:** None yet
**Next task to do:** Create folder structure and initialize Git
**Blockers:** None
**Last updated:** [DATE]

---

## 📅 SESSION LOG

### Session 1 — [Date will go here] — Project Kickoff

**Started:** —
**Stopped:** —
**Current Phase:** Phase 0
**Files modified:** None

### What I plan to do:
- Set up folder structure
- Install Flutter, Python, Firebase CLI
- Create Firebase project
- Initialize Git repo
- Open Claude CLI for first time

### NEXT TIME — START HERE:
**Prompt for Claude CLI:**
> "Read docs/BUILD_PLAN.md and docs/PRD.md. Start helping me with Phase 1.1 — Firebase Project Setup. Walk me through creating the Firebase project step by step."

---

<!-- Add new sessions below this line, newest at top -->

---

## 🐛 BUG LOG

Track bugs you discover but haven't fixed yet:

| Date | Bug | Severity | File | Status |
|---|---|---|---|---|
| — | — | — | — | — |

---

## ❓ OPEN QUESTIONS

Things you're unsure about and need to decide:

- [ ] Should we charge ₹15 or ₹20 platform fee? Need to validate with 5 store owners.
- [ ] Which area in Pune to pilot first — Kothrud or Aundh?
- [ ] Should custom items by stores have a verification step by admin?
- [ ] How many delivery boys per store on average?

---

## 💡 IDEAS PARKING LOT

Things that aren't priority but worth remembering:

- Voice ordering in Marathi (Phase 2 feature)
- WhatsApp ordering channel (Phase 2)
- Subscription for daily milk/bread (Phase 2)
- Store reviews and photos by customers (Phase 2)
- Push notification campaigns for offers (Phase 2)

---

## 🔑 IMPORTANT CREDENTIALS & URLS

**Keep this updated as you set things up. NEVER commit this to public Git.**

| What | Where | Notes |
|---|---|---|
| Firebase Project ID | — | — |
| Firebase Service Account JSON path | `backend/firebase-service-account.json` | Add to .gitignore |
| Backend URL (dev) | — | After Railway deployment |
| Backend URL (prod) | — | — |
| Admin Dashboard URL | — | After Firebase Hosting |
| Customer App Play Store link | — | After launch |
| Store App Play Store link | — | After launch |
| Google Maps API Key | — | Restrict by app + IP |

---

## 📚 USEFUL COMMANDS REFERENCE

```bash
# Start Claude CLI
cd ~/DHAVl-project
claude

# Backend
cd backend
source venv/bin/activate
uvicorn main:app --reload

# Customer App
cd customer_app
flutter run

# Store App
cd store_app
flutter run

# Admin Dashboard
cd admin_dashboard
flutter run -d chrome

# Git
git status
git add .
git commit -m "Description"
git push

# Firebase deploy
firebase deploy --only database
firebase deploy --only storage
firebase deploy --only hosting

# Build APK
flutter build apk --release
```

---

## 🎯 WEEKLY GOALS (Track Weekly Progress)

### Week 1 Goals:
- [ ] Complete Phase 0
- [ ] Complete Phase 1
- [ ] Have Firebase + 50 catalog items seeded

### Week 2 Goals:
- [ ] Complete Phase 2.1 to 2.6 (backend skeleton + geofencing + broadcasting)

### Week 3 Goals:
- [ ] Complete Phase 2.7 to 2.12 (rest of backend)
- [ ] All APIs tested with Postman

### Week 4-5 Goals:
- [ ] Complete Phase 3 (Store App MVP)

### Week 6-7 Goals:
- [ ] Complete Phase 4 (Customer App MVP)

### Week 8 Goals:
- [ ] Complete Phase 5 (Delivery boy view + live tracking)

### Week 9-10 Goals:
- [ ] Complete Phase 6 (Admin Dashboard)

### Week 11 Goals:
- [ ] Testing + bug fixes

### Week 12 Goals:
- [ ] Deployment
- [ ] Pilot launch in Kothrud

---

*Update this file every single day. Your future self will thank you.*
