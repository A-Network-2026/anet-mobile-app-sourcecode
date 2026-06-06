import 'dotenv/config';

function required(name) {
  const v = process.env[name];
  if (!v || v.trim() === '') {
    throw new Error(`Missing required env var: ${name}`);
  }
  return v.trim();
}

function optional(name, fallback) {
  const v = process.env[name];
  return v && v.trim() !== '' ? v.trim() : fallback;
}

function intEnv(name, fallback) {
  const v = process.env[name];
  if (!v) return fallback;
  const n = parseInt(v, 10);
  if (Number.isNaN(n)) throw new Error(`Invalid integer env var ${name}=${v}`);
  return n;
}

function boolEnv(name, fallback) {
  const v = (process.env[name] || '').trim().toLowerCase();
  if (v === '') return fallback;
  return v === '1' || v === 'true' || v === 'yes' || v === 'on';
}

export const config = {
  // BSC
  bscRpcUrl: required('BSC_RPC_URL'),
  bscRpcUrlFallback: optional('BSC_RPC_URL_FALLBACK', null),
  anetSwapContract: required('ANET_SWAP_CONTRACT'),
  minConfirmations: intEnv('MIN_CONFIRMATIONS', 12),
  scanChunkBlocks: intEnv('SCAN_CHUNK_BLOCKS', 2000),
  startBlock: intEnv('START_BLOCK', 99500000),
  pollIntervalMs: intEnv('POLL_INTERVAL_MS', 5000),
  // L1
  anetL1BaseUrl: required('ANET_L1_BASE_URL'),
  anetDexAdminKey: required('ANET_DEX_ADMIN_KEY'),
  // Safety — BSC → L1 (mint side)
  maxMintPerTxAnet: intEnv('MAX_MINT_PER_TX_ANET', 10000),
  maxMintPerDayAnet: intEnv('MAX_MINT_PER_DAY_ANET', 100000),
  dryRun: boolEnv('DRY_RUN', false),
  // Inbound bridge token allowlist. The L1 DEX only has an ANET-USDC pool
  // (bootstrap: 10 ANET / 10000 USDC), so USDC is the ONLY token we can quote
  // and credit. Any other deposited token (USDT, BUSD, DAI, WBNB, …) has no
  // pool — quoting it would fail and the funds would sit stuck in the swap
  // contract. We flag those for refund instead of silently failing forever.
  // Comma-separated symbols; case-insensitive. Override to widen once more
  // L1 pools exist.
  supportedBridgeTokens: new Set(
    optional('SUPPORTED_BRIDGE_TOKENS', 'USDC')
      .split(',')
      .map((s) => s.trim().toUpperCase())
      .filter(Boolean),
  ),

  // ── L1 → BSC bridge (burn-and-release) ────────────────────────────────
  // Master switch — when false the burn poller does not start at all.
  bridgeBurnEnabled: boolEnv('BRIDGE_BURN_ENABLED', false),
  // How often to poll the L1 for new pending burns.
  // Phase 0 bridge-latency tune (2026-05-26): default lowered from 8000 → 1500.
  // Phase 1 instant-swap tune (2026-05-26): default lowered 1500 → 500 so a
  // burn-submit → BSC-release round-trip stays under ~5s end-to-end when
  // paired with the L1 long-poll `wait_ms` API. L1 burn endpoint is cheap;
  // faster polling cuts user-visible latency without changing the trust model.
  // Operators can override via env.
  burnPollIntervalMs: intEnv('L1_BURN_POLL_INTERVAL_MS', 500),
  // ERC-20 token contract on BSC that the escrow holds and transfers
  // to bridge users (default: production ANET BEP-20 token).
  bscAnetToken: optional(
    'BSC_ANET_TOKEN',
    '0x791055A7d52AA392eaE8De04250497f33807E46A',
  ),
  // Decimals of the BSC release token (standard ERC-20 ANET = 18).
  bscAnetDecimals: intEnv('BSC_ANET_DECIMALS', 18),
  // Private key of the BSC escrow wallet (HOLDS THE INVENTORY).
  // Only required when BRIDGE_BURN_ENABLED=true.
  bscEscrowPrivateKey: optional('BSC_ESCROW_PRIVATE_KEY', null),
  // Per-burn cap & daily cap, in whole ANET.
  maxReleasePerTxAnet: intEnv('MAX_RELEASE_PER_TX_ANET', 10000),
  maxReleasePerDayAnet: intEnv('MAX_RELEASE_PER_DAY_ANET', 100000),
  // Same DRY_RUN flag also gates the BSC sender for symmetry.

  // ── Release mode: `legacy_eoa` (hot escrow `transfer`) or `vault` ────
  // (AnetBridgeVault on BSC, M-of-N EIP-712 signed releases).
  bridgeReleaseMode: optional('BRIDGE_RELEASE_MODE', 'legacy_eoa'),
  vaultAddress:        optional('VAULT_ADDRESS', null),
  vaultChainId:        intEnv('VAULT_CHAIN_ID', 56),
  // Submitter wallet — pays gas to call vault.releaseBurn(). Holds no signer power.
  vaultSubmitterKey:   optional('VAULT_SUBMITTER_KEY', null),
  // Transitional single-process multi-key signing (canary only).
  // Comma-separated private keys; each MUST be in the vault's on-chain signer set.
  vaultLocalSignerKeys: optional('VAULT_LOCAL_SIGNER_KEYS', null),
  // Release signature deadline, in seconds from now.
  vaultReleaseDeadlineSecs: intEnv('VAULT_RELEASE_DEADLINE_SECS', 3600),
  // Source for the M-of-N release signatures:
  //   'local' (default) — sign in-process from VAULT_LOCAL_SIGNER_KEYS. Canary only.
  //   'l1'              — fetch out-of-band signatures from the L1 chain
  //                       (POST'd by independent anet-vault-signer daemons).
  //                       Bitcoin-principle production posture: relayer has NO signing power.
  vaultSigSource: optional('VAULT_SIG_SOURCE', 'local'),

  // Storage
  databaseUrl: required('DATABASE_URL'),
  // Misc
  logLevel: optional('LOG_LEVEL', 'info'),
};

// Strict validation for burn side — only enforce when enabled so the
// existing BSC → L1 worker keeps running without these vars.
if (config.bridgeBurnEnabled && config.bridgeReleaseMode === 'legacy_eoa' && !config.bscEscrowPrivateKey) {
  throw new Error(
    'BRIDGE_BURN_ENABLED=true with BRIDGE_RELEASE_MODE=legacy_eoa requires BSC_ESCROW_PRIVATE_KEY',
  );
}
if (config.bridgeBurnEnabled && config.bridgeReleaseMode === 'vault') {
  if (!config.vaultAddress) {
    throw new Error('BRIDGE_RELEASE_MODE=vault requires VAULT_ADDRESS');
  }
  if (!config.vaultSubmitterKey) {
    throw new Error('BRIDGE_RELEASE_MODE=vault requires VAULT_SUBMITTER_KEY');
  }
  const src = (config.vaultSigSource || '').toLowerCase();
  if (src !== 'local' && src !== 'l1') {
    throw new Error(
      `VAULT_SIG_SOURCE='${config.vaultSigSource}' invalid (expected 'local' or 'l1')`,
    );
  }
  if (src === 'l1' && config.vaultLocalSignerKeys) {
    throw new Error(
      'VAULT_SIG_SOURCE=l1 is mutually exclusive with VAULT_LOCAL_SIGNER_KEYS — unset one.',
    );
  }
  config.vaultSigSource = src;
}
if (
  config.bridgeBurnEnabled &&
  config.bridgeReleaseMode !== 'legacy_eoa' &&
  config.bridgeReleaseMode !== 'vault'
) {
  throw new Error(
    `Invalid BRIDGE_RELEASE_MODE='${config.bridgeReleaseMode}' (expected 'legacy_eoa' or 'vault')`,
  );
}
