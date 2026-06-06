// SPDX-License-Identifier: MIT
// Service wrapper for the AnetUsernameRegistry on BSC.
//
// Contract address: 0x15c848e00610d1bd820b122b81879a66318e1c66 (BSC mainnet)
// Owner: 0x4f7219FB43289dfb58cEe363deD15CeD19670a91
// FeeRecipient (treasury): 0x9C7C1058fdc9b710f688ECb7562924D9AE771417
// Registration fee: 0.001 BNB → treasury
// Transfer fee: 0.0005 BNB → treasury

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';

/// The deployed AnetUsernameRegistry on BSC mainnet (chainId 56).
const String kUsernameRegistryAddress =
    '0x15c848e00610d1bd820b122b81879a66318e1c66';

const String _registryAbi = r'''[
  {"name":"register","type":"function","stateMutability":"payable",
   "inputs":[{"name":"name","type":"string"}],"outputs":[]},
  {"name":"transferUsername","type":"function","stateMutability":"payable",
   "inputs":[{"name":"name","type":"string"},{"name":"newOwner","type":"address"}],
   "outputs":[]},
  {"name":"release","type":"function","stateMutability":"nonpayable",
   "inputs":[{"name":"name","type":"string"}],"outputs":[]},
  {"name":"setPrimary","type":"function","stateMutability":"nonpayable",
   "inputs":[{"name":"name","type":"string"}],"outputs":[]},
  {"name":"resolve","type":"function","stateMutability":"view",
   "inputs":[{"name":"name","type":"string"}],
   "outputs":[{"name":"","type":"address"}]},
  {"name":"reverseResolve","type":"function","stateMutability":"view",
   "inputs":[{"name":"addr","type":"address"}],
   "outputs":[{"name":"","type":"string"}]},
  {"name":"isAvailable","type":"function","stateMutability":"view",
   "inputs":[{"name":"name","type":"string"}],
   "outputs":[{"name":"","type":"bool"}]},
  {"name":"registrationFee","type":"function","stateMutability":"view",
   "inputs":[],"outputs":[{"name":"","type":"uint256"}]},
  {"name":"transferFee","type":"function","stateMutability":"view",
   "inputs":[],"outputs":[{"name":"","type":"uint256"}]}
]''';

const List<String> _kBscRpcUrls = [
  'https://bsc-dataseed1.binance.org/',
  'https://bsc-dataseed2.binance.org/',
  'https://bsc-dataseed3.binance.org/',
  'https://bsc-dataseed4.binance.org/',
];

/// Regex enforced by the on-chain contract:
///   3-20 chars, first char a-z, body [a-z0-9_]
final RegExp kUsernameRegex = RegExp(r'^[a-z][a-z0-9_]{2,19}$');

/// Validates a username locally before submitting it to the chain.
/// Returns null if valid, otherwise a human-readable error.
String? validateUsername(String raw) {
  final s = raw.trim().toLowerCase();
  if (s.isEmpty) return 'Username is required';
  if (s.length < 3) return 'Min 3 characters';
  if (s.length > 20) return 'Max 20 characters';
  if (!kUsernameRegex.hasMatch(s)) {
    return 'Use a-z, 0-9, underscore. Must start with a letter.';
  }
  return null;
}

class UsernameRegistryService {
  Web3Client? _client;
  DeployedContract? _contract;

  // Tiny in-memory cache for reverseResolve so we don't spam the RPC
  // on every rebuild. Keyed by lowercase EOA address.
  final Map<String, _CachedReverse> _reverseCache = {};
  static const _cacheTtl = Duration(minutes: 5);

  Future<Web3Client> _getClient() async {
    if (_client != null) return _client!;
    Exception? lastError;
    for (final url in _kBscRpcUrls) {
      final c = Web3Client(url, http.Client());
      try {
        await c.getBlockNumber().timeout(const Duration(seconds: 5));
        _client = c;
        return c;
      } catch (e) {
        c.dispose();
        lastError = Exception('BSC RPC $url unreachable: $e');
      }
    }
    throw lastError ?? Exception('All BSC RPC endpoints unavailable');
  }

  DeployedContract _getContract() {
    return _contract ??= DeployedContract(
      ContractAbi.fromJson(_registryAbi, 'AnetUsernameRegistry'),
      EthereumAddress.fromHex(kUsernameRegistryAddress),
    );
  }

  /// Looks up the address that owns [name]. Returns null if unregistered.
  Future<String?> resolve(String name) async {
    final clean = name.trim().toLowerCase().replaceAll('@', '');
    if (validateUsername(clean) != null) return null;
    try {
      final client = await _getClient();
      final contract = _getContract();
      final fn = contract.function('resolve');
      final result = await client.call(
        contract: contract,
        function: fn,
        params: [clean],
      );
      final addr = result.first as EthereumAddress;
      final hex = addr.hexEip55;
      if (hex == '0x0000000000000000000000000000000000000000') return null;
      return hex;
    } catch (e) {
      if (kDebugMode) debugPrint('username.resolve($clean) failed: $e');
      return null;
    }
  }

  /// Returns the primary username for [address], or null if none set.
  /// Uses a 5-minute in-memory cache.
  Future<String?> reverseResolve(String address) async {
    final key = address.toLowerCase();
    final cached = _reverseCache[key];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheTtl) {
      return cached.username;
    }
    try {
      final client = await _getClient();
      final contract = _getContract();
      final fn = contract.function('reverseResolve');
      final result = await client.call(
        contract: contract,
        function: fn,
        params: [EthereumAddress.fromHex(address)],
      );
      final name = (result.first as String).trim();
      final value = name.isEmpty ? null : name;
      _reverseCache[key] = _CachedReverse(value, DateTime.now());
      return value;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('username.reverseResolve($address) failed: $e');
      }
      return null;
    }
  }

  /// True if [name] is not yet registered.
  Future<bool> isAvailable(String name) async {
    final clean = name.trim().toLowerCase().replaceAll('@', '');
    if (validateUsername(clean) != null) return false;
    try {
      final client = await _getClient();
      final contract = _getContract();
      final fn = contract.function('isAvailable');
      final result = await client.call(
        contract: contract,
        function: fn,
        params: [clean],
      );
      return result.first as bool;
    } catch (e) {
      if (kDebugMode) debugPrint('username.isAvailable($clean) failed: $e');
      return false;
    }
  }

  /// Current registration fee in wei (default 0.001 BNB).
  Future<BigInt> registrationFee() async {
    try {
      final client = await _getClient();
      final contract = _getContract();
      final fn = contract.function('registrationFee');
      final result = await client.call(
        contract: contract,
        function: fn,
        params: [],
      );
      return result.first as BigInt;
    } catch (_) {
      return BigInt.from(10).pow(15); // 0.001 BNB fallback
    }
  }

  /// Submits a register() transaction. Caller pays gas + registrationFee value.
  /// Returns the tx hash.
  Future<String> register({
    required String name,
    required EthPrivateKey credentials,
  }) async {
    final clean = name.trim().toLowerCase().replaceAll('@', '');
    final err = validateUsername(clean);
    if (err != null) throw Exception(err);
    final client = await _getClient();
    final contract = _getContract();
    final fn = contract.function('register');
    final fee = await registrationFee();

    // Live gas price with 10% buffer, 1 gwei floor
    BigInt gasWei;
    try {
      final raw = (await client.getGasPrice()).getInWei;
      final buffered = raw * BigInt.from(11) ~/ BigInt.from(10);
      final floor = BigInt.from(1000000000);
      gasWei = buffered > floor ? buffered : floor;
    } catch (_) {
      gasWei = BigInt.from(3000000000); // 3 gwei fallback
    }

    final tx = Transaction.callContract(
      contract: contract,
      function: fn,
      parameters: [clean],
      value: EtherAmount.fromBigInt(EtherUnit.wei, fee),
      gasPrice: EtherAmount.fromBigInt(EtherUnit.wei, gasWei),
      maxGas: 200000,
    );
    final hash = await client.sendTransaction(credentials, tx, chainId: 56);
    // Invalidate the reverse cache for the sender so the new name shows up.
    final senderAddr = (await credentials.extractAddress()).hexEip55
        .toLowerCase();
    _reverseCache.remove(senderAddr);
    return hash;
  }

  /// Sets [name] as the primary (reverse-resolve target) for the sender.
  /// Free transaction (gas only). Returns the tx hash.
  Future<String> setPrimary({
    required String name,
    required EthPrivateKey credentials,
  }) async {
    final clean = name.trim().toLowerCase().replaceAll('@', '');
    final err = validateUsername(clean);
    if (err != null) throw Exception(err);
    final client = await _getClient();
    final contract = _getContract();
    final fn = contract.function('setPrimary');

    BigInt gasWei;
    try {
      final raw = (await client.getGasPrice()).getInWei;
      final buffered = raw * BigInt.from(11) ~/ BigInt.from(10);
      final floor = BigInt.from(1000000000);
      gasWei = buffered > floor ? buffered : floor;
    } catch (_) {
      gasWei = BigInt.from(3000000000);
    }

    final tx = Transaction.callContract(
      contract: contract,
      function: fn,
      parameters: [clean],
      gasPrice: EtherAmount.fromBigInt(EtherUnit.wei, gasWei),
      maxGas: 80000,
    );
    final hash = await client.sendTransaction(credentials, tx, chainId: 56);
    final senderAddr = (await credentials.extractAddress()).hexEip55
        .toLowerCase();
    _reverseCache.remove(senderAddr);
    return hash;
  }

  /// Force-invalidate the cache for [address]. Call after registering or
  /// transferring a username so the UI refreshes immediately.
  void invalidateCache(String address) {
    _reverseCache.remove(address.toLowerCase());
  }

  void dispose() {
    _client?.dispose();
    _client = null;
  }
}

class _CachedReverse {
  final String? username;
  final DateTime fetchedAt;
  _CachedReverse(this.username, this.fetchedAt);
}

/// A process-wide singleton so widgets can share the cache without
/// constructing/disposing multiple clients.
final UsernameRegistryService usernameRegistry = UsernameRegistryService();
