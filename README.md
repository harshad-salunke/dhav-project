# 🛒 DHAV

> Empowering kirana stores in Pune to compete with Blinkit & Zepto — using only what they already have: their stock, their trust, and their own delivery boy.

---

## 📋 What is DHAV?

A hyperlocal commerce platform that connects customers in Pune with nearby kirana stores. Orders are broadcast to multiple nearby stores simultaneously (like Ola/Uber), and the first store to accept delivers using their own delivery boy.

**Key innovation:** B2B platform fee — customers pay only the product cost (cash on delivery), stores pay DHAV a small platform fee weekly. No delivery infrastructure on our side. Pure software platform.

---

## 🗂️ Project Structure

```
DHAVl-project/
├── docs/                       # All documentation
│   ├── PRD.md                  # Product Requirements Document (read this FIRST)
│   ├── BUILD_PLAN.md           # 7-phase build roadmap
│   ├── SESSION_NOTES.md        # Daily dev journal
│   ├── ARCHITECTURE.md         # System design deep dive
│   └── API_SPECIFICATIONS.md   # Every API endpoint detailed
│
├── backend/                    # FastAPI Python backend
├── customer_app/               # Flutter customer-facing app
├── store_app/                  # Flutter store owner + delivery boy app
├── admin_dashboard/            # Flutter Web admin panel
├── firebase/                   # Firebase config + security rules
│
└── README.md                   # This file
```

---

## 🚀 Quick Start

### Day 1 (Setup)
1. Read `docs/PRD.md` — understand WHAT we're building
2. Read `docs/BUILD_PLAN.md` — understand HOW we're building it
3. Follow Phase 0 in BUILD_PLAN.md to set up environment

### Every Day After
1. Open `docs/SESSION_NOTES.md` — see where you stopped
2. Work on ONE task at a time
3. Before closing: *"Update SESSION_NOTES.md with today's progress and next steps"*

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Customer App | Flutter (Android + iOS) |
| Store App | Flutter (Android + iOS) |
| Admin Dashboard | Flutter Web |
| Backend | FastAPI (Python 3.11+) |
| Database | Firebase Realtime Database |
| Storage | Firebase Storage |
| Auth | Firebase Auth (Google Sign-In + Email) |
| Notifications | Firebase Cloud Messaging (FCM) |
| Live Location | WebSocket (in-memory relay, no DB writes) |
| Maps | Google Maps API |
| Backend Hosting | Railway.app or Google Cloud Run |
| Admin Hosting | Firebase Hosting |

---

## 📐 Architecture (High Level)

```
Customer App     Store App        Admin Dashboard
     │                │                  │
     └────────────────┴──────────────────┘
                      │
            ┌─────────▼─────────┐
            │  FastAPI Backend   │
            │  + WebSocket Server│
            └─────────┬─────────┘
                      │
            ┌─────────▼─────────┐
            │  Firebase Services │
            └────────────────────┘
```

See `docs/ARCHITECTURE.md` for full deep dive.

---

## 💰 Business Model

- **Customer pays:** Product cost only, cash on delivery. Zero platform fee visible to customer.
- **Store pays DHAV:** ₹15 per successfully delivered order, settled weekly via UPI.
- **Result:** Pure platform business. No logistics costs. Lean operations.

---

## 🔐 Security Notes

- All writes to critical data go through FastAPI — NEVER direct Firebase writes from Flutter
- Firebase security rules enforce read access by role
- Live location data NEVER persisted (in-memory WebSocket relay only)
- `firebase-service-account.json` is in `.gitignore`
- `.env` files in `.gitignore`

---

## 📞 Support

For questions during development:
1. Check `docs/PRD.md` Section 26 (Use Cases)
2. Check `docs/SESSION_NOTES.md` (your past notes)
---

## 📜 License

Proprietary. All rights reserved.

---

*Built for Pune, by Pune, with love for kirana stores. 🇮🇳*
