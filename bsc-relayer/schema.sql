-- ANET BSC→L1 relayer state.
--
-- Two-table design:
--   1. `swaps` — every SwapRequested event we've seen, with its lifecycle.
--      The (tx_hash, log_index) PK guarantees we never process the same
--      event twice even across worker restarts / parallel workers / RPC
--      replays.
--   2. `cursor` — a single-row table tracking the last fully-scanned BSC
--      block so restarts don't re-scan from genesis.
--
-- Everything lives in a dedicated `relayer` schema so it can safely
-- coexist with the L1 chain's tables in a shared database.

CREATE SCHEMA IF NOT EXISTS relayer;
SET search_path TO relayer, public;

CREATE TABLE IF NOT EXISTS relayer.swaps (
    tx_hash         TEXT        NOT NULL,
    log_index       INTEGER     NOT NULL,
    block_number    BIGINT      NOT NULL,
    swap_id         BIGINT      NOT NULL,
    evm_sender      TEXT        NOT NULL,
    anet_recipient  TEXT        NOT NULL,
    token_address   TEXT        NOT NULL,
    token_symbol    TEXT        NOT NULL,
    gross_amount    NUMERIC(78) NOT NULL,    -- raw wei
    net_amount      NUMERIC(78) NOT NULL,    -- wei after fee
    fee_paid        NUMERIC(78) NOT NULL,    -- wei
    bsc_timestamp   TIMESTAMPTZ NOT NULL,
    -- Lifecycle:
    --   detected → confirmed (12+ blocks deep) → minted | skipped | failed
    status          TEXT        NOT NULL DEFAULT 'detected',
    anet_ants_minted NUMERIC(78),
    l1_tx_id        TEXT,
    error           TEXT,
    detected_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    minted_at       TIMESTAMPTZ,
    PRIMARY KEY (tx_hash, log_index)
);

CREATE INDEX IF NOT EXISTS idx_swaps_status    ON relayer.swaps (status);
CREATE INDEX IF NOT EXISTS idx_swaps_block     ON relayer.swaps (block_number);
CREATE INDEX IF NOT EXISTS idx_swaps_recipient ON relayer.swaps (anet_recipient);
CREATE INDEX IF NOT EXISTS idx_swaps_minted_at ON relayer.swaps (minted_at);

CREATE TABLE IF NOT EXISTS relayer.cursor (
    id              INTEGER     PRIMARY KEY DEFAULT 1,
    last_scanned    BIGINT      NOT NULL,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (id = 1)
);

-- ─────────────────────────────────────────────────────────────────────────
-- L1 → BSC bridge (burn-and-release)
--
-- The relayer polls the L1 chain's /bridge/burns endpoint for new burns
-- (the L1 is the source of truth — it has already debited the user's
-- ANET balance when a row appears there). For each L1 burn we:
--   1. Insert a row in `relayer.burns` with status='detected'
--   2. Send the equivalent wANET on BSC from the escrow wallet
--   3. POST /bridge/burns/:id/released back to the L1 with the BSC tx hash
--   4. Update our row to status='released'
--
-- (burn_id) is the PK because it is globally unique on the L1 side and
-- already serves as our idempotency key.
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS relayer.burns (
    burn_id         BIGINT      PRIMARY KEY,         -- from L1 bridge_burns.burn_id
    l1_sender       TEXT        NOT NULL,
    bsc_recipient   TEXT        NOT NULL,
    ants            NUMERIC(78) NOT NULL,
    token_symbol    TEXT        NOT NULL,            -- "ANET" (only supported for now)
    -- Lifecycle: detected → sending → released | skipped | failed
    status          TEXT        NOT NULL DEFAULT 'detected',
    bsc_tx_hash     TEXT,
    bsc_amount_wei  NUMERIC(78),                     -- amount actually transferred on BSC
    error           TEXT,
    detected_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    released_at     TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_burns_status   ON relayer.burns (status);
CREATE INDEX IF NOT EXISTS idx_burns_released ON relayer.burns (released_at);

-- Cursor for the L1 burn poller: largest burn_id we've ingested so far.
CREATE TABLE IF NOT EXISTS relayer.burn_cursor (
    id              INTEGER     PRIMARY KEY DEFAULT 1,
    last_burn_id    BIGINT      NOT NULL,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (id = 1)
);

