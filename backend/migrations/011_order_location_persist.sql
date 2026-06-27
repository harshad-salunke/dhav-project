-- 011_order_location_persist.sql
-- Live-tracking durability: periodically checkpoint the delivery rider's GPS to
-- the order row so a customer who opens/reopens tracking is seeded with the
-- last-known position immediately (no blank map), and so the position survives a
-- worker restart / works across workers. The live WebSocket fan-out stays the
-- real-time path; these columns are a ~15 s throttled checkpoint.
--
-- Safe to run on an existing DB (idempotent). Already folded into 000_full_schema.sql.

ALTER TABLE orders ADD COLUMN IF NOT EXISTS last_lat         DOUBLE PRECISION;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS last_lng         DOUBLE PRECISION;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS last_location_at TIMESTAMPTZ;
