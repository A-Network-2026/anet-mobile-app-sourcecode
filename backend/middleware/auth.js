const jwt = require('jsonwebtoken');
const db = require('../db');
const { extractSecuritySignals, logAudit } = require('../services/antiAbuse');
require('dotenv').config();

const SECRET = process.env.JWT_SECRET;
const PRESENCE_TOUCH_INTERVAL_MINUTES = Math.max(
  1,
  Number(process.env.PRESENCE_TOUCH_INTERVAL_MINUTES || 1)
);
const PRESENCE_TOUCH_MIN_INTERVAL_MS = 60_000;
const AUTH_DB_WAITING_THRESHOLD = Number(process.env.AUTH_DB_WAITING_THRESHOLD || 12);

// In-memory debounce: skip the DB write if we touched recently for this userId.
const presenceLastTouched = new Map();

async function touchUserPresence(userId) {
  if (!userId) {
    return;
  }

  // Debounce: skip if touched within the last minute (per userId).
  const now = Date.now();
  const last = presenceLastTouched.get(userId) || 0;
  if (now - last < PRESENCE_TOUCH_MIN_INTERVAL_MS) {
    return;
  }
  presenceLastTouched.set(userId, now);

  // Skip under DB connection pressure to avoid piling slow writes onto an overloaded pool.
  const waitingCount = Number(db.waitingCount || 0);
  if (Number.isFinite(waitingCount) && waitingCount >= AUTH_DB_WAITING_THRESHOLD) {
    return;
  }

  try {
    await db.query(
      `UPDATE users
       SET last_seen_at = NOW()
       WHERE id = $1
         AND (
           last_seen_at IS NULL
           OR last_seen_at < NOW() - ($2::int * INTERVAL '1 minute')
         )`,
      [userId, PRESENCE_TOUCH_INTERVAL_MINUTES]
    );
  } catch (_) {
    // Presence updates should never block authenticated requests.
  }
}

async function deny(req, reply, reason, userId = null) {
  try {
    await logAudit(db, {
      eventType: 'auth_token_rejected',
      userId,
      ip: req.ip,
      deviceId: String(req.headers['x-device-id'] || '').trim() || null,
      deviceFingerprint: String(req.headers['x-device-fingerprint'] || '').trim() || null,
      details: { reason },
    });
  } catch (_) {
    // Fail closed even if audit logging is unavailable.
  }
  return reply.code(401).send({ error: reason });
}

async function verifyToken(req, reply) {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader) {
      return deny(req, reply, 'No token provided');
    }

    /// Expect format: Bearer TOKEN
    const token = authHeader.split(" ")[1];

    if (!token) {
      return deny(req, reply, 'Invalid token format');
    }

    const decoded = jwt.verify(token, SECRET);

    if (!decoded?.userId || !decoded?.sessionNonce) {
      return deny(req, reply, 'Session expired. Please login again.', decoded?.userId || null);
    }

    const userRes = await db.query(
      `SELECT id, device_id, device_fingerprint, session_nonce, is_deleted
       FROM users
       WHERE id = $1
       LIMIT 1`,
      [decoded.userId]
    );

    const user = userRes.rows[0];
    if (!user || Boolean(user.is_deleted)) {
      return deny(req, reply, 'Unauthorized', decoded.userId);
    }

    if (!user.session_nonce || user.session_nonce !== decoded.sessionNonce) {
      return deny(req, reply, 'Session expired. Please login again.', decoded.userId);
    }

    const signals = extractSecuritySignals(req);

    if (decoded.deviceId && signals.deviceId !== decoded.deviceId) {
      return deny(req, reply, 'Device verification failed. Please login again.', decoded.userId);
    }

    if (decoded.deviceFingerprint && signals.deviceFingerprint !== decoded.deviceFingerprint) {
      return deny(req, reply, 'Device verification failed. Please login again.', decoded.userId);
    }

    if (user.device_id && signals.deviceId !== user.device_id) {
      return deny(req, reply, 'Device verification failed. Please login again.', decoded.userId);
    }

    if (user.device_fingerprint && signals.deviceFingerprint !== user.device_fingerprint) {
      return deny(req, reply, 'Device verification failed. Please login again.', decoded.userId);
    }

    /// attach user to request
    req.user = decoded;
    await touchUserPresence(decoded.userId);

  } catch (err) {
    return deny(req, reply, 'Unauthorized');
  }
}

module.exports = verifyToken;