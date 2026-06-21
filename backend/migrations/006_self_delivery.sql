-- DHAV: Store self-delivery flag
-- Run once in: Supabase Dashboard → SQL Editor → New Query → Run
-- Additive + non-destructive. Lets a store declare it delivers its own orders
-- (the owner rides + shares live GPS) instead of assigning a delivery partner.
-- Existing stores default to false (= use delivery partners, unchanged behaviour).

ALTER TABLE stores
    ADD COLUMN IF NOT EXISTS self_delivery BOOLEAN DEFAULT false;

UPDATE stores SET self_delivery = false WHERE self_delivery IS NULL;
