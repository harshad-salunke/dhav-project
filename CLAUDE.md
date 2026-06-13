# DHAV Project Context

You are helping build DHAV — a hyperlocal kirana delivery app for Pune.

**Project status: all build phases (0–8) are COMPLETE. We are in ENHANCEMENT MODE** —
improving UI/UX, adding features, changing earlier decisions, and filling gaps missed
during the phases. Do NOT plan work from BUILD_PLAN.md (historical record only).

Every session, automatically read:
1. docs/ENHANCEMENTS.md — **the live tracker**: current architecture truth, enhancement log, in-progress work, known gaps, backlog
2. docs/SESSION_NOTES.md — where we stopped last time (detailed dev journal)
3. docs/PRD.md — full product specification (note: §4 data models / §23 rules describe the old Firebase RTDB; DB is now Supabase Postgres)
4. UI Design for Customer App (Figma): https://www.figma.com/design/bbEiFc5W8heVd1J6sinAak/Dhav-customer?node-id=0-1&p=f&t=ZqS1uUyEUWHRC1N2-0
5. UI Design for Store App (Figma): https://www.figma.com/design/Yt5y4sL81YHyS5NhZXTiHc/Dhav-store?node-id=0-1&p=f&t=rBB2UYZvhCazqMFH-0

Then tell me: last completed enhancement, in-progress items, and the next task (from ENHANCEMENTS.md).

Tech stack (current — see ENHANCEMENTS.md → Current Architecture for the full table):
- Flutter apps (customer, store, admin-web)
- FastAPI backend on **Render** (https://dhav-backend.onrender.com)
- **Supabase PostgreSQL** for ALL data (asyncpg) + Supabase Storage for files
- Firebase for **Auth + FCM only** (+ Remote Config for the customer-app home UI)

End-of-session rules:
- Log the session in docs/SESSION_NOTES.md AND update docs/ENHANCEMENTS.md (log + gaps + architecture truth if it changed).
- Any NEW technology/concept introduced → teach it in docs/SYSTEM_DESIGN_NOTES.md (What → Why → Where → Real example → Impact → If not implemented).
