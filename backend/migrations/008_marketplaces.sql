-- ============================================================================
-- DHAV — 008: admin-configurable marketplaces (verticals).
-- Makes the top-level marketplaces (DHAV / Fresh Fruits / Electronics / Pharmacy)
-- DB-driven: the admin can rename them, change colours/emoji, reorder, enable/
-- disable, or add new verticals — and the customer app picks it up.
-- Run once in Supabase. Additive + safe to re-run. Folded into 000_full_schema.sql.
-- ============================================================================

CREATE TABLE IF NOT EXISTS marketplaces (
    wire                TEXT PRIMARY KEY,          -- marketplace_type value (grocery|fruits|...)
    name                TEXT NOT NULL,             -- display name ("Fresh Fruits")
    tab_label           TEXT DEFAULT '',           -- short tab label (defaults to name)
    emoji               TEXT DEFAULT '🛍️',
    color_primary       TEXT DEFAULT '',           -- hex "#1E88E5"
    color_primary_dark  TEXT DEFAULT '',
    color_accent        TEXT DEFAULT '',
    color_header_top    TEXT DEFAULT '',
    color_header_bottom TEXT DEFAULT '',
    color_tint          TEXT DEFAULT '',
    sort_order          INT  DEFAULT 0,
    is_enabled          BOOLEAN DEFAULT true,
    created_at          BIGINT DEFAULT 0,
    updated_at          BIGINT
);

CREATE INDEX IF NOT EXISTS idx_marketplaces_order ON marketplaces(sort_order);

-- Seed the original 4 verticals with their current colours (idempotent).
INSERT INTO marketplaces
    (wire, name, tab_label, emoji,
     color_primary, color_primary_dark, color_accent,
     color_header_top, color_header_bottom, color_tint,
     sort_order, is_enabled, created_at, updated_at) VALUES
('grocery','DHAV','DHAV','🛍️',
 '#1E88E5','#1565C0','#42A5F5','#2196F3','#1565C0','#E3F2FD',0,true,1718900000000,1718900000000),
('fruits','Fresh Fruits','Fresh Fruits','🍉',
 '#2E7D32','#1B5E20','#43A047','#43A047','#2E7D32','#E8F5E9',1,true,1718900000000,1718900000000),
('electronics','Electronics','Electronics','🎧',
 '#1A237E','#0D1551','#3949AB','#3949AB','#1A237E','#E8EAF6',2,true,1718900000000,1718900000000),
('pharmacy','Pharmacy','Pharmacy','💊',
 '#00897B','#00695C','#00ACC1','#00ACC1','#00897B','#E0F2F1',3,true,1718900000000,1718900000000)
ON CONFLICT (wire) DO NOTHING;
