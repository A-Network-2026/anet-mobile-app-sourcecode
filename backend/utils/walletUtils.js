const crypto = require('crypto');
const bip39 = require('bip39');

function generateSeedPhrase() {
  // 128 bits entropy => 12-word BIP39 mnemonic compatible with MetaMask.
  return bip39.generateMnemonic(128);
}

function seedToPrivateKey(seed) {
  return crypto.createHash('sha256').update(String(seed || '')).digest('hex');
}

function privateToPublic(privateKey) {
  return crypto.createHash('sha256').update(String(privateKey || '')).digest('hex');
}

function publicToAddress(publicKey) {
  const hash = crypto.createHash('ripemd160').update(String(publicKey || '')).digest('hex').toUpperCase();
  return `ANET${hash.substring(0, 36)}`;
}

function publicKeyBytesToAddress(publicKeyBytes) {
  const hash = crypto.createHash('ripemd160').update(Buffer.from(publicKeyBytes || [])).digest('hex').toUpperCase();
  return `ANET${hash.substring(0, 36)}`;
}

function privateToSecp256k1CompressedPublic(privateKeyHex) {
  const privateKey = Buffer.from(String(privateKeyHex || ''), 'hex');
  if (privateKey.length !== 32) {
    throw new Error('Invalid private key length for secp256k1 derivation');
  }

  const ecdh = crypto.createECDH('secp256k1');
  ecdh.setPrivateKey(privateKey);
  return ecdh.getPublicKey(null, 'compressed');
}

function generateCustomWalletAddress(passphrase) {
  const privateKey = seedToPrivateKey(passphrase);
  const publicKey = privateToPublic(privateKey);
  return publicToAddress(publicKey);
}

function createWallet() {
  const seed = generateSeedPhrase();
  const privateKey = seedToPrivateKey(seed);
  const publicKey = privateToPublic(privateKey);
  const address = publicToAddress(publicKey);

  return {
    seed,
    privateKey,
    publicKey,
    address,
  };
}

function generateL1CompatibleWalletAddress(passphrase) {
  const privateKey = seedToPrivateKey(passphrase);
  const compressedPublicKey = privateToSecp256k1CompressedPublic(privateKey);
  return publicKeyBytesToAddress(compressedPublicKey);
}

function createL1CompatibleWallet() {
  const seed = generateSeedPhrase();
  const privateKey = seedToPrivateKey(seed);
  const compressedPublicKey = privateToSecp256k1CompressedPublic(privateKey);
  const address = publicKeyBytesToAddress(compressedPublicKey);

  return {
    seed,
    privateKey,
    publicKey: compressedPublicKey.toString('hex'),
    address,
    legacyAddress: generateCustomWalletAddress(seed),
  };
}

/**
 * ✅ Validate ANET wallet address format
 */
function isValidANETWallet(address) {
  if (!address || typeof address !== 'string') return false;
  // ANET prefix + 36 hex-like chars = 40 total chars
  return /^ANET[A-F0-9]{36}$/.test(String(address).toUpperCase());
}

/**
 * 🔗 EVM Wallet mapping and validation
 * Supports MetaMask and other EVM-compatible wallets
 */
function isValidEVMAddress(address) {
  if (!address || typeof address !== 'string') return false;
  // Ethereum address format: 0x + 40 hex characters
  return /^0x[a-fA-F0-9]{40}$/.test(address);
}

module.exports = {
  generateSeedPhrase,
  seedToPrivateKey,
  privateToPublic,
  publicToAddress,
  publicKeyBytesToAddress,
  privateToSecp256k1CompressedPublic,
  generateCustomWalletAddress,
  generateL1CompatibleWalletAddress,
  createWallet,
  createL1CompatibleWallet,
  isValidANETWallet,
  isValidEVMAddress,
};
