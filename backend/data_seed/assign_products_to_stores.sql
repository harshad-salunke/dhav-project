-- ============================================================================
-- DHAV — Assign products to a store  (run in the Supabase SQL editor)
-- ============================================================================
-- WHY: the customer app shows products based on the NEARBY stores. It asks the
-- backend for the union of every nearby store's `available_item_ids`
-- (backend/routers/catalog.py -> /items/nearby). So a shop only "has" a product
-- if that product's catalog id is listed in stores.available_item_ids.
--
--   stores.available_item_ids = JSONB array of catalog_items.id  -> what it stocks
--   stores.inventory          = JSONB { item_id: {quantity, is_available} }
--
-- If available_item_ids is empty, the app can't tell what the shop carries and
-- falls back to the whole catalog. This file fills specific shops so you can
-- test per-shop inventory.
--
-- The catalog + 8 demo stores already exist (migrations/005_seed_marketplace.sql).
-- Catalog item ids look like  'itm_grocery_..._1_kg_0'  and store ids look like
-- 'store_grocery_dhav_supermart'. Use STEP 1 + STEP 2 below to read real ids,
-- then run STEP 3 (pick ids by hand) or STEP 4 (auto-fill) to assign them.
-- Everything here is re-runnable; it only UPDATEs two columns on one store.
-- ============================================================================


-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 1 — find the store you want to stock (copy its id)
-- ─────────────────────────────────────────────────────────────────────────────
SELECT id,
       COALESCE(shop_name, name) AS store_name,
       COALESCE(store_type,'grocery') AS marketplace,
       area,
       COALESCE(jsonb_array_length(available_item_ids), 0) AS current_item_count
FROM stores
WHERE COALESCE(deleted_at, 0) = 0
ORDER BY store_type, store_name;
-- Demo store ids you already have:
--   store_grocery_dhav_supermart      store_grocery_daily_needs_kirana
--   store_fruits_dhav_fresh_fruits    store_fruits_green_basket
--   store_electronics_dhav_electronics_hub   store_electronics_gadget_world
--   store_pharmacy_dhav_pharmacy      store_pharmacy_healthplus_medical


-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 2 — list catalog ids for that store's marketplace (copy the ids you want)
--          Change 'grocery' to fruits / electronics / pharmacy as needed.
-- ─────────────────────────────────────────────────────────────────────────────
SELECT id, name, category, unit, price
FROM catalog_items
WHERE is_active = true
  AND COALESCE(marketplace_type,'grocery') = 'grocery'
ORDER BY category, name
LIMIT 100;


-- ═════════════════════════════════════════════════════════════════════════════
-- STEP 3 — MANUAL: paste the ids you picked and assign them to ONE store.
--   • Edit the store id in WHERE.
--   • Edit the ids array (v.ids). `inventory` is derived from the same array,
--     so the two columns always stay in sync.
-- ═════════════════════════════════════════════════════════════════════════════
UPDATE stores AS s
SET available_item_ids = v.ids,
    inventory = (
        SELECT COALESCE(
                 jsonb_object_agg(elem, jsonb_build_object('quantity', 25, 'is_available', true)),
                 '{}'::jsonb)
        FROM jsonb_array_elements_text(v.ids) AS elem
    ),
    updated_at = (extract(epoch FROM now()) * 1000)::bigint
FROM (
    SELECT '[
        "itm_grocery_vegetables_fruits_onion_farm_fresh_0_0_1_kg_0",
        "itm_grocery_vegetables_fruits_potato_farm_fresh_1_0_1_kg_0",
        "itm_grocery_vegetables_fruits_tomato_farm_fresh_2_0_1_kg_0"
    ]'::jsonb AS ids
) AS v
WHERE s.id = 'store_grocery_dhav_supermart';   -- <-- change to your store id


-- ═════════════════════════════════════════════════════════════════════════════
-- STEP 4 — AUTO (easy): fill a store with N items of its OWN marketplace,
--          no copy-pasting ids. Just set the store id and the LIMIT.
--          Run it again per store (use a DIFFERENT id each time).
-- ═════════════════════════════════════════════════════════════════════════════
WITH tgt AS (
    SELECT id, COALESCE(store_type,'grocery') AS mt
    FROM stores
    WHERE id = 'store_grocery_daily_needs_kirana'   -- <-- change to your store id
),
picked AS (
    SELECT c.id
    FROM catalog_items c, tgt
    WHERE c.is_active = true
      AND COALESCE(c.marketplace_type,'grocery') = tgt.mt
    ORDER BY c.id          -- swap to `ORDER BY random()` for a random mix
    LIMIT 25               -- <-- how many products this shop stocks
)
UPDATE stores AS s
SET available_item_ids = (SELECT COALESCE(jsonb_agg(id), '[]'::jsonb) FROM picked),
    inventory = (
        SELECT COALESCE(
                 jsonb_object_agg(id, jsonb_build_object('quantity', 25, 'is_available', true)),
                 '{}'::jsonb)
        FROM picked
    ),
    updated_at = (extract(epoch FROM now()) * 1000)::bigint
WHERE s.id = (SELECT id FROM tgt);


-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 5 — verify what a store now stocks
-- ─────────────────────────────────────────────────────────────────────────────
SELECT s.id,
       COALESCE(s.shop_name, s.name) AS store_name,
       jsonb_array_length(s.available_item_ids) AS item_count,
       (SELECT string_agg(c.name, ', ')
        FROM catalog_items c
        WHERE c.id IN (SELECT jsonb_array_elements_text(s.available_item_ids))) AS items
FROM stores s
WHERE s.id IN ('store_grocery_dhav_supermart', 'store_grocery_daily_needs_kirana');

-- NOTE: the backend caches store rows for a short TTL (services/cache.py).
-- After running, wait a few minutes or restart the backend before the customer
-- app reflects the new inventory.
-- ============================================================================
