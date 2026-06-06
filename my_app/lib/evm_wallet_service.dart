import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:bip32/bip32.dart' as bip32;
import 'package:bip39/bip39.dart' as bip39;
import 'package:crypto/crypto.dart' as crypto;
import 'package:hex/hex.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';

// ─── BSC constants ────────────────────────────────────────────────────────────
const int bscChainId = 56;
const String _bscRpc1 = 'https://bsc-dataseed1.binance.org/';
const String _bscRpc2 = 'https://bsc-dataseed2.binance.org/';

const String anetSwapContractAddr =
    '0x1A1AFE5BF1ffDB64aC10958cCe2D06B22Fb47Fb8';

/// On-chain bridge configuration for a single token, as reported by the
/// `tokenConfigs(token)` view on AnetSwap. Used by the UI to validate the
/// user's amount BEFORE submitting (avoids paying gas on a guaranteed revert).
class TokenBridgeConfig {
  final bool accepted;
  final BigInt minAmount;
  final BigInt maxAmount;
  final int decimals;
  final String symbol;
  const TokenBridgeConfig({
    required this.accepted,
    required this.minAmount,
    required this.maxAmount,
    required this.decimals,
    required this.symbol,
  });
}

/// Token definitions on BSC mainnet.
const Map<String, Map<String, dynamic>> bscTokens = {
  'BNB': {'address': '', 'decimals': 18, 'native': true},
  'ANET': {
    'address': '0x791055A7d52AA392eaE8De04250497f33807E46A',
    'decimals': 18,
    'native': false,
  },
  'USDT': {
    'address': '0x55d398326f99059fF775485246999027B3197955',
    'decimals': 18,
    'native': false,
  },
  'USDC': {
    'address': '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d',
    'decimals': 18,
    'native': false,
  },
  'ETH': {
    'address': '0x2170Ed0880ac9A755fd29B2688956BD959F933F8',
    'decimals': 18,
    'native': false,
  },
  'BTCB': {
    'address': '0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c',
    'decimals': 18,
    'native': false,
  },
  'CAKE': {
    'address': '0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82',
    'decimals': 18,
    'native': false,
  },
  'BUSD': {
    'address': '0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56',
    'decimals': 18,
    'native': false,
  },
  // ─── Extended Binance-Peg tokens (all routed via WBNB on PancakeSwap V2) ──
  'DAI': {
    'address': '0x1AF3F329e8BE154074D8769D1FFa4eE058B1DBc3',
    'decimals': 18,
    'native': false,
  },
  'TUSD': {
    'address': '0x14016E85a25aeb13065688cAFB43044C2ef86784',
    'decimals': 18,
    'native': false,
  },
  'DOGE': {
    // Binance-Peg DOGE on BSC uses 8 decimals (NOT 18).
    'address': '0xbA2aE424d960c26247Dd6c32edC70B295c744C43',
    'decimals': 8,
    'native': false,
  },
  'SHIB': {
    'address': '0x2859e4544C4bB03966803b044A93563Bd2D0DD4D',
    'decimals': 18,
    'native': false,
  },
  'MATIC': {
    'address': '0xCC42724C6683B7E57334c4E856f4c9965ED682bD',
    'decimals': 18,
    'native': false,
  },
  'ADA': {
    'address': '0x3EE2200Efb3400fAbB9AacF31297cBdD1d435D47',
    'decimals': 18,
    'native': false,
  },
  'XRP': {
    'address': '0x1D2F0da169ceB9fC7B3144628dB156f3F6c60dBE',
    'decimals': 18,
    'native': false,
  },
  'LTC': {
    'address': '0x4338665CBB7B2485A8855A139b75D5e34AB0DB94',
    'decimals': 18,
    'native': false,
  },
  'LINK': {
    'address': '0xF8A0BF9cF54Bb92F17374d9e9A321E6a111a51bD',
    'decimals': 18,
    'native': false,
  },
  'DOT': {
    'address': '0x7083609fCE4d1d8Dc0C979AAb8c869Ea2C873402',
    'decimals': 18,
    'native': false,
  },
  'AVAX': {
    'address': '0x1CE0c2827e2eF14D5C4f29a091d735A204794041',
    'decimals': 18,
    'native': false,
  },
  'SOL': {
    'address': '0x570A5D26f7765Ecb712C0924E4De545B89fD43dF',
    'decimals': 18,
    'native': false,
  },
  'UNI': {
    'address': '0xBf5140A22578168FD562DCcF235E5D43A02ce9B1',
    'decimals': 18,
    'native': false,
  },
  'TRX': {
    'address': '0xCE7de646e7208a4Ef112cb6ed5038FA6cC6b12e3',
    'decimals': 18,
    'native': false,
  },
  'TWT': {
    'address': '0x4B0F1812e5Df2A09796481Ff14017e6005508003',
    'decimals': 18,
    'native': false,
  },
};

// ─── ABI fragments ────────────────────────────────────────────────────────────
const String _anetSwapAbi = r'''[
  {"name":"swapNativeForAnet","type":"function","stateMutability":"payable",
   "inputs":[{"name":"anetRecipient","type":"string"}],"outputs":[]},
  {"name":"swapTokenForAnet","type":"function","stateMutability":"nonpayable",
   "inputs":[{"name":"token","type":"address"},
             {"name":"amount","type":"uint256"},
             {"name":"anetRecipient","type":"string"}],"outputs":[]},
  {"name":"tokenConfigs","type":"function","stateMutability":"view",
   "inputs":[{"name":"token","type":"address"}],
   "outputs":[{"name":"accepted","type":"bool"},
              {"name":"minAmount","type":"uint256"},
              {"name":"maxAmount","type":"uint256"},
              {"name":"decimals","type":"uint8"},
              {"name":"symbol","type":"string"}]}
]''';

const String _erc20Abi = r'''[
  {"name":"balanceOf","type":"function","stateMutability":"view",
   "inputs":[{"name":"account","type":"address"}],
   "outputs":[{"name":"","type":"uint256"}]},
  {"name":"allowance","type":"function","stateMutability":"view",
   "inputs":[{"name":"owner","type":"address"},{"name":"spender","type":"address"}],
   "outputs":[{"name":"","type":"uint256"}]},
  {"name":"approve","type":"function","stateMutability":"nonpayable",
   "inputs":[{"name":"spender","type":"address"},{"name":"amount","type":"uint256"}],
   "outputs":[{"name":"","type":"bool"}]},
  {"name":"name","type":"function","stateMutability":"view",
   "inputs":[],"outputs":[{"name":"","type":"string"}]},
  {"name":"symbol","type":"function","stateMutability":"view",
   "inputs":[],"outputs":[{"name":"","type":"string"}]},
  {"name":"decimals","type":"function","stateMutability":"view",
   "inputs":[],"outputs":[{"name":"","type":"uint8"}]}
]''';

/// Metadata returned by `EvmWalletService.fetchErc20Metadata`.
class Erc20Metadata {
  final String name;
  final String symbol;
  final int decimals;
  const Erc20Metadata({
    required this.name,
    required this.symbol,
    required this.decimals,
  });
}

// ─── Key derivation ───────────────────────────────────────────────────────────

/// Derives the EVM private key bytes from any supported ANET wallet seed format:
///
///  - `'evmkey:HEX'` — EVM-imported wallet; raw 32-byte private key stored as hex.
///  - Valid BIP39 mnemonic — MetaMask-compatible BIP44 path m/44'/60'/0'/0/0.
///  - Any other string — legacy ANET wallet; deterministic SHA-256 of the seed
///    text (backward-compatible with wallets created before BIP39 rollout).
Uint8List deriveEvmPrivateKey(String seed) {
  final trimmed = seed.trim();

  // EVM-imported wallet: raw private key stored as 'evmkey:HEX'
  if (trimmed.startsWith('evmkey:')) {
    final hexStr = trimmed.substring(7).replaceAll(RegExp(r'\s'), '');
    return Uint8List.fromList(HEX.decode(hexStr));
  }

  // BIP39 mnemonic: standard BIP44 derivation
  final normalized = trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  if (bip39.validateMnemonic(normalized)) {
    final seedBytes = bip39.mnemonicToSeed(normalized);
    final root = bip32.BIP32.fromSeed(seedBytes);
    final child = root.derivePath("m/44'/60'/0'/0/0");
    final privateKey = child.privateKey;
    if (privateKey == null || privateKey.isEmpty) {
      throw Exception('Unable to derive EVM signing key from seed phrase');
    }
    return Uint8List.fromList(privateKey);
  }

  // Legacy ANET wallet: deterministic SHA-256 of the seed phrase text.
  // Produces the same BSC address every time for the same ANET seed.
  final digest = crypto.sha256.convert(utf8.encode(trimmed));
  return Uint8List.fromList(digest.bytes);
}

/// Generates a cryptographically random 32-byte EVM private key.
/// Used for users whose ANET wallet has no exportable seed phrase.
Uint8List generateRandomEvmPrivateKey() {
  final rng = Random.secure();
  return Uint8List.fromList(List.generate(32, (_) => rng.nextInt(256)));
}

// ─── ANET L1 signing key derivation ─────────────────────────────────────────

/// Resolves the **ANET L1** secp256k1 private key bytes from any stored
/// wallet credential string.  This is the key used to sign L1 DEX swaps,
/// transfers, and other on-chain actions.
///
///  - `'evmkey:HEX'` — EVM-imported wallet: raw 32-byte key from hex.
///  - Anything else  — ANET native wallet: SHA-256 of the seed phrase text.
///
/// The returned bytes are always a valid 32-byte secp256k1 private key.
/// They are safe to cache in flutter_secure_storage (Keystore/Secure Enclave).
Uint8List resolveAnetL1PrivateKey(String seedOrEvmKey) {
  final trimmed = seedOrEvmKey.trim();
  if (trimmed.startsWith('evmkey:')) {
    final hexStr = trimmed.substring(7).replaceAll(RegExp(r'\s'), '');
    return Uint8List.fromList(HEX.decode(hexStr));
  }
  // SHA-256 of the seed phrase text — matches `_deriveAnetPrivateKeyFromSeed`
  // in main.dart and the ANET L1 key derivation used for wallet address creation.
  final digest = crypto.sha256.convert(utf8.encode(trimmed));
  return Uint8List.fromList(digest.bytes);
}

// ─── Amount helpers ──────────────────────────────────────────────────────────

/// Parses a decimal string (e.g. "0.5") into the smallest token unit (BigInt).
BigInt parseUnits(String value, int decimals) {
  final cleaned = value.trim();
  if (cleaned.isEmpty) return BigInt.zero;
  final parts = cleaned.split('.');
  final whole = BigInt.parse(parts[0].isEmpty ? '0' : parts[0]);
  BigInt frac = BigInt.zero;
  if (parts.length > 1) {
    final fracStr = parts[1].length > decimals
        ? parts[1].substring(0, decimals)
        : parts[1].padRight(decimals, '0');
    frac = BigInt.parse(fracStr);
  }
  return whole * BigInt.from(10).pow(decimals) + frac;
}

/// Formats a BigInt amount from smallest units to a readable decimal string.
String formatUnits(BigInt value, int decimals, {int displayDecimals = 6}) {
  if (value == BigInt.zero) return '0.${'0' * displayDecimals}';
  final divisor = BigInt.from(10).pow(decimals);
  final whole = value ~/ divisor;
  final frac = value % divisor;
  final fracStr = frac.toString().padLeft(decimals, '0');
  final display = fracStr.substring(
    0,
    displayDecimals.clamp(0, fracStr.length),
  );
  return '$whole.$display';
}

// ─── Service ──────────────────────────────────────────────────────────────────

class EvmWalletService {
  Web3Client? _client;

  Web3Client get _web3 {
    _client ??= Web3Client(_bscRpc1, http.Client());
    return _client!;
  }

  void dispose() {
    _client?.dispose();
    _client = null;
  }

  // ── Balances ────────────────────────────────────────────────────────────────

  Future<BigInt> getBnbBalance(EthereumAddress addr) async {
    try {
      final bal = await _web3.getBalance(addr);
      return bal.getInWei;
    } catch (_) {
      // Fallback to secondary RPC
      final c2 = Web3Client(_bscRpc2, http.Client());
      try {
        final bal = await c2.getBalance(addr);
        return bal.getInWei;
      } finally {
        c2.dispose();
      }
    }
  }

  Future<BigInt> getErc20Balance(
    EthereumAddress owner,
    EthereumAddress token,
  ) async {
    final contract = DeployedContract(
      ContractAbi.fromJson(_erc20Abi, 'ERC20'),
      token,
    );
    final fn = contract.function('balanceOf');
    final result = await _web3.call(
      contract: contract,
      function: fn,
      params: [owner],
    );
    return result.first as BigInt;
  }

  Future<BigInt> getErc20Allowance(
    EthereumAddress owner,
    EthereumAddress token,
    EthereumAddress spender,
  ) async {
    final contract = DeployedContract(
      ContractAbi.fromJson(_erc20Abi, 'ERC20'),
      token,
    );
    final fn = contract.function('allowance');
    final result = await _web3.call(
      contract: contract,
      function: fn,
      params: [owner, spender],
    );
    return result.first as BigInt;
  }

  /// Reads `name()`, `symbol()`, and `decimals()` from any ERC-20 contract.
  /// Used by the "Add custom token" flow to verify a pasted contract address
  /// is a real ERC-20 before persisting it to the user's local token list.
  Future<Erc20Metadata?> fetchErc20Metadata(EthereumAddress token) async {
    try {
      final contract = DeployedContract(
        ContractAbi.fromJson(_erc20Abi, 'ERC20'),
        token,
      );
      final nameFn = contract.function('name');
      final symbolFn = contract.function('symbol');
      final decimalsFn = contract.function('decimals');

      final results = await Future.wait([
        _web3.call(contract: contract, function: nameFn, params: []),
        _web3.call(contract: contract, function: symbolFn, params: []),
        _web3.call(contract: contract, function: decimalsFn, params: []),
      ]);

      final name = results[0].first as String;
      final symbol = results[1].first as String;
      final decRaw = results[2].first;
      final decimals = decRaw is BigInt ? decRaw.toInt() : decRaw as int;

      if (name.trim().isEmpty || symbol.trim().isEmpty) return null;
      if (decimals < 0 || decimals > 36) return null;

      return Erc20Metadata(
        name: name.trim(),
        symbol: symbol.trim(),
        decimals: decimals,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Bridge config ────────────────────────────────────────────────────────────

  /// Returns the minimum bridge amount (in wei/smallest unit) for a given token.
  /// Pass `EthereumAddress.fromHex('0x0000000000000000000000000000000000000000')`
  /// for native BNB. Returns null if the call fails.
  Future<BigInt?> getBridgeMinAmount(EthereumAddress token) async {
    final cfg = await getTokenConfig(token);
    if (cfg == null || !cfg.accepted) return null;
    return cfg.minAmount;
  }

  /// Returns the full bridge configuration for a token from the AnetSwap
  /// contract on BSC: whether it is accepted, the min/max per-tx amounts (in
  /// the token's smallest unit), and its decimals + symbol. Returns null if
  /// the RPC call fails. Use this BEFORE submitting a bridge tx to give the
  /// user a clear error instead of a generic BSC revert.
  Future<TokenBridgeConfig?> getTokenConfig(EthereumAddress token) async {
    try {
      final contractAddr = EthereumAddress.fromHex(anetSwapContractAddr);
      final contract = DeployedContract(
        ContractAbi.fromJson(_anetSwapAbi, 'AnetSwap'),
        contractAddr,
      );
      final fn = contract.function('tokenConfigs');
      final result = await _web3.call(
        contract: contract,
        function: fn,
        params: [token],
      );
      // result: [accepted(bool), minAmount(BigInt), maxAmount(BigInt), decimals(int), symbol(String)]
      final dec = result[3];
      return TokenBridgeConfig(
        accepted: result[0] as bool,
        minAmount: result[1] as BigInt,
        maxAmount: result[2] as BigInt,
        decimals: dec is BigInt ? dec.toInt() : (dec as int),
        symbol: result[4] as String,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Bridge ──────────────────────────────────────────────────────────────────

  /// Bridge native BNB → ANET L1. Returns tx hash.
  Future<String> bridgeNative({
    required EthPrivateKey credentials,
    required BigInt amountWei,
    required String anetRecipient,
  }) async {
    final contractAddr = EthereumAddress.fromHex(anetSwapContractAddr);
    final contract = DeployedContract(
      ContractAbi.fromJson(_anetSwapAbi, 'AnetSwap'),
      contractAddr,
    );
    final fn = contract.function('swapNativeForAnet');
    return _web3.sendTransaction(
      credentials,
      Transaction.callContract(
        contract: contract,
        function: fn,
        parameters: [anetRecipient],
        value: EtherAmount.fromBigInt(EtherUnit.wei, amountWei),
        maxGas: 200000,
        gasPrice: EtherAmount.fromBigInt(EtherUnit.gwei, BigInt.from(3)),
      ),
      chainId: bscChainId,
    );
  }

  /// Bridge ERC-20 token → ANET L1. Approves spending if needed. Returns tx hash.
  Future<String> bridgeToken({
    required EthPrivateKey credentials,
    required String tokenSymbol,
    required BigInt amountUnits,
    required String anetRecipient,
  }) async {
    final tokenInfo = bscTokens[tokenSymbol]!;
    final tokenAddr = EthereumAddress.fromHex(tokenInfo['address'] as String);
    final spender = EthereumAddress.fromHex(anetSwapContractAddr);
    final owner = credentials.address;

    // Approve if allowance is insufficient.
    // CRITICAL: wait for the approve receipt AND re-verify allowance on-chain
    // before broadcasting the bridge tx. A fixed sleep is not safe on BSC —
    // if the approve hasn't been mined yet, transferFrom reverts and the user
    // burns gas ("SafeERC20: transferFrom failed").
    final allowance = await getErc20Allowance(owner, tokenAddr, spender);
    if (allowance < amountUnits) {
      final approveHash = await _approveErc20(
        credentials: credentials,
        tokenAddr: tokenAddr,
        spender: spender,
        amount: amountUnits,
      );
      final rc = await waitForReceipt(approveHash, timeoutSeconds: 90);
      if (rc == null) {
        throw Exception(
          'Approval transaction not mined within 90s. Please try again.',
        );
      }
      if (rc.status != true) {
        throw Exception('Approval transaction failed on BSC.');
      }
      // Re-verify allowance is now sufficient before we broadcast the bridge.
      var verified = await getErc20Allowance(owner, tokenAddr, spender);
      // Some RPCs lag one block — poll briefly.
      var tries = 0;
      while (verified < amountUnits && tries < 5) {
        await Future<void>.delayed(const Duration(seconds: 2));
        verified = await getErc20Allowance(owner, tokenAddr, spender);
        tries++;
      }
      if (verified < amountUnits) {
        throw Exception(
          'Approval mined but allowance still insufficient. Please try again.',
        );
      }
    }

    // Bridge
    // ERC20 path is much heavier than native: transferFrom + fee transfer +
    // contract bookkeeping + event logs. 300k was bumping straight into the
    // limit on USDC bridges (out-of-gas reverts). 600k gives comfortable
    // headroom; unused gas is refunded by BSC.
    final contractAddr = EthereumAddress.fromHex(anetSwapContractAddr);
    final contract = DeployedContract(
      ContractAbi.fromJson(_anetSwapAbi, 'AnetSwap'),
      contractAddr,
    );
    final fn = contract.function('swapTokenForAnet');
    return _web3.sendTransaction(
      credentials,
      Transaction.callContract(
        contract: contract,
        function: fn,
        parameters: [tokenAddr, amountUnits, anetRecipient],
        maxGas: 600000,
        gasPrice: EtherAmount.fromBigInt(EtherUnit.gwei, BigInt.from(3)),
      ),
      chainId: bscChainId,
    );
  }

  Future<String> _approveErc20({
    required EthPrivateKey credentials,
    required EthereumAddress tokenAddr,
    required EthereumAddress spender,
    required BigInt amount,
  }) async {
    final contract = DeployedContract(
      ContractAbi.fromJson(_erc20Abi, 'ERC20'),
      tokenAddr,
    );
    final fn = contract.function('approve');
    return _web3.sendTransaction(
      credentials,
      Transaction.callContract(
        contract: contract,
        function: fn,
        parameters: [spender, amount],
        maxGas: 100000,
        gasPrice: EtherAmount.fromBigInt(EtherUnit.gwei, BigInt.from(3)),
      ),
      chainId: bscChainId,
    );
  }

  // ── Receipt ──────────────────────────────────────────────────────────────────

  /// Polls for a BSC transaction receipt up to [timeoutSeconds].
  Future<TransactionReceipt?> waitForReceipt(
    String txHash, {
    int timeoutSeconds = 90,
  }) async {
    final deadline = DateTime.now().add(Duration(seconds: timeoutSeconds));
    while (DateTime.now().isBefore(deadline)) {
      final r = await _web3.getTransactionReceipt(txHash);
      if (r != null) return r;
      await Future<void>.delayed(const Duration(seconds: 3));
    }
    return null;
  }

  // ── Network info ─────────────────────────────────────────────────────────

  /// Returns the current BSC gas price in wei.
  Future<BigInt> getGasPrice() async {
    try {
      final price = await _web3.getGasPrice();
      return price.getInWei;
    } catch (_) {
      return BigInt.from(3000000000); // 3 gwei fallback
    }
  }

  /// Returns the current BSC block number.
  Future<int> getCurrentBlock() async {
    try {
      return await _web3.getBlockNumber();
    } catch (_) {
      return 0;
    }
  }
}
