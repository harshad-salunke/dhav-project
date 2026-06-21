-- DHAV: Multi-category marketplace taxonomy
-- Run once in: Supabase Dashboard → SQL Editor → New Query → Run
-- Additive + non-destructive. Converts DHAV from single-grocery to a 4-marketplace platform:
--   marketplace_type ∈ ('grocery', 'fruits', 'electronics', 'pharmacy')
-- All existing stores/catalog/orders are backfilled to 'grocery'.

-- ── catalog_items: marketplace + rich product fields ─────────────────────────
ALTER TABLE catalog_items
    ADD COLUMN IF NOT EXISTS marketplace_type TEXT    DEFAULT 'grocery',
    ADD COLUMN IF NOT EXISTS category_id      TEXT,            -- FK → categories.id
    ADD COLUMN IF NOT EXISTS subcategory_id   TEXT,            -- FK → subcategories.id
    ADD COLUMN IF NOT EXISTS brand            TEXT    DEFAULT '',
    ADD COLUMN IF NOT EXISTS sku              TEXT    DEFAULT '',
    ADD COLUMN IF NOT EXISTS description      TEXT    DEFAULT '',
    ADD COLUMN IF NOT EXISTS mrp              FLOAT   DEFAULT 0,    -- struck-through MRP
    ADD COLUMN IF NOT EXISTS discount_percent FLOAT   DEFAULT 0,    -- % OFF
    ADD COLUMN IF NOT EXISTS stock_quantity   INT     DEFAULT 0,
    ADD COLUMN IF NOT EXISTS images           JSONB   DEFAULT '[]', -- 3-5 image URLs (carousel)
    ADD COLUMN IF NOT EXISTS specs            JSONB   DEFAULT '{}'; -- key→value: RAM/Storage/Battery/Warranty (electronics), nutrition/healthcare (fruits/pharmacy)

CREATE INDEX IF NOT EXISTS idx_catalog_marketplace ON catalog_items(marketplace_type);
CREATE INDEX IF NOT EXISTS idx_catalog_category_id ON catalog_items(category_id);
CREATE INDEX IF NOT EXISTS idx_catalog_subcategory ON catalog_items(subcategory_id);

UPDATE catalog_items SET marketplace_type = 'grocery' WHERE marketplace_type IS NULL;

-- ── stores: store_type (mandatory on register) ───────────────────────────────
ALTER TABLE stores
    ADD COLUMN IF NOT EXISTS store_type TEXT DEFAULT 'grocery';

CREATE INDEX IF NOT EXISTS idx_stores_type ON stores(store_type);
UPDATE stores SET store_type = 'grocery' WHERE store_type IS NULL;

-- ── orders: marketplace_type (drives type-correct broadcast routing) ─────────
ALTER TABLE orders
    ADD COLUMN IF NOT EXISTS marketplace_type TEXT DEFAULT 'grocery';

UPDATE orders SET marketplace_type = 'grocery' WHERE marketplace_type IS NULL;

-- ── categories (admin-managed, DB-driven — replaces derived category strings) ─
CREATE TABLE IF NOT EXISTS categories (
    id               TEXT PRIMARY KEY,
    marketplace_type TEXT NOT NULL DEFAULT 'grocery',
    name             TEXT NOT NULL,
    image_url        TEXT DEFAULT '',
    sort_order       INT  DEFAULT 0,
    is_enabled       BOOLEAN DEFAULT true,
    created_at       BIGINT DEFAULT 0,
    updated_at       BIGINT
);

CREATE INDEX IF NOT EXISTS idx_categories_market ON categories(marketplace_type, sort_order);
CREATE INDEX IF NOT EXISTS idx_categories_enabled ON categories(is_enabled);

-- ── subcategories (admin-managed, parent = categories.id) ────────────────────
CREATE TABLE IF NOT EXISTS subcategories (
    id               TEXT PRIMARY KEY,
    category_id      TEXT NOT NULL,
    marketplace_type TEXT NOT NULL DEFAULT 'grocery',
    name             TEXT NOT NULL,
    image_url        TEXT DEFAULT '',
    sort_order       INT  DEFAULT 0,
    is_enabled       BOOLEAN DEFAULT true,
    created_at       BIGINT DEFAULT 0,
    updated_at       BIGINT
);

CREATE INDEX IF NOT EXISTS idx_subcategories_cat    ON subcategories(category_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_subcategories_market ON subcategories(marketplace_type);
CREATE INDEX IF NOT EXISTS idx_subcategories_enabled ON subcategories(is_enabled);
