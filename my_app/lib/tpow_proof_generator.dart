import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:bip32/bip32.dart' as bip32;
import 'package:web3dart/crypto.dart' show sign, bytesToHex;

/// TPoW (Time Proof of Work) proof generator for A Network.
/// Generates mining proofs that are signed by the miner's private key.
class TPoWProofGenerator {
  /// Generate a TPoW proof hash by finding a nonce that satisfies the difficulty target.
  /// 
  /// difficulty: Number of leading zero bits required (1-32).
  /// miner: The miner's wallet address (ANET prefix).
  /// maxIterations: Maximum nonces to try before giving up.
  /// 
  /// Returns: Proof hash as hex string, or null if target not found within iterations.
  static Future<String?> generateProofHash({
    required int difficulty,
    required String miner,
    int maxIterations = 100000,
  }) async {
    if (difficulty < 1 || difficulty > 32) {
      throw ArgumentError('difficulty must be between 1 and 32');
    }

    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final basePayload = '$miner|$timestamp|';

    for (int nonce = 0; nonce < maxIterations; nonce++) {
      final payload = '$basePayload$nonce';
      final hash = sha256.convert(utf8.encode(payload)).toString();

      // Check if hash meets difficulty requirement (leading zero bits).
      final leadingZeros = _countLeadingZeroBits(hash);
      if (leadingZeros >= difficulty) {
        return hash;
      }
    }

    // Target difficulty not found within iteration limit.
    return null;
  }

  /// Sign a mining proof with the miner's private key.
  /// 
  /// proof: The proof hash (hex string).
  /// difficulty: The proof difficulty level.
  /// miner: The miner's wallet address.
  /// nonce: A unique nonce for the signature (prevents replay).
  /// chainId: The blockchain chain_id.
  /// mnemonic: The miner's BIP39 mnemonic.
  /// 
  /// Returns: Signature as hex string (recoverable format).
  static Future<String> signProof({
    required String proof,
    required int difficulty,
    required String miner,
    required int nonce,
    required String chainId,
    required String mnemonic,
  }) async {
    if (!bip39.validateMnemonic(mnemonic)) {
      throw ArgumentError('Invalid mnemonic');
    }

    // Derive private key from mnemonic (same path as wallet signing).
    final seed = bip39.mnemonicToSeed(mnemonic);
    final root = bip32.BIP32.fromSeed(seed);
    final derivedKey = root.derivePath("m/44'/60'/0'/0/0");
    final privateKeyBytes = derivedKey.privateKey!;

    // Create proof signing message.
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final proofSigningBytes = _createProofSigningBytes(
      miner: miner,
      nonce: nonce,
      timestamp: timestamp,
      chainId: chainId,
      proofHash: proof,
      difficulty: difficulty,
    );

    // Hash the signing bytes with SHA256.
    final digest = Uint8List.fromList(sha256.convert(proofSigningBytes).bytes);
    
    // Sign using web3dart's sign function (secp256k1 ECDSA).
    final sig = sign(digest, privateKeyBytes);
    
    // Combine r + s + v into signature bytes (65 bytes total).
    final sigBytes = Uint8List.fromList([
      ..._bigIntTo32Bytes(sig.r),
      ..._bigIntTo32Bytes(sig.s),
      sig.v,
    ]);
    
    // Return signature as 0x-prefixed hex string.
    return bytesToHex(sigBytes, include0x: true).toLowerCase();
  }

  /// Create the canonical signing bytes for a mining proof.
  static List<int> _createProofSigningBytes({
    required String miner,
    required int nonce,
    required int timestamp,
    required String chainId,
    required String proofHash,
    required int difficulty,
  }) {
    final preimage = 'proof-v1|'
        '${miner.toUpperCase()}|'
        '$nonce|'
        '$timestamp|'
        '${chainId.trim()}|'
        '${proofHash.toLowerCase()}|'
        '$difficulty';
    return utf8.encode(preimage);
  }

  /// Convert a BigInt to 32 bytes (big-endian).
  static List<int> _bigIntTo32Bytes(BigInt value) {
    final bytes = value.toRadixString(16).padLeft(64, '0');
    final result = <int>[];
    for (int i = 0; i < 64; i += 2) {
      result.add(int.parse(bytes.substring(i, i + 2), radix: 16));
    }
    return result;
  }

  /// Count leading zero bits in a hex string.
  static int _countLeadingZeroBits(String hexString) {
    int zeroCount = 0;
    for (final char in hexString.split('')) {
      final val = int.parse(char, radix: 16);
      for (int i = 3; i >= 0; i--) {
        if ((val & (1 << i)) == 0) {
          zeroCount++;
        } else {
          return zeroCount;
        }
      }
    }
    return zeroCount;
  }
}
