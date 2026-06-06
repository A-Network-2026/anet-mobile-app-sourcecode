require('dotenv').config();
const { Pool } = require('pg');

const poolBaseConfig = {
  max: Math.max(2, Number(process.env.PGPOOL_MAX || 20)),
  min: Math.max(0, Number(process.env.PGPOOL_MIN || 2)),
  idleTimeoutMillis: Math.max(1000, Number(process.env.PGPOOL_IDLE_TIMEOUT_MS || 30000)),
  connectionTimeoutMillis: Math.max(1000, Number(process.env.PGPOOL_CONNECTION_TIMEOUT_MS || 5000)),
  keepAlive: String(process.env.PGPOOL_KEEPALIVE || 'true').toLowerCase() !== 'false',
  keepAliveInitialDelayMillis: Math.max(0, Number(process.env.PGPOOL_KEEPALIVE_INITIAL_DELAY_MS || 10000)),
};

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

let pool;
if (process.env.DATABASE_URL) {
  const sslMode = String(process.env.PGSSLMODE || '').toLowerCase();
  const disableSsl = sslMode === 'disable';

  pool = new Pool({
    ...poolBaseConfig,
    connectionString: process.env.DATABASE_URL,
    ssl: disableSsl ? false : { rejectUnauthorized: false },
  });
} else {
  pool = new Pool({
    ...poolBaseConfig,
    user: process.env.DB_USER,
    host: process.env.DB_HOST,
    database: process.env.DB_NAME,
    password: process.env.DB_PASS,
    port: process.env.DB_PORT,
  });
}

async function waitForDatabase(options = {}) {
  const attempts = Number(
    options.attempts || process.env.DB_STARTUP_RETRIES || 30
  );
  const delayMs = Number(
    options.delayMs || process.env.DB_STARTUP_RETRY_MS || 2000
  );

  let lastError = null;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      await pool.query('SELECT 1');
      console.log('✅ PostgreSQL connected');
      return true;
    } catch (err) {
      lastError = err;
      console.error(
        `❌ DB connection error (attempt ${attempt}/${attempts}):`,
        err
      );
      if (attempt < attempts) {
        await sleep(delayMs);
      }
    }
  }

  throw lastError;
}

pool.waitForDatabase = waitForDatabase;

module.exports = pool;