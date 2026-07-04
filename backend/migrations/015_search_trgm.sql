-- ============================================================================
-- 015_search_trgm.sql — real product search (typo-tolerant, ranked)
-- ----------------------------------------------------------------------------
-- The customer app's search used to substring-filter whatever catalog slice it
-- had in memory — no typo tolerance, no ranking. GET /catalog/search now runs
-- in Postgres using the pg_trgm extension (trigram similarity: "mlik" still
-- finds "Milk"), so it needs these indexes to stay fast as the catalog grows.
--
-- pg_trgm ships with Supabase — CREATE EXTENSION just enables it.
--
-- Idempotent / re-runnable. Apply in the Supabase SQL editor.
-- Folded into 000_full_schema.sql per the migration rule.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_catalog_name_trgm
    ON catalog_items USING gin (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_catalog_brand_trgm
    ON catalog_items USING gin (brand gin_trgm_ops);
