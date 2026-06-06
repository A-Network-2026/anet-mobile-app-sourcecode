const crypto = require('crypto');

const ALGO = 'aes-256-gcm';

function getKey() {
  const raw = String(process.env.WALLET_SEED_ENCRYPTION_KEY || '').trim();
  if (!raw) {
    throw new Error('Missing WALLET_SEED_ENCRYPTION_KEY environment variable');
  }

  if (/^[A-Fa-f0-9]{64}$/.test(raw)) {
    return Buffer.from(raw, 'hex');
  }

  // Accept passphrase-like keys and derive a 32-byte key deterministically.
  return crypto.createHash('sha256').update(raw).digest();
}

function encryptSecret(plainText) {
  const iv = crypto.randomBytes(12);
  const key = getKey();
  const cipher = crypto.createCipheriv(ALGO, key, iv);

  const encrypted = Buffer.concat([
    cipher.update(String(plainText || ''), 'utf8'),
    cipher.final(),
  ]);
  const tag = cipher.getAuthTag();

  return {
    encrypted: encrypted.toString('base64'),
    iv: iv.toString('base64'),
    tag: tag.toString('base64'),
  };
}

function decryptSecret(encrypted, iv, tag) {
  const key = getKey();
  const decipher = crypto.createDecipheriv(
    ALGO,
    key,
    Buffer.from(String(iv || ''), 'base64')
  );
  decipher.setAuthTag(Buffer.from(String(tag || ''), 'base64'));

  const plain = Buffer.concat([
    decipher.update(Buffer.from(String(encrypted || ''), 'base64')),
    decipher.final(),
  ]);

  return plain.toString('utf8');
}

module.exports = {
  encryptSecret,
  decryptSecret,
};
