// Apply schema.sql to the configured DATABASE_URL. Idempotent — safe to
// re-run on every deploy (CREATE TABLE IF NOT EXISTS).
import 'dotenv/config';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import pg from 'pg';

const { Pool } = pg;
const __dirname = dirname(fileURLToPath(import.meta.url));

const url = process.env.DATABASE_URL;
if (!url) {
  console.error('DATABASE_URL is not set');
  process.exit(1);
}

const pool = new Pool({
  connectionString: url,
  ssl: url.includes('localhost') ? false : { rejectUnauthorized: false },
});

const sql = readFileSync(join(__dirname, '..', 'schema.sql'), 'utf8');

try {
  await pool.query(sql);
  console.log('✓ schema applied');
} catch (e) {
  console.error('migration failed', e);
  process.exit(1);
} finally {
  await pool.end();
}
