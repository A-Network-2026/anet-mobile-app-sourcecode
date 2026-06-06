const db = require('../db');
const verifyToken = require('../middleware/auth');
const {
  SESSION_GATE_REQUIRED_SESSIONS,
  isSessionGateBypassed,
} = require('../utils/sessionGate');

const ANET_L1_URL = String(process.env.ANET_L1_URL || 'https://anet-private-mainnet.onrender.com')
  .trim()
  .replace(/\/+$/, '');
const FETCH_TIMEOUT_MS = Math.max(Number(process.env.NFT_L1_TIMEOUT_MS || 7000), 1000);

// Gate startup schema sync behind an env flag, matching the pattern used by
// stats.js, mining.js, admin.js, colonyRewards.js, chatbot.js, auth.js.
// In production the schema is already in place, so we default to skipping the
// blocking startup sync — a slow Postgres must NEVER crash the backend.
const RUN_WALLETNFT_SCHEMA_SYNC_STARTUP = String(process.env.RUN_WALLETNFT_SCHEMA_SYNC_STARTUP || 'false').trim().toLowerCase() === 'true';

let walletNftSchemaInitPromise = null;

const SETTLEMENT_TRANSACTION_TYPES = [
  'mining_claim',
  'wallet_transfer_complete',
  'wallet_transfer_confirmed',
  'transfer_complete',
  'transfer_confirmed',
  'swap_complete',
  'swap_confirmed',
  'cashout_complete',
  'cashout_confirmed',
];

function sanitizeText(value, maxLen = 120) {
  return String(value || '')
    .replace(/[\r\n;|<>]+/g, ' ')
    .trim()
    .slice(0, maxLen);
}

function sanitizeStyleValue(value, fallback, maxLen = 48) {
  const cleaned = sanitizeText(value, maxLen).replace(/[^a-zA-Z0-9 _-]/g, '');
  return cleaned || fallback;
}

function normalizeHexColor(value, fallback) {
  const cleaned = String(value || '').trim();
  if (/^#[0-9a-fA-F]{6}$/.test(cleaned) || /^#[0-9a-fA-F]{8}$/.test(cleaned)) {
    return cleaned.toUpperCase();
  }
  return fallback;
}

function toSafeMetadata(value) {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return value;
  }
  return {};
}

function buildAvatarSeed(user, profileName) {
  const wallet = String(user.custom_wallet_address || user.wallet_address || `user-${user.id}`)
    .trim()
    .toUpperCase();
  const name = sanitizeText(profileName || 'A Network Identity', 80);
  return `${wallet}:${name}`;
}

function buildAvatarUrl(seed) {
  return `https://api.dicebear.com/9.x/identicon/svg?seed=${encodeURIComponent(seed)}`;
}

function formatProfile(row) {
  if (!row) {
    return null;
  }

  return {
    id: row.id,
    user_id: row.user_id,
    nft_name: row.nft_name,
    powered_by: row.powered_by,
    primary_color: row.primary_color,
    secondary_color: row.secondary_color,
    glow_color: row.glow_color,
    background_style: row.background_style,
    frame_style: row.frame_style,
    hologram_level: Number(row.hologram_level || 0),
    metadata_json: row.metadata_json || {},
    avatar_image_url: row.avatar_image_url,
    profile_banner_url: row.profile_banner_url,
    nft_card_image_url: row.nft_card_image_url,
    avatar_thumb_url: row.avatar_thumb_url,
    profile_active: Boolean(row.profile_active),
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
}

async function postL1ProfileActivity(payload) {
  if (typeof fetch !== 'function') {
    throw new Error('Global fetch is unavailable in this Node runtime');
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);

  try {
    const response = await fetch(`${ANET_L1_URL}/app/activity`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });

    const result = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(result.error || `L1 activity failed with status ${response.status}`);
    }

    return result;
  } finally {
    clearTimeout(timeout);
  }
}

async function ensureSchema(fastify) {
  if (!walletNftSchemaInitPromise) {
    const promise = (async () => {
      await db.query(`
        CREATE TABLE IF NOT EXISTS user_nft_profiles (
          id BIGSERIAL PRIMARY KEY,
          user_id BIGINT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
          nft_name VARCHAR(120) NOT NULL DEFAULT 'A Network Identity',
          powered_by VARCHAR(120) NOT NULL DEFAULT 'A Network',
          primary_color VARCHAR(32) NOT NULL DEFAULT '#00D2FF',
          secondary_color VARCHAR(32) NOT NULL DEFAULT '#8A3FFC',
          glow_color VARCHAR(32) NOT NULL DEFAULT '#FFFFFF',
          background_style VARCHAR(64) NOT NULL DEFAULT 'cyberpunk',
          frame_style VARCHAR(64) NOT NULL DEFAULT 'chrome',
          hologram_level NUMERIC(4,2) NOT NULL DEFAULT 0.75,
          metadata_json JSONB NOT NULL DEFAULT '{}'::jsonb,
          avatar_image_url TEXT,
          profile_banner_url TEXT,
          nft_card_image_url TEXT,
          avatar_thumb_url TEXT,
          profile_active BOOLEAN NOT NULL DEFAULT TRUE,
          created_at TIMESTAMP NOT NULL DEFAULT NOW(),
          updated_at TIMESTAMP NOT NULL DEFAULT NOW()
        )
      `);
      await db.query('CREATE INDEX IF NOT EXISTS idx_user_nft_profiles_user_active ON user_nft_profiles(user_id, profile_active)');
      await db.query('CREATE INDEX IF NOT EXISTS idx_user_nft_profiles_user_created ON user_nft_profiles(user_id, created_at DESC)');
      await db.query(`
        ALTER TABLE users
        ADD COLUMN IF NOT EXISTS active_nft_profile_id BIGINT
      `);
      await db.query(`
        ALTER TABLE users
        ADD COLUMN IF NOT EXISTS profile_avatar_type VARCHAR(16) NOT NULL DEFAULT 'default'
      `);
      await db.query(`
        ALTER TABLE users
        ADD COLUMN IF NOT EXISTS profile_avatar_url TEXT
      `);
      await db.query(`
        ALTER TABLE users
        ADD COLUMN IF NOT EXISTS nft_activated BOOLEAN NOT NULL DEFAULT FALSE
      `);
      await db.query(`
        ALTER TABLE users
        ADD COLUMN IF NOT EXISTS nft_activated_at TIMESTAMP
      `);
      await db.query(`
        ALTER TABLE users
        ADD COLUMN IF NOT EXISTS first_settlement_at TIMESTAMP
      `);
    })();
    walletNftSchemaInitPromise = promise;

    promise
      .then(() => {
        if (fastify) fastify.log.info('Wallet NFT schema checks completed');
      })
      .catch((err) => {
        if (fastify) fastify.log.error(err, 'Wallet NFT schema checks failed');
        // Reset cache so a future call can retry once Postgres recovers.
        // Without this, a single startup timeout would permanently poison the
        // cached promise and 500 every wallet-NFT request after that.
        if (walletNftSchemaInitPromise === promise) walletNftSchemaInitPromise = null;
      });
  }

  return walletNftSchemaInitPromise;
}

async function loadIdentityState(userId) {
  const userRes = await db.query(
    `SELECT id,
            email,
            successful_sessions,
            wallet_address,
            custom_wallet_address,
            migration_wallet_address,
            referral_code,
            active_nft_profile_id,
            profile_avatar_type,
            profile_avatar_url,
            nft_activated,
            nft_activated_at,
            first_settlement_at
     FROM users
     WHERE id = $1
     LIMIT 1`,
    [userId]
  );

  const user = userRes.rows[0];
  if (!user) {
    return { error: 'User not found', statusCode: 404 };
  }

  let completedSessions = 0;
  try {
    const sessionRes = await db.query(
      `SELECT COUNT(*)::int AS completed_sessions
       FROM mining_sessions
       WHERE user_id = $1
         AND is_completed = TRUE
         AND COALESCE(status, '') = 'completed'`,
      [userId]
    );
    completedSessions = Number(sessionRes.rows[0]?.completed_sessions || 0);
  } catch (err) {
    if (!err || err.code !== '42P01') {
      throw err;
    }
  }

  let settlementCount = 0;
  let firstSettlementAt = user.first_settlement_at || null;
  try {
    const settlementRes = await db.query(
      `SELECT COUNT(*)::int AS settlement_count,
              MIN(created_at) AS first_settlement_at
       FROM ant_transactions
       WHERE user_id = $1
         AND status = 'completed'
         AND transaction_type = ANY($2::text[])`,
      [userId, SETTLEMENT_TRANSACTION_TYPES]
    );
    settlementCount = Number(settlementRes.rows[0]?.settlement_count || 0);
    firstSettlementAt = settlementRes.rows[0]?.first_settlement_at || firstSettlementAt;
  } catch (err) {
    if (!err || err.code !== '42P01') {
      throw err;
    }
  }

  const verifiedSessions = Math.max(
    0,
    Math.min(Number(user.successful_sessions || 0), completedSessions || Number(user.successful_sessions || 0))
  );
  const hasSettlement = settlementCount > 0;
  const eligibilityBypass = isSessionGateBypassed({
    userId,
    email: user.email,
  });
  const sessionEligible = verifiedSessions >= SESSION_GATE_REQUIRED_SESSIONS || eligibilityBypass;
  const executionEligible = sessionEligible && hasSettlement;
  const needsActivation = executionEligible && !user.nft_activated;

  if (needsActivation) {
    await db.query(
      `UPDATE users
       SET nft_activated = TRUE,
           nft_activated_at = COALESCE(nft_activated_at, NOW()),
           first_settlement_at = COALESCE(first_settlement_at, $2)
       WHERE id = $1`,
      [userId, firstSettlementAt]
    );
    user.nft_activated = true;
    user.nft_activated_at = user.nft_activated_at || new Date();
    user.first_settlement_at = user.first_settlement_at || firstSettlementAt;
  }

  const profileRes = await db.query(
    `SELECT id,
            user_id,
            nft_name,
            powered_by,
            primary_color,
            secondary_color,
            glow_color,
            background_style,
            frame_style,
            hologram_level,
            metadata_json,
            avatar_image_url,
            profile_banner_url,
            nft_card_image_url,
            avatar_thumb_url,
            profile_active,
            created_at,
            updated_at
     FROM user_nft_profiles
     WHERE user_id = $1
     LIMIT 1`,
    [userId]
  );

  const profile = formatProfile(profileRes.rows[0] || null);
  const colonyCode = sanitizeText(user.referral_code || `ANET${user.id}`, 40).toUpperCase();
  const walletAddress = String(user.custom_wallet_address || user.wallet_address || '').trim().toUpperCase();
  const migrationWalletAddress = String(user.migration_wallet_address || '').trim();
  const identityState = !sessionEligible
    ? 'MINER_ONLY'
    : executionEligible
      ? 'NFT_ACTIVATED'
      : 'ELIGIBLE_EXECUTION';
  const rank = Math.max(1, 1000 - Math.floor(verifiedSessions / 3) - (hasSettlement ? 75 : 0));

  return {
    user,
    profile,
    completedSessions: verifiedSessions,
    requiredSessions: SESSION_GATE_REQUIRED_SESSIONS,
    hasSettlement,
    settlementCount,
    firstSettlementAt,
    nftActivated: Boolean(user.nft_activated) || executionEligible,
    identityState,
    colonyCode,
    walletAddress,
    migrationWalletAddress: migrationWalletAddress || null,
    rank,
    sessionEligible,
    executionEligible,
    activationUrl: profile?.avatar_image_url || profile?.avatar_thumb_url || user.profile_avatar_url || buildAvatarUrl(buildAvatarSeed(user, profile?.nft_name || colonyCode)),
    avatarType: user.profile_avatar_type || 'default',
    avatarUrl: user.profile_avatar_url || null,
    activeProfileId: user.active_nft_profile_id || null,
    eligibilityBypass,
  };
}

async function syncUserAvatar(client, userId, profile, useAsAvatar) {
  if (!profile) {
    return;
  }

  const avatarUrl = profile.avatar_thumb_url || profile.avatar_image_url || buildAvatarUrl(buildAvatarSeed({
    id: userId,
    wallet_address: null,
    custom_wallet_address: null,
  }, profile.nft_name));

  await client.query(
    `UPDATE users
     SET active_nft_profile_id = $2,
         profile_avatar_type = $3,
         profile_avatar_url = $4,
         nft_activated = TRUE,
         nft_activated_at = COALESCE(nft_activated_at, NOW())
     WHERE id = $1`,
    [userId, profile.id, useAsAvatar ? 'nft' : 'default', useAsAvatar ? avatarUrl : null]
  );
}

async function loadProfileOrFail(userId) {
  const profileRes = await db.query(
    `SELECT id,
            user_id,
            nft_name,
            powered_by,
            primary_color,
            secondary_color,
            glow_color,
            background_style,
            frame_style,
            hologram_level,
            metadata_json,
            avatar_image_url,
            profile_banner_url,
            nft_card_image_url,
            avatar_thumb_url,
            profile_active,
            created_at,
            updated_at
     FROM user_nft_profiles
     WHERE user_id = $1
     LIMIT 1`,
    [userId]
  );
  return formatProfile(profileRes.rows[0] || null);
}

module.exports = async function (fastify) {
  if (RUN_WALLETNFT_SCHEMA_SYNC_STARTUP) {
    await ensureSchema(fastify);
  } else {
    // Fire-and-forget; failures are logged inside ensureSchema and the cache
    // self-heals on the next call. Must never throw during plugin
    // registration — that would crash `start()` and trigger a restart loop.
    ensureSchema(fastify).catch(() => {});
    fastify.log.info('Wallet NFT startup schema checks skipped (RUN_WALLETNFT_SCHEMA_SYNC_STARTUP=false)');
  }

  fastify.addHook('preHandler', async () => {
    // Best-effort: do not fail the request if schema sync is still in flight
    // or previously errored. Tables/columns already exist in prod; this is a
    // belt-and-suspenders idempotent migration.
    try {
      await ensureSchema(fastify);
    } catch (_) {
      /* logged inside ensureSchema; cache resets on failure for retry */
    }
  });

  fastify.get('/status', {
    preHandler: verifyToken,
    config: { rateLimit: { max: 30, timeWindow: '1 minute' } },
  }, async (req, reply) => {
    try {
      const state = await loadIdentityState(req.user.userId || req.user.id);
      if (state.error) {
        return reply.code(state.statusCode || 500).send({ success: false, error: state.error });
      }

      return {
        success: true,
        ...state,
        profile: state.profile,
      };
    } catch (err) {
      console.error(err);
      return reply.code(500).send({ success: false, error: 'Failed to load NFT identity status' });
    }
  });

  fastify.post('/create', {
    preHandler: verifyToken,
    config: { rateLimit: { max: 8, timeWindow: '1 minute' } },
  }, async (req, reply) => {
    const userId = req.user.userId || req.user.id;
    const existingState = await loadIdentityState(userId);
    if (existingState.error) {
      return reply.code(existingState.statusCode || 500).send({ success: false, error: existingState.error });
    }

    if (!existingState.nftActivated) {
      return reply.code(403).send({
        success: false,
        error: 'NFT identity unlocks only after your first successful settlement event',
        status: existingState,
      });
    }

    const existingProfile = existingState.profile || await loadProfileOrFail(userId);
    if (existingProfile) {
      return {
        success: true,
        created: false,
        profile: existingProfile,
        status: existingState,
      };
    }

    const body = req.body || {};
    const nftName = sanitizeText(body.nftName || body.nft_name || 'A-Network Identity', 120) || 'A-Network Identity';
    const poweredBy = sanitizeText(body.poweredBy || body.powered_by || 'A Network', 120) || 'A Network';
    const primaryColor = normalizeHexColor(body.primaryColor || body.primary_color, '#00D2FF');
    const secondaryColor = normalizeHexColor(body.secondaryColor || body.secondary_color, '#8A3FFC');
    const glowColor = normalizeHexColor(body.glowColor || body.glow_color, '#FFFFFF');
    const backgroundStyle = sanitizeStyleValue(body.backgroundStyle || body.background_style, 'cyberpunk', 64);
    const frameStyle = sanitizeStyleValue(body.frameStyle || body.frame_style, 'chrome', 64);
    const hologramLevelRaw = Number(body.hologramLevel ?? body.hologram_level ?? 0.75);
    const hologramLevel = Number.isFinite(hologramLevelRaw)
      ? Math.max(0, Math.min(1, hologramLevelRaw))
      : 0.75;
    const useAsAvatar = body.useAsAvatar === undefined ? true : Boolean(body.useAsAvatar);
    const metadata = {
      ...toSafeMetadata(body.metadata),
      identityState: existingState.identityState,
      colonyCode: existingState.colonyCode,
      rank: existingState.rank,
      completedSessions: existingState.completedSessions,
      hasSettlement: existingState.hasSettlement,
      walletAddress: existingState.walletAddress,
      nftName,
      poweredBy,
      palette: {
        primaryColor,
        secondaryColor,
        glowColor,
      },
      styles: {
        backgroundStyle,
        frameStyle,
        hologramLevel,
      },
    };
    const seed = buildAvatarSeed(existingState.user, nftName);
    const avatarUrl = buildAvatarUrl(seed);
    const client = await db.connect();

    try {
      await client.query('BEGIN');
      const insertRes = await client.query(
        `INSERT INTO user_nft_profiles
           (user_id, nft_name, powered_by, primary_color, secondary_color, glow_color, background_style, frame_style, hologram_level, metadata_json, avatar_image_url, profile_banner_url, nft_card_image_url, avatar_thumb_url, profile_active, created_at, updated_at)
         VALUES
           ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10::jsonb, $11, $12, $13, $14, TRUE, NOW(), NOW())
         RETURNING id, user_id, nft_name, powered_by, primary_color, secondary_color, glow_color, background_style, frame_style, hologram_level, metadata_json, avatar_image_url, profile_banner_url, nft_card_image_url, avatar_thumb_url, profile_active, created_at, updated_at`,
        [
          userId,
          nftName,
          poweredBy,
          primaryColor,
          secondaryColor,
          glowColor,
          backgroundStyle,
          frameStyle,
          hologramLevel,
          JSON.stringify(metadata),
          avatarUrl,
          null,
          null,
          avatarUrl,
        ]
      );
      const profile = formatProfile(insertRes.rows[0]);
      await syncUserAvatar(client, userId, profile, useAsAvatar);
      await client.query('COMMIT');

      let l1Accepted = false;
      try {
        await postL1ProfileActivity({
          source: 'inapp',
          action: 'nft_identity_created',
          status: 'accepted',
          screen: 'nft_identity',
          wallet: existingState.walletAddress,
          profileId: profile.id,
          profileName: nftName,
          colonyCode: existingState.colonyCode,
          rank: existingState.rank,
          completedSessions: existingState.completedSessions,
          settlementCount: existingState.settlementCount,
          avatarUrl: profile.avatar_thumb_url || profile.avatar_image_url,
        });
        l1Accepted = true;
      } catch (l1Error) {
        console.warn('L1 profile creation activity failed:', l1Error?.message || l1Error);
      }

      return reply.code(201).send({
        success: true,
        created: true,
        profile,
        onChainRecorded: l1Accepted,
        status: {
          ...existingState,
          profile,
          identityState: 'NFT_ACTIVATED',
          nftActivated: true,
          avatarType: useAsAvatar ? 'nft' : 'default',
          avatarUrl: useAsAvatar ? avatarUrl : null,
        },
      });
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  });

  fastify.post('/update', {
    preHandler: verifyToken,
    config: { rateLimit: { max: 12, timeWindow: '1 minute' } },
  }, async (req, reply) => {
    const userId = req.user.userId || req.user.id;
    const existingState = await loadIdentityState(userId);
    if (existingState.error) {
      return reply.code(existingState.statusCode || 500).send({ success: false, error: existingState.error });
    }

    if (!existingState.nftActivated) {
      return reply.code(403).send({
        success: false,
        error: 'NFT identity unlocks only after your first successful settlement event',
        status: existingState,
      });
    }

    const currentProfile = existingState.profile || await loadProfileOrFail(userId);
    if (!currentProfile) {
      return reply.code(404).send({ success: false, error: 'Create your NFT identity first' });
    }

    const body = req.body || {};
    const nftName = sanitizeText(body.nftName || body.nft_name || currentProfile.nft_name, 120) || currentProfile.nft_name;
    const poweredBy = sanitizeText(body.poweredBy || body.powered_by || currentProfile.powered_by, 120) || currentProfile.powered_by;
    const primaryColor = normalizeHexColor(body.primaryColor || body.primary_color, currentProfile.primary_color);
    const secondaryColor = normalizeHexColor(body.secondaryColor || body.secondary_color, currentProfile.secondary_color);
    const glowColor = normalizeHexColor(body.glowColor || body.glow_color, currentProfile.glow_color);
    const backgroundStyle = sanitizeStyleValue(body.backgroundStyle || body.background_style, currentProfile.background_style, 64);
    const frameStyle = sanitizeStyleValue(body.frameStyle || body.frame_style, currentProfile.frame_style, 64);
    const hologramLevelRaw = Number(body.hologramLevel ?? body.hologram_level ?? currentProfile.hologram_level);
    const hologramLevel = Number.isFinite(hologramLevelRaw)
      ? Math.max(0, Math.min(1, hologramLevelRaw))
      : Number(currentProfile.hologram_level || 0.75);
    const useAsAvatar = body.useAsAvatar === undefined ? true : Boolean(body.useAsAvatar);
    const metadata = {
      ...toSafeMetadata(currentProfile.metadata_json),
      ...(toSafeMetadata(body.metadata)),
      identityState: existingState.identityState,
      colonyCode: existingState.colonyCode,
      rank: existingState.rank,
      completedSessions: existingState.completedSessions,
      hasSettlement: existingState.hasSettlement,
      walletAddress: existingState.walletAddress,
      nftName,
      poweredBy,
      palette: {
        primaryColor,
        secondaryColor,
        glowColor,
      },
      styles: {
        backgroundStyle,
        frameStyle,
        hologramLevel,
      },
    };
    const seed = buildAvatarSeed(existingState.user, nftName);
    const avatarUrl = buildAvatarUrl(seed);
    const client = await db.connect();

    try {
      await client.query('BEGIN');
      const updateRes = await client.query(
        `UPDATE user_nft_profiles
         SET nft_name = $2,
             powered_by = $3,
             primary_color = $4,
             secondary_color = $5,
             glow_color = $6,
             background_style = $7,
             frame_style = $8,
             hologram_level = $9,
             metadata_json = $10::jsonb,
             avatar_image_url = $11,
             avatar_thumb_url = $12,
             profile_active = TRUE,
             updated_at = NOW()
         WHERE user_id = $1
         RETURNING id, user_id, nft_name, powered_by, primary_color, secondary_color, glow_color, background_style, frame_style, hologram_level, metadata_json, avatar_image_url, profile_banner_url, nft_card_image_url, avatar_thumb_url, profile_active, created_at, updated_at`,
        [
          userId,
          nftName,
          poweredBy,
          primaryColor,
          secondaryColor,
          glowColor,
          backgroundStyle,
          frameStyle,
          hologramLevel,
          JSON.stringify(metadata),
          avatarUrl,
          avatarUrl,
        ]
      );

      const profile = formatProfile(updateRes.rows[0]);
      await syncUserAvatar(client, userId, profile, useAsAvatar);
      await client.query('COMMIT');

      let l1Accepted = false;
      try {
        await postL1ProfileActivity({
          source: 'inapp',
          action: 'nft_identity_updated',
          status: 'accepted',
          screen: 'nft_identity',
          wallet: existingState.walletAddress,
          profileId: profile.id,
          profileName: nftName,
          colonyCode: existingState.colonyCode,
          rank: existingState.rank,
          completedSessions: existingState.completedSessions,
          settlementCount: existingState.settlementCount,
          avatarUrl: profile.avatar_thumb_url || profile.avatar_image_url,
        });
        l1Accepted = true;
      } catch (l1Error) {
        console.warn('L1 profile update activity failed:', l1Error?.message || l1Error);
      }

      return {
        success: true,
        updated: true,
        profile,
        onChainRecorded: l1Accepted,
        status: {
          ...existingState,
          profile,
          identityState: 'NFT_ACTIVATED',
          nftActivated: true,
          avatarType: useAsAvatar ? 'nft' : 'default',
          avatarUrl: useAsAvatar ? avatarUrl : null,
        },
      };
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  });

  fastify.get('/public/:walletAddress', {
    config: { rateLimit: { max: 120, timeWindow: '1 minute' } },
  }, async (req, reply) => {
    try {
      const walletAddress = sanitizeText(req.params.walletAddress || '', 160).toUpperCase();
      if (!walletAddress || walletAddress.length < 20) {
        return reply.code(400).send({ success: false, error: 'Invalid wallet address' });
      }

      const userRes = await db.query(
        `SELECT id,
                email,
                successful_sessions,
                wallet_address,
                custom_wallet_address,
                migration_wallet_address,
                referral_code,
                nft_activated,
                nft_activated_at,
                first_settlement_at,
                profile_avatar_url,
                profile_avatar_type,
                active_nft_profile_id
         FROM users
         WHERE (UPPER(wallet_address) = $1 OR UPPER(custom_wallet_address) = $1)
           AND COALESCE(is_deleted, FALSE) = FALSE
         LIMIT 1`,
        [walletAddress]
      );

      const user = userRes.rows[0];
      if (!user) {
        return reply.code(404).send({ success: false, error: 'Profile not found' });
      }

      if (!user.nft_activated) {
        return {
          success: true,
          public: true,
          status: 'locked',
          message: 'This miner has not yet unlocked NFT identity. Complete 1,000 sessions + first settlement to unlock.',
          walletAddress: walletAddress,
          refCode: sanitizeText(user.referral_code || `ANET${user.id}`, 40).toUpperCase(),
        };
      }

      let completedSessions = 0;
      try {
        const sessionRes = await db.query(
          `SELECT COUNT(*)::int AS completed_sessions
           FROM mining_sessions
           WHERE user_id = $1
             AND is_completed = TRUE
             AND COALESCE(status, '') = 'completed'`,
          [user.id]
        );
        completedSessions = Number(sessionRes.rows[0]?.completed_sessions || 0);
      } catch (err) {
        if (!err || err.code !== '42P01') {
          throw err;
        }
      }

      let settlementCount = 0;
      try {
        const settlementRes = await db.query(
          `SELECT COUNT(*)::int AS settlement_count
           FROM ant_transactions
           WHERE user_id = $1
             AND status = 'completed'
             AND transaction_type = ANY($2::text[])`,
          [user.id, SETTLEMENT_TRANSACTION_TYPES]
        );
        settlementCount = Number(settlementRes.rows[0]?.settlement_count || 0);
      } catch (err) {
        if (!err || err.code !== '42P01') {
          throw err;
        }
      }

      const verifiedSessions = Math.max(0, Math.min(Number(user.successful_sessions || 0), completedSessions || Number(user.successful_sessions || 0)));
      const rank = Math.max(1, 1000 - Math.floor(verifiedSessions / 3) - (settlementCount > 0 ? 75 : 0));
      const colonyCode = sanitizeText(user.referral_code || `ANET${user.id}`, 40).toUpperCase();

      const profileRes = await db.query(
        `SELECT id,
                user_id,
                nft_name,
                powered_by,
                primary_color,
                secondary_color,
                glow_color,
                background_style,
                frame_style,
                hologram_level,
                metadata_json,
                avatar_image_url,
                profile_banner_url,
                nft_card_image_url,
                avatar_thumb_url,
                profile_active,
                created_at,
                updated_at
         FROM user_nft_profiles
         WHERE user_id = $1
         LIMIT 1`,
        [user.id]
      );

      const profile = formatProfile(profileRes.rows[0] || null);
      const avatarUrl = user.profile_avatar_type === 'nft' && user.profile_avatar_url
        ? user.profile_avatar_url
        : (profile?.avatar_thumb_url || profile?.avatar_image_url || buildAvatarUrl(buildAvatarSeed(user, profile?.nft_name || colonyCode)));

      return {
        success: true,
        public: true,
        status: 'activated',
        walletAddress: walletAddress,
        migrationWalletAddress: String(user.migration_wallet_address || '').trim() || null,
        colonyCode: colonyCode,
        nftActivatedAt: user.nft_activated_at,
        firstSettlementAt: user.first_settlement_at,
        profile: {
          name: profile?.nft_name || 'A-Network Identity',
          poweredBy: profile?.powered_by || 'A Network',
          avatarUrl: avatarUrl,
          metadata: profile?.metadata_json || {},
          styling: {
            primaryColor: profile?.primary_color || '#00D2FF',
            secondaryColor: profile?.secondary_color || '#8A3FFC',
            glowColor: profile?.glow_color || '#FFFFFF',
            backgroundStyle: profile?.background_style || 'cyberpunk',
            frameStyle: profile?.frame_style || 'chrome',
            hologramLevel: Number(profile?.hologram_level || 0.75),
          },
        },
        stats: {
          completedSessions: verifiedSessions,
          requiredSessions: SESSION_GATE_REQUIRED_SESSIONS,
          settlementCount: settlementCount,
          rank: rank,
        },
        verification: {
          onChainActivated: true,
          profileId: profile?.id || null,
          createdAt: profile?.created_at || user.nft_activated_at,
          updatedAt: profile?.updated_at || null,
        },
      };
    } catch (err) {
      console.error(err);
      return reply.code(500).send({ success: false, error: 'Failed to load public profile' });
    }
  });
};
