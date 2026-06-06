# FEATURE FREEZE IN EFFECT

**Start:** 2026-05-14  
**End:** 2026-05-28  
**Status:** ACTIVE

## Policy
Only the following commit types are permitted during the freeze window:
- `fix:` — bug fixes reducing measurable risk
- `security:` — security hardening (timing-safe comparisons, input validation, etc.)
- `hardening:` — reliability improvements (error handling, idempotency)
- `chore:` — dependency pinning, CI/CD, monitoring

## Exception Whitelist
The following features were approved before/during freeze due to critical user impact:
- `feat: EVM/MetaMask wallet import` (2026-05-17, commit ced767a) — approved: DEX usability blocker

## Rejected During Freeze
- New UI screens unrelated to security or stability
- New API integrations
- Database schema additions not required by a security fix

## Freeze Owner
Any exception to this policy requires explicit approval and must be logged above.
