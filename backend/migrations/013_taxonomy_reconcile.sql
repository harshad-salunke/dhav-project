-- ============================================================================
-- 013_taxonomy_reconcile.sql — one taxonomy, no duplicates, no orphan products
-- ----------------------------------------------------------------------------
-- catalog_items historically carried BOTH a free-text `category` label and a
-- proper `category_id` FK. Old/admin-created rows sometimes have only the
-- text. This migration:
--   1. guards against duplicate category/subcategory names per marketplace
--      (case-insensitive), so admin CRUD can't create "oil" next to "Oil";
--   2. back-fills `category_id` (and `subcategory_id` where derivable) by
--      matching the legacy text label to the categories table.
-- The text `category` column stays as a denormalized display label for now —
-- every surface still reads it — but category_id is the source of truth.
--
-- Idempotent / re-runnable. Apply in the Supabase SQL editor.
-- Folded into 000_full_schema.sql (indexes) per the migration rule.
-- ============================================================================

-- 1) No two categories with the same name in one marketplace.
CREATE UNIQUE INDEX IF NOT EXISTS uq_categories_market_name
    ON categories (marketplace_type, lower(name));

-- Subcategory names must be unique within their parent category.
CREATE UNIQUE INDEX IF NOT EXISTS uq_subcategories_cat_name
    ON subcategories (category_id, lower(name));

-- 2) Back-fill category_id from the legacy text label.
UPDATE catalog_items ci
   SET category_id = c.id
  FROM categories c
 WHERE (ci.category_id IS NULL OR ci.category_id = '')
   AND lower(ci.category) = lower(c.name)
   AND COALESCE(ci.marketplace_type, 'grocery') = c.marketplace_type;

-- Back-fill subcategory_id only when the category has exactly ONE subcategory
-- (unambiguous); anything else needs a human (admin catalog screen).
UPDATE catalog_items ci
   SET subcategory_id = s.id
  FROM (
    SELECT category_id, MIN(id) AS id
      FROM subcategories
     GROUP BY category_id
    HAVING COUNT(*) = 1
  ) s
 WHERE (ci.subcategory_id IS NULL OR ci.subcategory_id = '')
   AND ci.category_id = s.category_id;

-- Report leftovers (run manually to see what still needs admin attention):
-- SELECT id, name, category, marketplace_type FROM catalog_items
--  WHERE is_active AND (category_id IS NULL OR category_id = '');
