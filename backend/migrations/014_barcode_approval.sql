-- ============================================================================
-- 014_barcode_approval.sql — barcode product onboarding + admin approval loop
-- ----------------------------------------------------------------------------
-- Store owners scan a product barcode → free public APIs prefill the details →
-- the owner completes price/images/category → the request goes to an ADMIN
-- QUEUE → approve publishes it into the global catalog (deduped by barcode)
-- and stocks the submitting store; reject records a reason.
--
--   • catalog_items.barcode  — EAN/UPC; unique when set, so the same physical
--     product can never enter the global catalog twice. A second store scanning
--     a known barcode just adds the existing item to its inventory.
--   • custom_item_requests   — upgraded from a bare "please add X" note into a
--     full submission (images, price/mrp, taxonomy, barcode) with review state.
--
-- Idempotent / re-runnable. Apply in the Supabase SQL editor.
-- Folded into 000_full_schema.sql per the migration rule.
-- ============================================================================

ALTER TABLE catalog_items ADD COLUMN IF NOT EXISTS barcode TEXT DEFAULT '';
CREATE UNIQUE INDEX IF NOT EXISTS uq_catalog_barcode
    ON catalog_items (barcode) WHERE barcode <> '';

ALTER TABLE custom_item_requests
    ADD COLUMN IF NOT EXISTS barcode             TEXT  DEFAULT '',
    ADD COLUMN IF NOT EXISTS brand               TEXT  DEFAULT '',
    ADD COLUMN IF NOT EXISTS description         TEXT  DEFAULT '',
    ADD COLUMN IF NOT EXISTS mrp                 FLOAT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS images              JSONB DEFAULT '[]',  -- store-owner photos (Supabase URLs, ≤3)
    ADD COLUMN IF NOT EXISTS external_image_urls JSONB DEFAULT '[]',  -- barcode-API images; sideloaded on approve
    ADD COLUMN IF NOT EXISTS specs               JSONB DEFAULT '{}',  -- ingredients/allergens/nutrition from the barcode API ({label: value})
    ADD COLUMN IF NOT EXISTS marketplace_type    TEXT  DEFAULT 'grocery',
    ADD COLUMN IF NOT EXISTS category_id         TEXT,
    ADD COLUMN IF NOT EXISTS subcategory_id      TEXT,
    ADD COLUMN IF NOT EXISTS rejection_reason    TEXT  DEFAULT '',
    ADD COLUMN IF NOT EXISTS reviewed_by         TEXT,                -- admin uid
    ADD COLUMN IF NOT EXISTS reviewed_at         BIGINT,
    ADD COLUMN IF NOT EXISTS catalog_item_id     TEXT;                -- set on approve (new or linked item)
