// Production launcher. The legacy Express test server has been removed because
// it created a Postgres pool with `ssl: { rejectUnauthorized: false }`, which a
// single env flip (USE_LEGACY_EXPRESS=true) could re-enable in production —
// downgrading every DB connection to "accept any certificate." That is exactly
// the kind of silent foot-gun this project is hardening away from.
//
// If a minimal smoke server is ever needed again, write a separate file with
// proper CA pinning. Do not bring the toggle back.
if (String(process.env.USE_LEGACY_EXPRESS || 'false').toLowerCase() === 'true') {
  console.error(
    'USE_LEGACY_EXPRESS is no longer supported. The legacy server has been ' +
    'removed (insecure TLS posture). Unset USE_LEGACY_EXPRESS and redeploy.'
  );
  process.exit(2);
}

require('./backend/server');
