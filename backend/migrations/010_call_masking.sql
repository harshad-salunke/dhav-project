-- ============================================================================
-- 010_call_masking.sql  —  Privacy-preserving call masking (Blinkit/Swiggy style)
-- ----------------------------------------------------------------------------
-- When a deliverer (store owner self-delivering, or an assigned delivery
-- partner) and a customer need to talk, neither side should see the other's
-- real phone number. A cloud-telephony provider (default: Exotel) bridges the
-- two legs through a VIRTUAL NUMBER; both parties only ever see that number.
--
-- This table is the audit log of every masked call we initiate: who started
-- it, for which order, which virtual number bridged it, and (via the provider
-- status callback) how it ended and how long it lasted. We log every call so
-- spend is auditable and delivery disputes ("they never called me") can be
-- checked.
--
-- Idempotent / re-runnable. Apply in the Supabase SQL editor.
-- ============================================================================

CREATE TABLE IF NOT EXISTS call_logs (
    id                TEXT PRIMARY KEY,            -- our uuid
    order_id          TEXT,                        -- the order the call is about
    initiator_uid     TEXT,                        -- who tapped "Call"
    initiator_role    TEXT,                        -- 'customer' | 'store_owner' | 'delivery'
    direction         TEXT,                        -- 'deliverer_to_customer' | 'customer_to_deliverer'
    -- Real numbers are stored so support can audit a disputed delivery. They
    -- are NEVER returned to the apps — masking only hides numbers between the
    -- two callers, not from the platform operator.
    caller_phone      TEXT,                        -- leg A (initiator), rings first
    callee_phone      TEXT,                        -- leg B (the other party)
    virtual_number    TEXT,                        -- the masking number both parties saw
    provider          TEXT DEFAULT 'exotel',       -- which telephony provider bridged it
    provider_call_sid TEXT,                         -- provider's call id (for the status callback)
    status            TEXT DEFAULT 'initiated',    -- initiated|ringing|in-progress|completed|failed|no-answer|busy
    duration_seconds  INT  DEFAULT 0,              -- billed talk time (filled by callback)
    error_detail      TEXT,                         -- provider error message, if any
    created_at        BIGINT DEFAULT 0,            -- epoch ms
    ended_at          BIGINT                        -- epoch ms (filled by callback)
);

CREATE INDEX IF NOT EXISTS idx_call_logs_order     ON call_logs(order_id);
CREATE INDEX IF NOT EXISTS idx_call_logs_initiator ON call_logs(initiator_uid);
CREATE INDEX IF NOT EXISTS idx_call_logs_sid       ON call_logs(provider_call_sid);
