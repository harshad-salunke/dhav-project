-- DHAV: "Notify me" waitlist for areas with no nearby store yet.
-- Run once in: Supabase Dashboard → SQL Editor → New Query → Run.
--
-- Captured when a customer taps "Notify Me" on the "No stores near you yet"
-- screen, so the team can see WHERE demand exists (which spots have customers
-- but no store in delivery range) and prioritise onboarding there.

CREATE TABLE IF NOT EXISTS coming_soon_waitlist (
    id          TEXT PRIMARY KEY,           -- uuid string (new_id())
    uid         TEXT NOT NULL,              -- Firebase UID of the requesting customer
    area        TEXT DEFAULT '',            -- reverse-geocoded area label (context only)
    lat         DOUBLE PRECISION,           -- the spot the customer wanted served
    lng         DOUBLE PRECISION,
    notified    BOOLEAN DEFAULT false,      -- set true once we ping them a store went live
    created_at  BIGINT DEFAULT 0,           -- epoch ms (last request)
    -- One active request per (customer, area): re-tapping refreshes the row
    -- instead of piling up duplicates.
    UNIQUE (uid, area)
);

CREATE INDEX IF NOT EXISTS idx_waitlist_area     ON coming_soon_waitlist(area);
CREATE INDEX IF NOT EXISTS idx_waitlist_notified ON coming_soon_waitlist(notified);
