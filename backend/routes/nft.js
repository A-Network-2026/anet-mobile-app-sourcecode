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

let nftSchemaInitPromise = null;

function startNftSchemaSetup(fastify) {
  if (!nftSchemaInitPromise) {
    nftSchemaInitPromise = (async () => {
      await db.query(`
        CREATE TABLE IF NOT EXISTS nft_mints (
          id BIGSERIAL PRIMARY KEY,
          user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          wallet_address VARCHAR(120),
          title VARCHAR(120) NOT NULL,
          description TEXT,
          image_url TEXT,
          metadata_json JSONB,
          onchain_action VARCHAR(120),
          onchain_status VARCHAR(40) DEFAULT 'pending',
          onchain_response JSONB,
          onchain_error TEXT,
          created_at TIMESTAMP DEFAULT NOW()
        )
      `);
      await db.query('CREATE INDEX IF NOT EXISTS idx_nft_mints_user_created ON nft_mints(user_id, created_at DESC)');
      await db.query('CREATE INDEX IF NOT EXISTS idx_nft_mints_wallet_created ON nft_mints(wallet_address, created_at DESC)');
    })();

    if (fastify) {
      nftSchemaInitPromise
        .then(() => fastify.log.info('NFT schema checks completed'))
        .catch((err) => fastify.log.error(err, 'NFT schema checks failed'));
    }
  }

  return nftSchemaInitPromise;
}

function sanitizeActivityText(value, maxLen = 180) {
  return String(value || '')
    .replace(/[\r\n;|]+/g, ' ')
    .trim()
    .slice(0, maxLen);
}

function toSafeJson(value) {
  if (value == null) return null;
  if (typeof value === 'object') return value;
  return { value: String(value) };
}

async function postL1AppActivity(payload) {
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

module.exports = async function (fastify) {
  startNftSchemaSetup(fastify);

  fastify.addHook('preHandler', async () => {
    await startNftSchemaSetup();
  });

  fastify.get('/mine', {
    preHandler: verifyToken,
    config: { rateLimit: { max: 40, timeWindow: '1 minute' } },
  }, async (req, reply) => {
    const userId = req.user.userId || req.user.id;
    const limit = Math.min(Math.max(parseInt(req.query.limit || '40', 10) || 40, 1), 100);

    const rows = await db.query(
      `SELECT id, wallet_address, title, description, image_url, metadata_json,
              onchain_action, onchain_status, onchain_error, created_at
       FROM nft_mints
       WHERE user_id = $1
       ORDER BY created_at DESC
       LIMIT $2`,
      [userId, limit]
    );

    return {
      success: true,
      nfts: rows.rows,
      count: rows.rowCount,
    };
  });

  fastify.post('/mint', {
    preHandler: verifyToken,
    config: { rateLimit: { max: 8, timeWindow: '1 minute' } },
  }, async (req, reply) => {
    const userId = req.user.userId || req.user.id;
    const title = String(req.body?.title || '').trim();
    const description = String(req.body?.description || '').trim();
    const imageUrl = String(req.body?.imageUrl || '').trim();
    const metadata = req.body?.metadata;

    if (!title || title.length < 3 || title.length > 120) {
      return reply.code(400).send({ error: 'NFT title must be 3 to 120 characters' });
    }
    if (!description || description.length < 8 || description.length > 1200) {
      return reply.code(400).send({ error: 'NFT description must be 8 to 1200 characters' });
    }
    if (imageUrl && !/^https?:\/\//i.test(imageUrl)) {
      return reply.code(400).send({ error: 'imageUrl must be an http/https URL' });
    }

    const sessionRes = await db.query(
      `SELECT COUNT(*)::int AS completed_sessions
       FROM mining_sessions
       WHERE user_id = $1
         AND is_completed = TRUE
         AND COALESCE(status, '') = 'completed'`,
      [userId]
    );
    const completedSessions = Number(sessionRes.rows[0]?.completed_sessions || 0);

    const userRes = await db.query(
      `SELECT email, wallet_address, custom_wallet_address
       FROM users
       WHERE id = $1
       LIMIT 1`,
      [userId]
    );

    const eligibilityBypass = isSessionGateBypassed({
      userId,
      email: userRes.rows[0]?.email,
    });

    if (completedSessions < SESSION_GATE_REQUIRED_SESSIONS && !eligibilityBypass) {
      return reply.code(403).send({
        error: `NFT mint unlocks after ${SESSION_GATE_REQUIRED_SESSIONS} sessions`,
        completedSessions,
        requiredSessions: SESSION_GATE_REQUIRED_SESSIONS,
      });
    }

    const walletAddress = String(
      userRes.rows[0]?.custom_wallet_address || userRes.rows[0]?.wallet_address || ''
    ).trim().toUpperCase();

    const insertRes = await db.query(
      `INSERT INTO nft_mints
         (user_id, wallet_address, title, description, image_url, metadata_json, onchain_status)
       VALUES
         ($1, NULLIF($2, ''), $3, $4, NULLIF($5, ''), $6, 'pending')
       RETURNING id, wallet_address, title, description, image_url, metadata_json, created_at`,
      [
        userId,
        walletAddress,
        title,
        description,
        imageUrl,
        toSafeJson(metadata),
      ]
    );

    const nft = insertRes.rows[0];
    const detail = [
      `nft_id=${nft.id}`,
      `wallet=${sanitizeActivityText(walletAddress, 60)}`,
      `title=${sanitizeActivityText(title, 80)}`,
      `description=${sanitizeActivityText(description, 140)}`,
      imageUrl ? `image=${sanitizeActivityText(imageUrl, 180)}` : '',
    ]
      .filter(Boolean)
      .join(';');

    let onchainAccepted = false;
    let onchainAction = null;
    let onchainResponse = null;
    let onchainError = null;

    try {
      onchainResponse = await postL1AppActivity({
        source: 'inapp',
        action: 'nft_mint',
        status: 'accepted',
        screen: 'nft_studio',
        detail,
      });
      onchainAccepted = true;
      onchainAction = String(onchainResponse.action || 'ui_nft_mint');
    } catch (error) {
      onchainAccepted = false;
      onchainError = error?.message || 'L1 activity call failed';
    }

    await db.query(
      `UPDATE nft_mints
       SET onchain_status = $1,
           onchain_action = $2,
           onchain_response = $3,
           onchain_error = $4
       WHERE id = $5`,
      [
        onchainAccepted ? 'accepted' : 'failed',
        onchainAction,
        toSafeJson(onchainResponse),
        onchainError,
        nft.id,
      ]
    );

    return reply.code(201).send({
      success: true,
      nft: {
        ...nft,
        onchain_status: onchainAccepted ? 'accepted' : 'failed',
        onchain_action: onchainAction,
        onchain_error: onchainError,
      },
    });
  });
};
