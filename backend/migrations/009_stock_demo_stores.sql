-- ============================================================================
-- DHAV migration 009 — Stock the 8 demo stores with products (one-shot)
-- ============================================================================
-- WHY: the customer app shows products for the NEARBY stores by taking the union
-- of each nearby store's `available_item_ids` (backend/routers/catalog.py ->
-- /items/nearby). The demo stores from 005_seed_marketplace.sql DO get stocked
-- by that seed, but if you onboarded stores yourself — or want a clean, testable
-- assignment — this migration (re)fills EVERY demo store (id starting 'store_')
-- with products of its OWN marketplace, in one run. No id-copying needed.
--
-- DESIGN: the two demo stores of the same marketplace get DIFFERENT but
-- OVERLAPPING product sets (a 40-item window, shifted 20 per store -> ~50% shared)
-- so you can verify the "union of nearby stores" behaviour: some items are unique
-- to shop A, some to shop B, some shared.
--
--   stores.available_item_ids = JSONB array of catalog_items.id   (what it stocks)
--   stores.inventory          = JSONB { item_id: {quantity, is_available} }
-- Both are written together so the customer app AND the store/admin inventory
-- screens stay consistent.
--
-- PREREQ: run 005_seed_marketplace.sql first (it creates the demo stores + items).
-- SAFE:   only UPDATEs demo stores (id LIKE 'store_%'); your admin-onboarded
--         stores (random UUID ids) are never touched. Re-runnable.
-- ============================================================================

WITH demo_stores AS (
    -- rank the demo stores within each marketplace: 0 = first shop, 1 = second
    SELECT id,
           COALESCE(store_type, 'grocery') AS mt,
           row_number() OVER (PARTITION BY COALESCE(store_type, 'grocery')
                              ORDER BY id) - 1 AS store_rank
    FROM stores
    WHERE starts_with(id, 'store_')
      AND COALESCE(deleted_at, 0) = 0
),
ranked_items AS (
    -- number the catalog items within each marketplace so we can window them
    SELECT id,
           COALESCE(marketplace_type, 'grocery') AS mt,
           row_number() OVER (PARTITION BY COALESCE(marketplace_type, 'grocery')
                              ORDER BY id) AS rn
    FROM catalog_items
    WHERE is_active = true
),
assignment AS (
    -- each store takes a 40-item window of its marketplace, offset by its rank
    SELECT ds.id AS store_id, ri.id AS item_id
    FROM demo_stores ds
    JOIN ranked_items ri ON ri.mt = ds.mt
    WHERE ri.rn >  ds.store_rank * 20
      AND ri.rn <= ds.store_rank * 20 + 40
),
agg AS (
    SELECT store_id,
           jsonb_agg(item_id ORDER BY item_id) AS ids,
           jsonb_object_agg(item_id,
               jsonb_build_object('quantity', 25, 'is_available', true)) AS inv
    FROM assignment
    GROUP BY store_id
)
UPDATE stores s
SET available_item_ids = agg.ids,
    inventory          = agg.inv,
    updated_at         = (extract(epoch FROM now()) * 1000)::bigint
FROM agg
WHERE s.id = agg.store_id;


-- ── verify: how many products each demo store now stocks ────────────────────
SELECT id,
       COALESCE(shop_name, name) AS store_name,
       COALESCE(store_type, 'grocery') AS marketplace,
       area,
       jsonb_array_length(available_item_ids) AS item_count
FROM stores
WHERE starts_with(id, 'store_')
ORDER BY store_type, id;
-- ============================================================================
