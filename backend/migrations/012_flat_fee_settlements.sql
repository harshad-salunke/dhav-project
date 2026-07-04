-- ============================================================================
-- 012_flat_fee_settlements.sql — flat ₹10 platform fee + reliable settlements
-- ----------------------------------------------------------------------------
-- Business change: the platform fee is now a FLAT ₹10 per order (was 5% of the
-- product total). The customer pays it at checkout (visible bill line); the
-- store collects it via COD and owes it to DHAV in the weekly settlement.
--
-- Settlement fix: the weekly sweep now tags each delivered order with the
-- settlement it was swept into (orders.settlement_id). Untagged delivered
-- orders are "unsettled" — the sweep picks them up no matter how old they are,
-- which fixes the old current-week-only window that produced ₹0 settlements.
--
-- Idempotent / re-runnable. Apply in the Supabase SQL editor.
-- Folded into 000_full_schema.sql (rule: every migration also lands there).
-- ============================================================================

-- Which settlement swept this delivered order (NULL = not yet settled).
ALTER TABLE orders ADD COLUMN IF NOT EXISTS settlement_id TEXT;

-- Fast "what does this store still owe" lookups for the sweep + live views.
CREATE INDEX IF NOT EXISTS idx_orders_unsettled
    ON orders (accepted_by_store_id)
    WHERE status = 'delivered' AND settlement_id IS NULL;

-- Backfill: old delivered orders (incl. seeds) sometimes have no delivered_at;
-- the sweep needs it to place them in a week. Use created_at as best effort.
UPDATE orders SET delivered_at = created_at
 WHERE status = 'delivered' AND (delivered_at IS NULL OR delivered_at = 0);
