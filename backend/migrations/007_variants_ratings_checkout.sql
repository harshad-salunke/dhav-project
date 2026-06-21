-- ============================================================================
-- DHAV — 007: product variants (group_id), product ratings, checkout fields,
--             and the customer wishlist.
-- Run once in: Supabase Dashboard → SQL Editor → New Query → Run.
-- Additive + non-destructive + safe to re-run.
-- ============================================================================

-- ── catalog_items: variant family + product rating ──────────────────────────
-- group_id ties unit-variants of the SAME product (10kg / 5kg / 1kg) together,
-- so the detail screen's "Select Unit" chips can list siblings. NULL = standalone.
ALTER TABLE catalog_items
    ADD COLUMN IF NOT EXISTS group_id     TEXT,
    ADD COLUMN IF NOT EXISTS rating       FLOAT DEFAULT 0,   -- avg product rating
    ADD COLUMN IF NOT EXISTS rating_count INT   DEFAULT 0;   -- number of ratings

CREATE INDEX IF NOT EXISTS idx_catalog_group ON catalog_items(group_id);

-- Demo ratings so the redesigned cards/detail show stars immediately. Only fills
-- rows that have no rating yet — real ratings (from the rate-order flow) override.
-- Deterministic-ish via random(); safe on re-run (guarded by rating = 0).
UPDATE catalog_items
   SET rating       = ROUND((3.7 + random() * 1.2)::numeric, 1),
       rating_count = (40 + floor(random() * 4000))::int
 WHERE (rating IS NULL OR rating = 0)
   AND is_active = true;

-- ── orders: checkout extras (GSTIN / donation / delivery instructions / handling)
ALTER TABLE orders
    ADD COLUMN IF NOT EXISTS gstin                 TEXT  DEFAULT '',
    ADD COLUMN IF NOT EXISTS donation_amount       FLOAT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS handling_charge       FLOAT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS delivery_instructions JSONB DEFAULT '[]';

-- ── wishlist (saved-for-later, per customer) ─────────────────────────────────
CREATE TABLE IF NOT EXISTS wishlist (
    uid        TEXT NOT NULL,            -- Firebase UID of the customer
    item_id    TEXT NOT NULL,            -- catalog_items.id
    created_at BIGINT DEFAULT 0,         -- epoch ms
    PRIMARY KEY (uid, item_id)
);

CREATE INDEX IF NOT EXISTS idx_wishlist_uid ON wishlist(uid);

-- ============================================================================
-- NOTE on variants: group_id is added + indexed here but NOT back-filled — the
-- seed (scripts/build_seed.py / 005_*) must emit the same group_id for each
-- unit-family for the "Select Unit" chips to populate. Until then products show
-- a single unit (graceful). See migrations/README.md.
-- ============================================================================
