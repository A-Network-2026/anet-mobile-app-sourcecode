// Background performance-index creation.
//
// Runs AFTER fastify.listen so it can never block startup or port binding.
// Uses CREATE INDEX CONCURRENTLY so no table-level write lock is taken — safe
// to run against a live database under heartbeat traffic.
//
// Each statement is idempotent (IF NOT EXISTS) and wrapped in its own
// try/catch so any single failure (timeout, perms, conflict) is logged and
// the rest still run. Once the indexes exist, subsequent restarts are no-ops.
//
// Kill switch: set ENSURE_PERF_INDEXES=false to skip entirely.

const db = require('./db');

const KILL_SWITCH = String(process.env.ENSURE_PERF_INDEXES || 'true')
  .trim()
  .toLowerCase() !== 'false';

// Each index targets a slow query observed in production logs.
const INDEXES = [
  {
    name: 'idx_mining_sessions_user_active_started',
    sql: `CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_mining_sessions_user_active_started
          ON mining_sessions (user_id, start_time DESC)
          WHERE is_completed = FALSE`,
    reason: 'heartbeat UPDATE subquery: SELECT id FROM mining_sessions WHERE user_id=$1 AND is_completed=FALSE ORDER BY start_time DESC LIMIT 1',
  },
  {
    name: 'idx_mining_sessions_user_id',
    sql: `CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_mining_sessions_user_id
          ON mining_sessions (user_id)`,
    reason: 'SELECT COUNT(*) FROM mining_sessions WHERE user_id = $1',
  },
  {
    name: 'idx_users_device_fingerprint_active',
    sql: `CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_device_fingerprint_active
          ON users (device_fingerprint)
          WHERE COALESCE(is_deleted, FALSE) = FALSE`,
    reason: 'device-dup check: SELECT 1 FROM users WHERE device_fingerprint=$1 AND is_deleted=FALSE',
  },
];

async function ensurePerfIndexes(logger) {
  const log = logger || console;

  if (!KILL_SWITCH) {
    log.info('Perf-index creation skipped (ENSURE_PERF_INDEXES=false)');
    return;
  }

  for (const idx of INDEXES) {
    try {
      // Note: CREATE INDEX CONCURRENTLY must run outside a transaction.
      // pg-pool's pool.query() runs each statement in its own implicit txn,
      // which is fine because a single statement is auto-committed.
      const startedAt = Date.now();
      await db.query(idx.sql);
      log.info(
        { event: 'perf_index_ready', name: idx.name, ms: Date.now() - startedAt },
        `Perf index ready: ${idx.name}`
      );
    } catch (err) {
      // Common non-fatal cases:
      //  - 42P07 duplicate_table (index exists but with mismatched definition)
      //  - 23505 unique_violation (CONCURRENTLY left an INVALID index from a
      //    prior crashed run — operator should DROP it manually)
      //  - 57014 statement_timeout (DB busy — try again next restart)
      log.warn(
        { err, event: 'perf_index_failed', name: idx.name },
        `Perf index failed (will retry on next restart): ${idx.name}`
      );
    }
  }
}

module.exports = ensurePerfIndexes;
