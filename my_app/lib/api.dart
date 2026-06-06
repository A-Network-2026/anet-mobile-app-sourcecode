import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'security_service.dart';

/// Production endpoint can be overridden at build time:
/// flutter build ... --dart-define=API_BASE_URL=https://your-api.example.com
const String baseUrl = String.fromEnvironment(
  'RMP_BACKEND_URL',
  defaultValue: 'https://rmp-site.onrender.com',
);

const String aiBaseUrl = String.fromEnvironment(
  'AI_BASE_URL',
  defaultValue: 'https://anetwork-ai-backend.onrender.com',
);

const String l1BaseUrl = String.fromEnvironment(
  'L1_CHAIN_URL',
  defaultValue: 'https://explorer.a-network.net',
);

const String _apiFallbackUrlsEnv = String.fromEnvironment(
  'API_FALLBACK_URLS',
  defaultValue: '',
);

const String _l1FallbackUrlsEnv = String.fromEnvironment(
  'L1_FALLBACK_URLS',
  defaultValue: '',
);

const List<String> _fallbackApiBaseUrls = ['https://rmp-site.onrender.com'];

const List<String> _fallbackL1BaseUrls = [
  'https://explorer.a-network.net',
  'https://mainnet.explorer.a-network.net',
];

String? token;
int? currentUserId;
String? currentEmail;
String? _activeBaseUrl;

final FlutterSecureStorage _secureStorage = FlutterSecureStorage(
  aOptions: const AndroidOptions(encryptedSharedPreferences: true),
);

const String _sessionTokenKey = 'session.token';
const String _sessionUserIdKey = 'session.user_id';
const String _sessionEmailKey = 'session.email';
const String _deviceIdKey = 'device.id';
const Duration _requestTimeout = Duration(seconds: 45);
const String _aiSupportToken = String.fromEnvironment(
  'AI_SUPPORT_TOKEN',
  defaultValue: String.fromEnvironment('ADS_SUPPORT_TOKEN', defaultValue: ''),
);
const String _aiSessionTokenKey = 'ai.session.token';
String? _aiToken;
bool _secureStorageRecovered = false;
const int _maxGetBusyRetries = 3;
const int _maxMiningStartRetries = 2;
const int _retryBaseDelayMs = 500;

bool _isSecureStorageDecryptError(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains('badpaddingexception') ||
      message.contains('bad_decrypt') ||
      message.contains('javax.crypto') ||
      message.contains('storagecipher') ||
      message.contains('fluttersecurestorage');
}

Future<void> _recoverSecureStorageCorruption([SharedPreferences? prefs]) async {
  if (_secureStorageRecovered) return;
  _secureStorageRecovered = true;

  try {
    await _secureStorage.deleteAll();
  } catch (_) {
    // Ignore cleanup errors and continue with plaintext fallback prefs reset.
  }

  final localPrefs = prefs ?? await SharedPreferences.getInstance();
  await localPrefs.remove('token');
  await localPrefs.remove('userId');
  await localPrefs.remove('email');
  await localPrefs.remove('deviceId');
}

Future<String?> _safeSecureRead(String key, {SharedPreferences? prefs}) async {
  try {
    final value = await _secureStorage.read(key: key);
    // Validate token format after reading to catch corrupted decryption
    if (key == _sessionTokenKey && value != null) {
      if (!_isValidTokenFormat(value)) {
        // Token is corrupted, clear it
        await _recoverSecureStorageCorruption(prefs);
        return null;
      }
    }
    return value;
  } on PlatformException catch (e) {
    if (_isSecureStorageDecryptError(e)) {
      await _recoverSecureStorageCorruption(prefs);
      return null;
    }
    rethrow;
  } catch (e) {
    if (_isSecureStorageDecryptError(e)) {
      await _recoverSecureStorageCorruption(prefs);
      return null;
    }
    rethrow;
  }
}

/// Check if token looks like a valid JWT or session token (alphanumeric + common JWT chars)
bool _isValidTokenFormat(String token) {
  if (token.isEmpty) return false;

  // JWT tokens contain only alphanumeric, dots, hyphens, and underscores
  // Valid chars: a-z A-Z 0-9 . - _ =
  final validTokenPattern = RegExp(r'^[a-zA-Z0-9._\-=]+$');

  // Token should be at least 20 chars and at most 4KB
  if (token.length < 20 || token.length > 4096) return false;

  // Check for garbled/corrupted patterns: multiple special chars in a row, or unusual Unicode
  if (RegExp(r'[^\x20-\x7E]').hasMatch(token)) {
    // Contains non-ASCII or control characters = corrupted
    return false;
  }

  return validTokenPattern.hasMatch(token);
}

Future<void> _safeSecureWrite(
  String key,
  String value, {
  SharedPreferences? prefs,
}) async {
  try {
    await _secureStorage.write(key: key, value: value);
  } on PlatformException catch (e) {
    if (_isSecureStorageDecryptError(e)) {
      await _recoverSecureStorageCorruption(prefs);
      await _secureStorage.write(key: key, value: value);
      return;
    }
    rethrow;
  } catch (e) {
    if (_isSecureStorageDecryptError(e)) {
      await _recoverSecureStorageCorruption(prefs);
      await _secureStorage.write(key: key, value: value);
      return;
    }
    rethrow;
  }
}

Future<void> _safeSecureDelete(String key, {SharedPreferences? prefs}) async {
  try {
    await _secureStorage.delete(key: key);
  } on PlatformException catch (e) {
    if (_isSecureStorageDecryptError(e)) {
      await _recoverSecureStorageCorruption(prefs);
      return;
    }
    rethrow;
  } catch (e) {
    if (_isSecureStorageDecryptError(e)) {
      await _recoverSecureStorageCorruption(prefs);
      return;
    }
    rethrow;
  }
}

// ── Wallet seed secure storage helpers ───────────────────────────────────────
// The seed phrase is the master key to the wallet. It must never be stored
// in plaintext SharedPreferences. These helpers use flutter_secure_storage
// (backed by Android Keystore / iOS Secure Enclave) exclusively.

const String _walletSeedKey = 'wallet.seedPhrase';

/// Persist the wallet seed phrase in secure storage.
Future<void> saveWalletSeedSecure(String seed) async =>
    _safeSecureWrite(_walletSeedKey, seed);

/// Read the wallet seed phrase from secure storage. Returns null if not set.
Future<String?> loadWalletSeedSecure() async => _safeSecureRead(_walletSeedKey);

/// Delete the wallet seed phrase from secure storage.
Future<void> deleteWalletSeedSecure() async =>
    _safeSecureDelete(_walletSeedKey);

// ── DEX signing keys (cached per-wallet for offline auto-sign) ───────────────
// After the user verifies their PIN once for a given account, the derived
// signing keys are cached so subsequent swaps within the session sign fully
// offline.  Two keys are stored per wallet:
//
//   • ANET L1 signing key — secp256k1 32-byte private key used to sign DEX
//     swap action-auth blobs sent to the L1 server.  Derived as
//     SHA256(seed_phrase) (or raw bytes for evmkey-imported wallets).
//
//   • EVM signing key — secp256k1 32-byte private key used to sign bridge
//     transactions broadcast to Ethereum/BSC/etc.  Derived via BIP32/BIP44
//     `m/44'/60'/0'/0/0` from the same mnemonic (or raw bytes for evmkey
//     imports — in that case it equals the ANET key).
//
// Both entries are scoped by the active ANET wallet address so multiple
// accounts on the same device never collide.  The value is the 32-byte
// private key encoded as 64 hex chars.
String _dexAnetSigningKeyStorageKey(String wallet) =>
    'dex.anet_signing_key.${wallet.trim().toUpperCase()}';

String _dexEvmSigningKeyStorageKey(String wallet) =>
    'dex.evm_signing_key.${wallet.trim().toUpperCase()}';

/// Persist the ANET L1 signing key (64-char hex) for [wallet] in secure storage.
Future<void> saveDexAnetSigningKeySecure(String wallet, String hexKey) async =>
    _safeSecureWrite(_dexAnetSigningKeyStorageKey(wallet), hexKey);

/// Read the cached ANET L1 signing key for [wallet].  Null if not yet cached.
Future<String?> loadDexAnetSigningKeySecure(String wallet) async =>
    _safeSecureRead(_dexAnetSigningKeyStorageKey(wallet));

/// Remove the cached ANET L1 signing key for [wallet] (e.g. on logout).
Future<void> deleteDexAnetSigningKeySecure(String wallet) async =>
    _safeSecureDelete(_dexAnetSigningKeyStorageKey(wallet));

/// Persist the EVM bridge signing key (64-char hex) for [wallet] in secure storage.
Future<void> saveDexEvmSigningKeySecure(String wallet, String hexKey) async =>
    _safeSecureWrite(_dexEvmSigningKeyStorageKey(wallet), hexKey);

/// Read the cached EVM bridge signing key for [wallet].  Null if not yet cached.
Future<String?> loadDexEvmSigningKeySecure(String wallet) async =>
    _safeSecureRead(_dexEvmSigningKeyStorageKey(wallet));

/// Remove the cached EVM bridge signing key for [wallet] (e.g. on logout).
Future<void> deleteDexEvmSigningKeySecure(String wallet) async =>
    _safeSecureDelete(_dexEvmSigningKeyStorageKey(wallet));

/// Remove every cached DEX key associated with [wallet].  Call on logout or
/// when the user removes the account from the device.
Future<void> deleteAllDexKeysForWallet(String wallet) async {
  await Future.wait([
    deleteDexAnetSigningKeySecure(wallet),
    deleteDexEvmSigningKeySecure(wallet),
  ]);
}

// ── EVM bridge key (dedicated per-device BSC wallet) ─────────────────────────
const String _evmBridgePrivKeyStorageKey = 'evm_bridge.privkey';

/// Persist the EVM bridge private key (64-char hex) in secure storage.
Future<void> saveEvmBridgePrivKeySecure(String hexKey) async =>
    _safeSecureWrite(_evmBridgePrivKeyStorageKey, hexKey);

/// Read the EVM bridge private key from secure storage. Returns null if not set.
Future<String?> loadEvmBridgePrivKeySecure() async =>
    _safeSecureRead(_evmBridgePrivKeyStorageKey);

/// One-time migration: moves the seed from plaintext SharedPreferences into
/// secure storage, then removes the plaintext copy.  Safe to call on every
/// app start — it is a no-op if the seed is already in secure storage.
Future<void> migrateWalletSeedToSecureStorage(SharedPreferences prefs) async {
  final existing = await loadWalletSeedSecure();
  if (existing != null && existing.isNotEmpty) return; // already migrated

  final legacy = (prefs.getString('createdSeedPhrase') ?? '').trim();
  if (legacy.isEmpty ||
      legacy == 'Hidden for security' ||
      legacy == 'No wallet created yet') {
    return;
  }

  await saveWalletSeedSecure(legacy);
  await prefs.remove('createdSeedPhrase');
}

bool _isAllowedDevelopmentEndpoint(Uri uri) {
  return uri.scheme == 'http' &&
      (uri.host == 'localhost' ||
          uri.host == '127.0.0.1' ||
          uri.host == '10.0.2.2');
}

List<String> _resolveApiBaseUrls() {
  final resolved = <String>[];

  void addUrl(String candidate) {
    final normalized = candidate.trim();
    if (normalized.isEmpty || resolved.contains(normalized)) {
      return;
    }
    resolved.add(normalized);
  }

  addUrl(baseUrl);
  for (final fallbackUrl in _apiFallbackUrlsEnv.split(',')) {
    addUrl(fallbackUrl);
  }
  for (final fallbackUrl in _fallbackApiBaseUrls) {
    addUrl(fallbackUrl);
  }

  return resolved;
}

List<String> _resolveL1BaseUrls() {
  final resolved = <String>[];

  void addUrl(String candidate) {
    final normalized = candidate.trim();
    if (normalized.isEmpty || resolved.contains(normalized)) {
      return;
    }
    resolved.add(normalized);
  }

  addUrl(l1BaseUrl);
  for (final fallbackUrl in _l1FallbackUrlsEnv.split(',')) {
    addUrl(fallbackUrl);
  }
  for (final fallbackUrl in _fallbackL1BaseUrls) {
    addUrl(fallbackUrl);
  }

  return resolved;
}

void _ensureSecureBaseUrls() {
  for (final apiBaseUrl in _resolveApiBaseUrls()) {
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null) {
      throw SecurityException(
        'Invalid API base URL configured for this build.',
      );
    }

    if (uri.scheme != 'https' && !_isAllowedDevelopmentEndpoint(uri)) {
      throw SecurityException(
        'Blocked insecure API endpoint. Release builds must use HTTPS.',
      );
    }
  }
}

void _ensureSecureL1BaseUrls() {
  for (final endpoint in _resolveL1BaseUrls()) {
    final uri = Uri.tryParse(endpoint);
    if (uri == null) {
      throw SecurityException('Invalid L1 endpoint configured for this build.');
    }

    if (uri.scheme != 'https' && !_isAllowedDevelopmentEndpoint(uri)) {
      throw SecurityException(
        'Blocked insecure L1 endpoint. Release builds must use HTTPS.',
      );
    }
  }
}

bool _isRetriableNetworkError(Object error) {
  if (error is http.ClientException) {
    return true;
  }

  final message = error.toString().toLowerCase();
  return message.contains('socketexception') ||
      message.contains('failed host lookup') ||
      message.contains('connection closed before full header was received') ||
      message.contains('connection refused') ||
      message.contains('network is unreachable') ||
      message.contains('no address associated with hostname');
}

Exception _buildApiUnavailableException(String path) {
  final normalizedPath = path.toLowerCase();
  if (normalizedPath.contains('/auth/login') ||
      normalizedPath.contains('/auth/register')) {
    return Exception(
      'Unable to reach login server. Check your connection and try again.',
    );
  }

  return Exception(
    'Unable to reach the A Network server. Check your internet and try again.',
  );
}

bool _looksUnauthorizedResponseBody(String body) {
  final normalized = body.toLowerCase();
  return normalized.contains('unauthorized') ||
      normalized.contains('invalid token') ||
      normalized.contains('token expired') ||
      normalized.contains('jwt expired') ||
      normalized.contains('invalid session') ||
      normalized.contains('session expired');
}

Future<void> _handleExpiredSessionIfNeeded({
  required bool authRequired,
  required http.Response response,
}) async {
  if (!authRequired) {
    return;
  }

  if (response.statusCode == 401) {
    await logout();
    throw Exception('Session expired. Please login again.');
  }

  if (response.statusCode == 403 &&
      _looksUnauthorizedResponseBody(response.body)) {
    await logout();
    throw Exception('Session expired. Please login again.');
  }
}

bool _isRetriableHttpStatusCode(int statusCode) {
  return statusCode == 408 ||
      statusCode == 425 ||
      statusCode == 429 ||
      statusCode == 500 ||
      statusCode == 502 ||
      statusCode == 503 ||
      statusCode == 504;
}

Duration _computeRetryDelay(int attempt) {
  final safeAttempt = max(0, attempt);
  final backoffMs = _retryBaseDelayMs * (1 << safeAttempt);
  final jitterMs = Random().nextInt(250);
  return Duration(milliseconds: min(5000, backoffMs + jitterMs));
}

Future<http.Response> _sendRequestWithFallback(
  String path,
  Future<http.Response> Function(Uri uri) sender, {
  bool retryBusyResponses = false,
  int maxBusyRetries = 0,
}) async {
  _ensureSecureBaseUrls();

  Object? lastTransportError;
  final apiBaseUrls = _resolveApiBaseUrls();
  for (var index = 0; index < apiBaseUrls.length; index++) {
    final apiBaseUrl = apiBaseUrls[index];
    final uri = Uri.parse('$apiBaseUrl$path');
    var attempt = 0;

    while (true) {
      try {
        final response = await sender(uri).timeout(_requestTimeout);

        if (retryBusyResponses &&
            _isRetriableHttpStatusCode(response.statusCode) &&
            attempt < maxBusyRetries) {
          await Future.delayed(_computeRetryDelay(attempt));
          attempt += 1;
          continue;
        }

        _activeBaseUrl = apiBaseUrl;
        return response;
      } on TimeoutException catch (error) {
        if (retryBusyResponses && attempt < maxBusyRetries) {
          await Future.delayed(_computeRetryDelay(attempt));
          attempt += 1;
          continue;
        }

        lastTransportError = error;
        if (index == apiBaseUrls.length - 1) {
          throw _buildApiUnavailableException(path);
        }
        break;
      } on Exception catch (error) {
        if (!_isRetriableNetworkError(error)) {
          rethrow;
        }

        if (retryBusyResponses && attempt < maxBusyRetries) {
          await Future.delayed(_computeRetryDelay(attempt));
          attempt += 1;
          continue;
        }

        lastTransportError = error;
        if (index == apiBaseUrls.length - 1) {
          throw _buildApiUnavailableException(path);
        }
        break;
      }
    }
  }

  if (lastTransportError != null) {
    throw _buildApiUnavailableException(path);
  }

  throw Exception('Failed to send request to $path.');
}

Future<Map<String, String>> _buildHeaders({
  bool authRequired = false,
  bool jsonContent = false,
  Map<String, String>? extraHeaders,
}) async {
  await SecurityService.ensureInitialized();
  final headers = <String, String>{
    ...SecurityService.buildSecurityHeaders(),
    'x-device-id': await getOrCreateDeviceId(),
  };

  if (jsonContent) {
    headers['Content-Type'] = 'application/json';
  }

  if (authRequired) {
    if (token == null || token!.isEmpty) {
      throw Exception('No session token. Please login again.');
    }
    // Validate token format to catch corrupted storage
    if (!_isValidTokenFormat(token!)) {
      // Token is corrupted, clear it and ask user to login again
      await logout();
      throw Exception('Session token corrupted. Please login again.');
    }
    headers['Authorization'] = 'Bearer $token';
  }

  if (extraHeaders != null) {
    headers.addAll(extraHeaders);
  }

  return headers;
}

Future<http.Response> _postRequest(
  String path, {
  Map<String, dynamic>? body,
  bool authRequired = false,
  bool sensitive = false,
  Map<String, String>? extraHeaders,
}) async {
  _ensureSecureBaseUrls();
  await SecurityService.ensureInitialized();
  if (sensitive) {
    SecurityService.ensureSensitiveOperationAllowed(path);
  }

  final headers = await _buildHeaders(
    authRequired: authRequired,
    jsonContent: true,
    extraHeaders: extraHeaders,
  );

  final response = await _sendRequestWithFallback(
    path,
    (uri) => http.post(
      uri,
      headers: headers,
      body: jsonEncode(body ?? <String, dynamic>{}),
    ),
  );

  await _handleExpiredSessionIfNeeded(
    authRequired: authRequired,
    response: response,
  );

  return response;
}

Future<http.Response> _getRequest(
  String path, {
  bool authRequired = false,
  bool sensitive = false,
  Map<String, String>? extraHeaders,
}) async {
  _ensureSecureBaseUrls();
  await SecurityService.ensureInitialized();
  if (sensitive) {
    SecurityService.ensureSensitiveOperationAllowed(path);
  }

  final headers = await _buildHeaders(
    authRequired: authRequired,
    extraHeaders: extraHeaders,
  );

  final response = await _sendRequestWithFallback(
    path,
    (uri) => http.get(uri, headers: headers),
    retryBusyResponses: true,
    maxBusyRetries: _maxGetBusyRetries,
  );

  await _handleExpiredSessionIfNeeded(
    authRequired: authRequired,
    response: response,
  );

  return response;
}

Future<http.Response> _sendL1RequestWithFallback(
  String path,
  Future<http.Response> Function(Uri uri) sender,
) async {
  _ensureSecureL1BaseUrls();

  final endpoints = _resolveL1BaseUrls();
  for (var index = 0; index < endpoints.length; index++) {
    final endpoint = endpoints[index];
    final normalizedBase = endpoint.trim().replaceAll(RegExp(r'/+$'), '');
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$normalizedBase$normalizedPath');

    try {
      final response = await sender(uri).timeout(_requestTimeout);
      if (response.statusCode >= 500 && index < endpoints.length - 1) {
        continue;
      }

      return response;
    } on TimeoutException {
      if (index == endpoints.length - 1) {
        rethrow;
      }
    } on Exception catch (error) {
      if (!_isRetriableNetworkError(error) || index == endpoints.length - 1) {
        rethrow;
      }
    }
  }

  throw Exception('Failed to send L1 request to $path.');
}

Future<http.Response> _getL1Request(String path) async {
  await SecurityService.ensureInitialized();
  return _sendL1RequestWithFallback(
    path,
    (uri) => http.get(uri, headers: SecurityService.buildSecurityHeaders()),
  );
}

Future<http.Response> _postL1Request(
  String path,
  Map<String, dynamic> body,
) async {
  await SecurityService.ensureInitialized();
  return _sendL1RequestWithFallback(
    path,
    (uri) => http.post(
      uri,
      headers: {
        ...SecurityService.buildSecurityHeaders(),
        'content-type': 'application/json',
      },
      body: jsonEncode(body),
    ),
  );
}

Future<void> _persistCurrentEmail(String email) async {
  final normalized = email.trim().toLowerCase();
  currentEmail = normalized;
  final prefs = await SharedPreferences.getInstance();
  await _safeSecureWrite(_sessionEmailKey, normalized, prefs: prefs);
  await prefs.remove('email');
}

/// =========================
/// 🔐 SESSION
/// =========================

Future<void> loadSession() async {
  final prefs = await SharedPreferences.getInstance();

  var loadedToken =
      await _safeSecureRead(_sessionTokenKey, prefs: prefs) ??
      prefs.getString('token');

  // Double-check token format in case plaintext backup is corrupted
  if (loadedToken != null && !_isValidTokenFormat(loadedToken)) {
    loadedToken = null;
    await prefs.remove('token');
  }

  token = loadedToken;

  final storedUserId = await _safeSecureRead(_sessionUserIdKey, prefs: prefs);
  final rawPrefsUserId = prefs.get('userId');
  int? prefsUserId;
  if (rawPrefsUserId is int) {
    prefsUserId = rawPrefsUserId;
  } else if (rawPrefsUserId is num) {
    prefsUserId = rawPrefsUserId.toInt();
  } else if (rawPrefsUserId is String) {
    prefsUserId = int.tryParse(rawPrefsUserId.trim());
    if (prefsUserId == null) {
      await prefs.remove('userId');
    }
  }
  currentUserId = int.tryParse(storedUserId ?? '') ?? prefsUserId;

  currentEmail =
      await _safeSecureRead(_sessionEmailKey, prefs: prefs) ??
      prefs.getString('email');
  _aiToken = await _safeSecureRead(_aiSessionTokenKey, prefs: prefs);

  if (token != null && token!.isNotEmpty) {
    await _safeSecureWrite(_sessionTokenKey, token!, prefs: prefs);
    await prefs.remove('token');
  }
  if (currentUserId != null) {
    await _safeSecureWrite(
      _sessionUserIdKey,
      currentUserId.toString(),
      prefs: prefs,
    );
    await prefs.remove('userId');
  }
  if (currentEmail != null && currentEmail!.isNotEmpty) {
    await _safeSecureWrite(_sessionEmailKey, currentEmail!, prefs: prefs);
    await prefs.remove('email');
  }
}

Future<void> saveSession(String t, int userId, {String? email}) async {
  final prefs = await SharedPreferences.getInstance();

  await _safeSecureWrite(_sessionTokenKey, t, prefs: prefs);
  await _safeSecureWrite(_sessionUserIdKey, userId.toString(), prefs: prefs);
  await prefs.remove('token');
  await prefs.remove('userId');
  if (email != null && email.trim().isNotEmpty) {
    await _persistCurrentEmail(email);
  }

  token = t;
  currentUserId = userId;
  if (email != null && email.trim().isNotEmpty) {
    currentEmail = email.trim().toLowerCase();
  }
}

int _parseUserId(dynamic rawUserId) {
  if (rawUserId is int) {
    return rawUserId;
  }
  if (rawUserId is num) {
    return rawUserId.toInt();
  }
  if (rawUserId is String) {
    final parsed = int.tryParse(rawUserId.trim());
    if (parsed != null) {
      return parsed;
    }
  }

  throw Exception('Invalid user ID returned by server.');
}

Future<void> _saveSessionFromResponse(Map<String, dynamic> data) async {
  final sessionToken = data['token']?.toString();
  if (sessionToken == null || sessionToken.isEmpty) {
    return;
  }

  final user = data['user'];
  if (user is! Map) {
    throw Exception('Invalid user payload returned by server.');
  }

  final userMap = Map<String, dynamic>.from(user);
  await saveSession(
    sessionToken,
    _parseUserId(userMap['id']),
    email: userMap['email']?.toString(),
  );
}

Future<void> logout() async {
  final prefs = await SharedPreferences.getInstance();
  await _safeSecureDelete(_sessionTokenKey, prefs: prefs);
  await _safeSecureDelete(_sessionUserIdKey, prefs: prefs);
  await _safeSecureDelete(_sessionEmailKey, prefs: prefs);
  await _safeSecureDelete(_aiSessionTokenKey, prefs: prefs);
  await prefs.remove('token');
  await prefs.remove('userId');
  await prefs.remove('email');

  token = null;
  currentUserId = null;
  currentEmail = null;
  _aiToken = null;
}

Map<String, dynamic> _decodeJsonMapSafely(String rawBody) {
  try {
    final decoded = jsonDecode(rawBody);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } catch (_) {
    // Return an empty map when upstream returns non-JSON payloads.
  }

  return <String, dynamic>{};
}

String _extractAiErrorMessage(Map<String, dynamic> data, String fallback) {
  final detail = data['detail']?.toString().trim();
  if (detail != null && detail.isNotEmpty) {
    return detail;
  }

  final error = data['error']?.toString().trim();
  if (error != null && error.isNotEmpty) {
    return error;
  }

  final message = data['message']?.toString().trim();
  if (message != null && message.isNotEmpty) {
    return message;
  }

  return fallback;
}

Exception _buildAiUnavailableException() {
  return Exception(
    'Unable to reach AI server. Check your internet and try again.',
  );
}

Future<http.Response> _sendAiAuthorizedRequest(
  Future<http.Response> Function(String aiToken) sender,
) async {
  if (_aiToken == null || _aiToken!.isEmpty) {
    throw Exception('AI session is not ready');
  }

  Future<http.Response> attempt(String aiToken) async {
    try {
      return await sender(aiToken).timeout(_requestTimeout);
    } on TimeoutException {
      throw _buildAiUnavailableException();
    } on Exception catch (error) {
      if (_isRetriableNetworkError(error)) {
        throw _buildAiUnavailableException();
      }
      rethrow;
    }
  }

  var response = await attempt(_aiToken!);
  if (response.statusCode == 401 ||
      (response.statusCode == 403 &&
          _looksUnauthorizedResponseBody(response.body))) {
    final prefs = await SharedPreferences.getInstance();
    _aiToken = null;
    await _safeSecureDelete(_aiSessionTokenKey, prefs: prefs);

    final refreshed = await ensureAiSession();
    if (!refreshed || _aiToken == null || _aiToken!.isEmpty) {
      throw Exception('AI session expired. Please try again.');
    }

    response = await attempt(_aiToken!);
  }

  return response;
}

Future<bool> ensureAiSession({String? migrationWallet}) async {
  if (_aiToken != null && _aiToken!.isNotEmpty) {
    return true;
  }
  if (_aiSupportToken.isEmpty) {
    return false;
  }

  final headers = {
    'Content-Type': 'application/json',
    'x-support-token': _aiSupportToken,
  };

  http.Response response;
  try {
    response = await http
        .post(
          Uri.parse('$aiBaseUrl/api/v1/auth/app-session'),
          headers: headers,
          body: jsonEncode({
            'app_user_id': currentUserId,
            'email': currentEmail,
            if (migrationWallet != null && migrationWallet.trim().isNotEmpty)
              'migration_wallet': migrationWallet.trim(),
          }),
        )
        .timeout(_requestTimeout);
  } on TimeoutException {
    throw _buildAiUnavailableException();
  } on Exception catch (error) {
    if (_isRetriableNetworkError(error)) {
      throw _buildAiUnavailableException();
    }
    rethrow;
  }

  final data = _decodeJsonMapSafely(response.body);
  if (response.statusCode != 200) {
    final errorMessage = _extractAiErrorMessage(
      data,
      'Failed to create AI session',
    );
    final normalizedMessage = errorMessage.toLowerCase();

    // Treat support-token/auth and missing route cases as "AI not enabled"
    // so production builds can keep running without hard-failing the screen.
    if (response.statusCode == 401 ||
        response.statusCode == 403 ||
        response.statusCode == 404 ||
        normalizedMessage.contains('support token') ||
        normalizedMessage.contains('unauthorized') ||
        normalizedMessage.contains('not found')) {
      final prefs = await SharedPreferences.getInstance();
      _aiToken = null;
      await _safeSecureDelete(_aiSessionTokenKey, prefs: prefs);
      return false;
    }

    throw Exception(errorMessage);
  }

  final sessionToken = data['access_token']?.toString() ?? '';
  if (sessionToken.isEmpty) {
    throw Exception('AI session token missing from response');
  }

  final prefs = await SharedPreferences.getInstance();
  await _safeSecureWrite(_aiSessionTokenKey, sessionToken, prefs: prefs);
  _aiToken = sessionToken;
  return true;
}

Future<Map<String, dynamic>> sendAiChatMessage(
  String message, {
  String? conversationId,
}) async {
  Map<String, dynamic>? preparedPrompt;
  try {
    preparedPrompt = await prepareAiPrompt(message, languageCode: 'en');
  } catch (_) {
    preparedPrompt = null;
  }

  final promptPayload = preparedPrompt == null
      ? null
      : Map<String, dynamic>.from(
          preparedPrompt['prompt'] as Map? ?? const <String, dynamic>{},
        );

  final response = await _sendAiAuthorizedRequest(
    (aiToken) => http.post(
      Uri.parse('$aiBaseUrl/api/v1/chat/message'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $aiToken',
      },
      body: jsonEncode({
        'message': message,
        if (conversationId != null && conversationId.isNotEmpty)
          'conversation_id': conversationId,
        if (promptPayload != null)
          'system_instruction': promptPayload['systemInstruction'],
        if (promptPayload != null)
          'language_profile': promptPayload['languageProfile'],
        if (promptPayload != null)
          'training_examples': promptPayload['trainingExamples'],
        if (promptPayload != null) 'memory_context': promptPayload['context'],
        if (promptPayload != null) 'owner': promptPayload['owner'],
      }),
    ),
  );

  final data = _decodeJsonMapSafely(response.body);
  if (response.statusCode != 200) {
    throw Exception(_extractAiErrorMessage(data, 'AI chat request failed'));
  }
  return data;
}

Future<Map<String, dynamic>> getAiProfile() async {
  final response = await _sendAiAuthorizedRequest(
    (aiToken) => http.get(
      Uri.parse('$aiBaseUrl/api/v1/profile/me'),
      headers: {'Authorization': 'Bearer $aiToken'},
    ),
  );

  final data = _decodeJsonMapSafely(response.body);
  if (response.statusCode != 200) {
    throw Exception(_extractAiErrorMessage(data, 'Failed to load AI profile'));
  }
  return data;
}

Future<Map<String, dynamic>> addAiMemoryText(
  String text, {
  String sourceType = 'manual',
  String? sourceRef,
}) async {
  try {
    final res = await _postRequest(
      '/chatbot/memory',
      authRequired: true,
      sensitive: true,
      body: {
        'category': sourceType,
        'memoryText': text,
        'metadata': {
          if (sourceRef != null && sourceRef.trim().isNotEmpty)
            'source_ref': sourceRef.trim(),
        },
      },
    );

    final data = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    if (res.statusCode == 200) {
      return data;
    }
  } catch (_) {
    // Fall back to legacy AI backend below.
  }

  final response = await _sendAiAuthorizedRequest(
    (aiToken) => http.post(
      Uri.parse('$aiBaseUrl/api/v1/memory/text'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $aiToken',
      },
      body: jsonEncode({
        'text': text,
        'source_type': sourceType,
        if (sourceRef != null && sourceRef.trim().isNotEmpty)
          'source_ref': sourceRef.trim(),
      }),
    ),
  );

  final data = _decodeJsonMapSafely(response.body);
  if (response.statusCode != 200) {
    throw Exception(_extractAiErrorMessage(data, 'Failed to save memory text'));
  }
  return data;
}

Future<Map<String, dynamic>> addAiTrainingExample(
  String prompt,
  String idealResponse,
) async {
  try {
    final res = await _postRequest(
      '/chatbot/train',
      authRequired: true,
      sensitive: true,
      body: {
        'languageCode': 'en',
        'inputText': prompt,
        'idealResponse': idealResponse,
      },
    );

    final data = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    if (res.statusCode == 200) {
      return data;
    }
  } catch (_) {
    // Fall back to legacy AI backend below.
  }

  final response = await _sendAiAuthorizedRequest(
    (aiToken) => http.post(
      Uri.parse('$aiBaseUrl/api/v1/memory/training-example'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $aiToken',
      },
      body: jsonEncode({'prompt': prompt, 'ideal_response': idealResponse}),
    ),
  );

  final data = _decodeJsonMapSafely(response.body);
  if (response.statusCode != 200) {
    throw Exception(
      _extractAiErrorMessage(data, 'Failed to save training example'),
    );
  }
  return data;
}

Future<Map<String, dynamic>> getAiOwnerProfile() async {
  final res = await _getRequest('/chatbot/owner-profile', authRequired: true);
  final data = _decodeJsonMapSafely(res.body);
  if (res.statusCode == 404) {
    return <String, dynamic>{};
  }
  if (res.statusCode != 200) {
    throw Exception(
      data['error'] ?? data['message'] ?? 'Failed to load AI owner profile',
    );
  }
  return data;
}

Future<Map<String, dynamic>> getAiLanguageProfile() async {
  final res = await _getRequest(
    '/chatbot/language-profile',
    authRequired: true,
  );
  final data = _decodeJsonMapSafely(res.body);
  if (res.statusCode == 404) {
    return <String, dynamic>{
      'profile': <String, dynamic>{
        'preferred_language': 'en',
        'auto_detect': false,
        'allowed_languages': <String>['en'],
      },
    };
  }
  if (res.statusCode != 200) {
    throw Exception(
      data['error'] ?? data['message'] ?? 'Failed to load AI language profile',
    );
  }
  return data;
}

Future<Map<String, dynamic>> setAiLanguageProfile({
  String preferredLanguage = 'en',
  bool autoDetect = false,
  List<String> allowedLanguages = const <String>[],
  String? responseStyle,
}) async {
  final res = await _postRequest(
    '/chatbot/language-profile',
    authRequired: true,
    sensitive: true,
    body: {
      'preferredLanguage': preferredLanguage,
      'autoDetect': autoDetect,
      'allowedLanguages': allowedLanguages,
      if (responseStyle != null && responseStyle.trim().isNotEmpty)
        'responseStyle': responseStyle.trim(),
    },
  );

  final data = _decodeJsonMapSafely(res.body);
  if (res.statusCode == 404) {
    return <String, dynamic>{
      'profile': <String, dynamic>{
        'preferred_language': preferredLanguage,
        'auto_detect': autoDetect,
        'allowed_languages': allowedLanguages.isEmpty
            ? <String>['en']
            : List<String>.from(allowedLanguages),
        if (responseStyle != null && responseStyle.trim().isNotEmpty)
          'response_style': responseStyle.trim(),
      },
    };
  }
  if (res.statusCode != 200) {
    throw Exception(
      data['error'] ??
          data['message'] ??
          'Failed to update AI language profile',
    );
  }
  return data;
}

Future<void> ensureAiLanguageDefaults() async {
  try {
    final current = await getAiLanguageProfile();
    final profile = (current['profile'] is Map)
        ? Map<String, dynamic>.from(current['profile'] as Map)
        : <String, dynamic>{};

    final preferredLanguage = (profile['preferred_language'] ?? '')
        .toString()
        .toLowerCase();
    final autoDetect = profile['auto_detect'] == true;

    if (preferredLanguage != 'en' || autoDetect) {
      await setAiLanguageProfile(preferredLanguage: 'en', autoDetect: false);
    }
  } catch (_) {
    // Best effort only.
  }
}

Future<Map<String, dynamic>> prepareAiPrompt(
  String query, {
  String languageCode = 'en',
}) async {
  final res = await _postRequest(
    '/chatbot/prepare-prompt',
    authRequired: true,
    sensitive: true,
    body: {'query': query, 'languageCode': languageCode},
  );

  final data = _decodeJsonMapSafely(res.body);
  if (res.statusCode == 404) {
    return <String, dynamic>{'prompt': <String, dynamic>{}};
  }
  if (res.statusCode != 200) {
    throw Exception(
      data['error'] ?? data['message'] ?? 'Failed to prepare AI prompt',
    );
  }
  return data;
}

Future<Map<String, dynamic>> uploadAiMemoryFile({
  required String filename,
  String? filePath,
  Uint8List? bytes,
}) async {
  if (_aiToken == null || _aiToken!.isEmpty) {
    throw Exception('AI session is not ready');
  }
  if ((filePath == null || filePath.isEmpty) && bytes == null) {
    throw Exception('No file content available for upload');
  }

  final request = http.MultipartRequest(
    'POST',
    Uri.parse('$aiBaseUrl/api/v1/memory/upload'),
  )..headers['Authorization'] = 'Bearer $_aiToken';

  if (bytes != null) {
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );
  } else {
    request.files.add(
      await http.MultipartFile.fromPath('file', filePath!, filename: filename),
    );
  }

  final streamedResponse = await request.send().timeout(_requestTimeout);
  final response = await http.Response.fromStream(streamedResponse);
  final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);

  if (response.statusCode != 200) {
    throw Exception(data['detail'] ?? 'Failed to upload training file');
  }
  return data;
}

Future<Map<String, dynamic>> sendAiDeepResearchMessage(
  String message, {
  String? conversationId,
}) async {
  final response = await _sendAiAuthorizedRequest(
    (aiToken) => http.post(
      Uri.parse('$aiBaseUrl/api/v1/chat/research'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $aiToken',
      },
      body: jsonEncode({
        'message': message,
        if (conversationId != null && conversationId.isNotEmpty)
          'conversation_id': conversationId,
      }),
    ),
  );

  final data = _decodeJsonMapSafely(response.body);
  if (response.statusCode != 200) {
    throw Exception(
      _extractAiErrorMessage(data, 'AI deep research request failed'),
    );
  }
  return data;
}

/// =========================
/// 🔐 AUTH
/// =========================

Future<Map<String, dynamic>> register(
  String email,
  String password,
  String deviceId, {
  String? referralCode,
}) async {
  await SecurityService.ensureInitialized();
  final res = await _postRequest(
    '/auth/register',
    sensitive: true,
    body: {
      'email': email,
      'password': password,
      'deviceId': deviceId,
      'deviceFingerprint': SecurityService.assessment.deviceFingerprint,
      'referralCode': referralCode,
    },
  );

  final data = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  await _saveSessionFromResponse(data);

  return data;
}

Future<Map<String, dynamic>> verifyEmailOtp(String email, String code) async {
  final res = await _postRequest(
    '/auth/verify-email-otp',
    sensitive: true,
    body: {'email': email, 'code': code},
  );

  final data = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  await _saveSessionFromResponse(data);

  return data;
}

Future<Map<String, dynamic>> resendEmailOtp(String email) async {
  final res = await _postRequest(
    '/auth/resend-email-otp',
    sensitive: true,
    body: {'email': email},
  );

  return jsonDecode(res.body);
}

Future<Map<String, dynamic>> requestAccountRestoreOtp(String email) async {
  final res = await _postRequest(
    '/auth/account-restore/request',
    sensitive: true,
    body: {'email': email},
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode == 404) {
    throw Exception(
      "Account restore endpoint not found on server. Please restart or redeploy the backend with the new restore routes.",
    );
  }
  if (res.statusCode == 200) {
    return data;
  }

  throw Exception(
    data["message"] ?? data["error"] ?? "Failed to send restore code",
  );
}

Future<Map<String, dynamic>> confirmAccountRestore(
  String email,
  String code,
) async {
  final res = await _postRequest(
    '/auth/account-restore/confirm',
    sensitive: true,
    body: {'email': email, 'code': code},
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode == 404) {
    throw Exception(
      "Account restore endpoint not found on server. Please restart or redeploy the backend with the new restore routes.",
    );
  }
  if (res.statusCode == 200) {
    return data;
  }

  throw Exception(
    data["message"] ?? data["error"] ?? "Failed to restore account",
  );
}

Future<Map<String, dynamic>> requestPasswordResetOtp(String email) async {
  final res = await _postRequest(
    '/auth/forgot-password/request',
    sensitive: true,
    body: {'email': email},
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(data['error'] ?? 'Failed to send reset code');
  }
  return data;
}

Future<Map<String, dynamic>> confirmPasswordReset(
  String email,
  String code,
  String newPassword,
) async {
  final res = await _postRequest(
    '/auth/forgot-password/confirm',
    sensitive: true,
    body: {'email': email, 'code': code, 'newPassword': newPassword},
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(data['error'] ?? 'Failed to reset password');
  }
  return data;
}

Future<Map<String, dynamic>> login(
  String email,
  String password,
  String deviceId,
) async {
  await SecurityService.ensureInitialized();
  final res = await _postRequest(
    '/auth/login',
    sensitive: true,
    body: {
      'email': email,
      'password': password,
      'deviceId': deviceId,
      'deviceFingerprint': SecurityService.assessment.deviceFingerprint,
    },
  );

  final data = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  await _saveSessionFromResponse(data);

  return data;
}

Future<Map<String, dynamic>> verifyLoginOtp(
  String email,
  String otp,
  String deviceId,
) async {
  await SecurityService.ensureInitialized();
  final res = await _postRequest(
    '/auth/verify-login-otp',
    sensitive: true,
    body: {
      'email': email,
      'otp': otp,
      'deviceId': deviceId,
      'deviceFingerprint': SecurityService.assessment.deviceFingerprint,
    },
  );

  final data = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  await _saveSessionFromResponse(data);

  return data;
}

Future<Map<String, dynamic>> resendLoginOtp(
  String email,
  String deviceId,
) async {
  await SecurityService.ensureInitialized();
  final res = await _postRequest(
    '/auth/resend-login-otp',
    sensitive: true,
    body: {
      'email': email,
      'deviceId': deviceId,
      'deviceFingerprint': SecurityService.assessment.deviceFingerprint,
    },
  );

  return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
}

/// =========================
/// ⛏ MINING (FIXED)
/// =========================

Future<Map<String, dynamic>> startMiningAPI() async {
  http.Response res;
  Map<String, dynamic> data;

  var attempt = 0;
  while (true) {
    res = await _postRequest(
      '/mining/start',
      authRequired: true,
      sensitive: true,
    );

    data = jsonDecode(res.body) as Map<String, dynamic>;

    if (_isRetriableHttpStatusCode(res.statusCode) &&
        attempt < _maxMiningStartRetries) {
      await Future.delayed(_computeRetryDelay(attempt));
      attempt += 1;
      continue;
    }

    break;
  }

  if (res.statusCode != 200) {
    throw Exception("Start mining failed: ${res.body}");
  }

  if (data["error"] != null) {
    throw Exception(data["error"].toString());
  }

  if (data["status"] != "started") {
    throw Exception("Unexpected mining response: ${res.body}");
  }

  return data;
}

Future<Map<String, dynamic>> completeMiningAPI() async {
  final res = await _postRequest(
    '/mining/complete',
    authRequired: true,
    sensitive: true,
  );

  if (res.statusCode != 200) {
    throw Exception("Complete mining failed: ${res.body}");
  }

  return jsonDecode(res.body);
}

/// Submit a decentralized mining proof to the L1 chain (Phase 5).
Future<Map<String, dynamic>> submitMiningProofToL1({
  required String miner,
  required int nonce,
  required String chainId,
  required String proofHash,
  required int difficulty,
  required String signature,
}) async {
  final payload = {
    'miner': miner,
    'nonce': nonce,
    'timestamp': DateTime.now().toUtc().toIso8601String(),
    'chain_id': chainId,
    'proof_hash': proofHash,
    'difficulty': difficulty,
    'signature': signature,
  };

  final res = await _postL1Request('/mining/submit-proof', payload);

  if (res.statusCode != 200) {
    throw Exception(
      "Submit mining proof failed: ${res.statusCode} ${res.body}",
    );
  }

  return jsonDecode(res.body);
}

Future<Map<String, dynamic>> getMyProfile() async {
  final res = await _getRequest(
    '/auth/me',
    authRequired: true,
    sensitive: true,
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(data["error"] ?? "Failed to load profile");
  }

  if (data["user"]?["email"] != null) {
    await _persistCurrentEmail(data['user']['email'].toString());
  }

  return data;
}

Future<Map<String, dynamic>> getMyWalletAPI() async {
  final res = await _getRequest(
    '/auth/wallet',
    authRequired: true,
    sensitive: true,
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(data["error"] ?? "Failed to load wallet");
  }

  return data;
}

Future<Map<String, dynamic>> createWalletAPI({String? migrationAddress}) async {
  final res = await _postRequest(
    '/auth/wallet/create',
    authRequired: true,
    sensitive: true,
    body: {
      if (migrationAddress != null && migrationAddress.trim().isNotEmpty)
        'migrationAddress': migrationAddress.trim(),
    },
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(data["error"] ?? "Failed to create wallet");
  }

  return data;
}

Future<Map<String, dynamic>> setWalletPinAPI(String pin) async {
  final res = await _postRequest(
    '/auth/wallet/pin/set',
    authRequired: true,
    sensitive: true,
    body: {'pin': pin},
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(data["message"] ?? data["error"] ?? "Failed to set PIN");
  }
  return data;
}

Future<Map<String, dynamic>> changeWalletPinAPI(
  String currentPin,
  String newPin,
) async {
  final res = await _postRequest(
    '/auth/wallet/pin/change',
    authRequired: true,
    sensitive: true,
    body: {'currentPin': currentPin, 'newPin': newPin},
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(data["message"] ?? data["error"] ?? "Failed to change PIN");
  }
  return data;
}

Future<Map<String, dynamic>> verifyWalletPinAPI(String pin) async {
  final res = await _postRequest(
    '/auth/wallet/pin/verify',
    authRequired: true,
    sensitive: true,
    body: {'pin': pin},
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(data["message"] ?? data["error"] ?? "Failed to verify PIN");
  }
  return data;
}

Future<Map<String, dynamic>> requestSeedOtpAPI(String pin) async {
  final res = await _postRequest(
    '/auth/wallet/seed/request-otp',
    authRequired: true,
    sensitive: true,
    body: {'pin': pin},
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(
      data["message"] ?? data["error"] ?? "Failed to request OTP",
    );
  }
  return data;
}

/// Thrown by [revealSeedForDexAPI] when the server has no usable seed for the
/// account (corrupt or missing). Carries the human-readable [message] and the
/// backend flags so callers can route the user to the wallet Reveal / recovery
/// screen instead of dead-ending on a snackbar.
class SeedUnavailableException implements Exception {
  SeedUnavailableException(
    this.message, {
    this.serverSeedCorrupt = false,
    this.localSeedFallback = false,
  });
  final String message;
  final bool serverSeedCorrupt;
  final bool localSeedFallback;
  @override
  String toString() => message;
}

/// Reveals the wallet seed phrase for DEX signing purposes using PIN only (no OTP).
/// The seed is returned over HTTPS and must only be held in memory briefly for signing.
Future<Map<String, dynamic>> revealSeedForDexAPI(String pin) async {
  final res = await _postRequest(
    '/auth/wallet/seed/reveal-for-dex',
    authRequired: true,
    sensitive: true,
    body: {'pin': pin},
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    // The seed-unavailable case (server seed corrupt / missing) is recoverable
    // from the wallet Reveal screen, so surface it as a typed exception the UI
    // can route on rather than a plain error.
    if (data['localSeedFallback'] == true ||
        data['serverSeedCorrupt'] == true) {
      throw SeedUnavailableException(
        (data['message'] ??
                data['error'] ??
                'Wallet seed is not available on the server.')
            .toString(),
        serverSeedCorrupt: data['serverSeedCorrupt'] == true,
        localSeedFallback: data['localSeedFallback'] == true,
      );
    }
    throw Exception(
      data["message"] ?? data["error"] ?? "Failed to retrieve seed for DEX",
    );
  }
  return data;
}

/// Runs the chain's commit-reveal /wallet/migrate-legacy flow server-side
/// using the user's PIN-decrypted seed. After success the user's on-chain
/// wallet_address becomes the secp256k1 address that DEX / Bridge action
/// signatures actually recover to, which is the only way the chain will
/// accept `dex_swap` and `bridge_burn` for legacy-address users.
///
/// Idempotent — safe to call on every DEX/Bridge entry; returns
///   { success, status: 'migrated'|'already_migrated'|'synced_from_chain',
///     legacy_address, secp_address, wallet_address, ... }
Future<Map<String, dynamic>> migrateWalletToSecpAPI(String pin) async {
  final res = await _postRequest(
    '/auth/wallet/migrate-to-secp',
    authRequired: true,
    sensitive: true,
    body: {'pin': pin},
  );
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(
      data['message'] ?? data['error'] ?? 'Wallet migration failed',
    );
  }
  return data;
}

/// Server-side action signer. Returns `{ success, wallet_address, auth }`
/// where `auth` is a ready-to-submit ActionAuth signed by the user's
/// secp256k1 key for the requested actionType.
///
/// Use this instead of on-device signing whenever you want the chain
/// signature to come from the canonical server-side derivation path
/// (eliminates "signature recovery does not match action wallet" errors).
Future<Map<String, dynamic>> signActionViaServerAPI({
  required String pin,
  required String actionType,
  Map<String, dynamic>? payload,
}) async {
  final res = await _postRequest(
    '/auth/wallet/sign-action',
    authRequired: true,
    sensitive: true,
    body: {'pin': pin, 'actionType': actionType, 'payload': ?payload},
  );
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(
      data['message'] ?? data['error'] ?? 'Failed to sign action',
    );
  }
  return data;
}

// ─────────────────────────────────────────────────────────────────────
// Swap Waitlist (Phase 1 — off-chain queue for users awaiting activation
// or pending bridge credit). The backend auto-marks intents as 'ready'
// once the wallet becomes activated; the mobile DEX then offers a
// one-tap confirm to execute. Cancellation is currently free; once the
// fee wallet is configured server-side, the DELETE call returns 402
// requiring a BSC tx hash that paid the BNB cancel fee.
// ─────────────────────────────────────────────────────────────────────

Future<Map<String, dynamic>> createWaitlistIntentAPI({
  required String intentType, // 'swap' | 'wrap' | 'unwrap' | 'bridge_out'
  required String fromToken, // ANET | WANET | USDC | USDT | BNB
  required String toToken,
  required String fromAmount, // integer in smallest units, as string
  String toMinAmount = '0',
  int expiresInDays = 30,
}) async {
  final res = await _postRequest(
    '/waitlist/create',
    authRequired: true,
    body: {
      'intentType': intentType,
      'fromToken': fromToken,
      'toToken': toToken,
      'fromAmount': fromAmount,
      'toMinAmount': toMinAmount,
      'expiresInDays': expiresInDays,
    },
  );
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(
      data['message'] ?? data['error'] ?? 'Waitlist create failed',
    );
  }
  return data;
}

Future<Map<String, dynamic>> listMyWaitlistIntentsAPI() async {
  final res = await _getRequest('/waitlist/mine', authRequired: true);
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(data['message'] ?? data['error'] ?? 'Waitlist list failed');
  }
  return data;
}

Future<Map<String, dynamic>> cancelWaitlistIntentAPI(
  int id, {
  String? feeTxHash,
}) async {
  final body = <String, dynamic>{};
  if (feeTxHash != null && feeTxHash.isNotEmpty) body['feeTxHash'] = feeTxHash;
  // Server exposes both DELETE /waitlist/:id and POST /waitlist/:id/cancel
  // — we use the POST mirror so we can reuse the existing _postRequest
  // helper (auth headers, base-URL fallback, retries).
  final res = await _postRequest(
    '/waitlist/$id/cancel',
    authRequired: true,
    body: body,
  );
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(
      data['message'] ?? data['error'] ?? 'Waitlist cancel failed',
    );
  }
  return data;
}

Future<Map<String, dynamic>> revealSeedAPI(String pin, {String? otp}) async {
  final body = <String, dynamic>{"pin": pin};
  if (otp != null && otp.trim().isNotEmpty) {
    body["otp"] = otp.trim();
  }

  final res = await _postRequest(
    '/auth/wallet/seed/reveal',
    authRequired: true,
    sensitive: true,
    body: body,
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(
      data["message"] ?? data["error"] ?? "Failed to reveal seed",
    );
  }
  return data;
}

/// Pushes a locally-stored seed phrase back to the server when the server
/// copy is unreadable (e.g. encrypted with a key that was lost during a
/// deploy window). Server verifies the seed derives to the user's existing
/// wallet address before accepting; will NOT overwrite a healthy server seed.
Future<Map<String, dynamic>> backupSeedAPI(
  String pin,
  String seedPhrase,
) async {
  final res = await _postRequest(
    '/auth/wallet/seed/backup',
    authRequired: true,
    sensitive: true,
    body: {'pin': pin, 'seedPhrase': seedPhrase},
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(
      data["message"] ?? data["error"] ?? "Failed to back up seed",
    );
  }
  return data;
}

/// Last-resort recovery for users whose server seed is unreadable AND who
/// have no local seed on the device. Provisions a fresh wallet (new seed +
/// address) on the SAME account, preserving balance and history. The server
/// refuses if the existing seed still decrypts, or if the wallet is on-chain
/// activated. Returns the new one-time seed phrase the user must write down.
Future<Map<String, dynamic>> recoverNewWalletAPI(String pin) async {
  final res = await _postRequest(
    '/auth/wallet/recover-new',
    authRequired: true,
    sensitive: true,
    body: {'pin': pin, 'acknowledgeNewWallet': true},
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(
      data["message"] ?? data["error"] ?? "Failed to recover wallet",
    );
  }
  return data;
}

Future<Map<String, dynamic>> requestPinResetAPI(String email) async {
  final res = await _postRequest(
    '/auth/wallet/pin/forgot/request',
    sensitive: true,
    body: {'email': email.trim()},
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(
      data["message"] ?? data["error"] ?? "Failed to request PIN reset",
    );
  }
  return data;
}

Future<Map<String, dynamic>> confirmPinResetAPI(
  String email,
  String otp,
  String newPin,
) async {
  final res = await _postRequest(
    '/auth/wallet/pin/forgot/confirm',
    sensitive: true,
    body: {'email': email.trim(), 'otp': otp.trim(), 'newPin': newPin},
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(data["message"] ?? data["error"] ?? "Failed to reset PIN");
  }
  return data;
}

Future<Map<String, dynamic>> requestAccountDeleteAPI({String? pin}) async {
  final res = await _postRequest(
    '/auth/account/delete',
    authRequired: true,
    sensitive: true,
    body: {if (pin?.trim().isNotEmpty ?? false) 'pin': pin!.trim()},
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(
      data["message"] ?? data["error"] ?? "Failed to schedule account deletion",
    );
  }
  return data;
}

Future<Map<String, dynamic>> updateMigrationWalletAPI(
  String migrationAddress,
) async {
  final res = await _postRequest(
    '/auth/wallet/migration-address',
    authRequired: true,
    sensitive: true,
    body: {'migrationAddress': migrationAddress.trim()},
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(data["error"] ?? "Failed to save migration wallet address");
  }

  return data;
}

Future<Map<String, dynamic>> getWalletCoinHistoryAPI({
  int limit = 30,
  int offset = 0,
}) async {
  final uri = '/auth/wallet/history?limit=$limit&offset=$offset';
  final res = await _getRequest(uri, authRequired: true, sensitive: true);

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode == 404) {
    return {
      'success': true,
      'history': const <Map<String, dynamic>>[],
      'count': 0,
      'legacyFallback': true,
    };
  }
  if (res.statusCode != 200) {
    throw Exception(
      data["message"] ?? data["error"] ?? "Failed to load wallet coin history",
    );
  }

  return data;
}

Future<Map<String, dynamic>> createWalletTransferIntentAPI({
  required String pin,
  required String toAddress,
  required String amountAnet,
}) async {
  final res = await _postRequest(
    '/auth/wallet/transfer-intent',
    authRequired: true,
    sensitive: true,
    body: {
      'pin': pin.trim(),
      'toAddress': toAddress.trim(),
      'amountAnet': amountAnet.trim(),
    },
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(
      data["message"] ?? data["error"] ?? "Failed to prepare transfer",
    );
  }

  return data;
}

Future<Map<String, dynamic>> getL1AccountAPI(String walletAddress) async {
  final address = walletAddress.trim().toUpperCase();
  if (address.isEmpty) {
    throw Exception('Wallet address is required');
  }

  final res = await _getL1Request('/accounts/${Uri.encodeComponent(address)}');
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(data['error'] ?? 'Failed to load L1 account');
  }
  return data;
}

Future<Map<String, dynamic>> submitL1TransactionAPI(
  Map<String, dynamic> signedTx,
) async {
  final res = await _postL1Request('/transactions', signedTx);
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200 && res.statusCode != 202) {
    throw Exception(data['error'] ?? 'Failed to submit L1 transaction');
  }
  return data;
}

// ─── DEX (Native In-App) ────────────────────────────────────────────────────

Future<List<Map<String, dynamic>>> getDexPoolsAPI() async {
  final res = await _getL1Request('/dex/pools');
  if (res.statusCode != 200) {
    throw Exception('Failed to load DEX pools (${res.statusCode})');
  }
  final data = jsonDecode(res.body);
  if (data is List) {
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  return [];
}

Future<Map<String, dynamic>> getDexSwapQuoteAPI({
  required String tokenSymbol,
  required int amountIn,
  required bool anetToToken,
}) async {
  final res = await _postL1Request('/dex/swap/quote', {
    'token_symbol': tokenSymbol,
    'amount_in': amountIn,
    'anet_to_token': anetToToken,
  });
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(data['error'] ?? 'Failed to get swap quote');
  }
  return data;
}

Future<Map<String, dynamic>> executeDexSwapAPI({
  required String trader,
  required String tokenSymbol,
  required int amountIn,
  required bool anetToToken,
  required Map<String, dynamic> auth,
  int? minAmountOut,
}) async {
  final body = <String, dynamic>{
    'trader': trader,
    'token_symbol': tokenSymbol,
    'amount_in': amountIn,
    'anet_to_token': anetToToken,
    'auth': auth,
    'min_amount_out': ?minAmountOut,
  };
  final res = await _postL1Request('/dex/swap/execute', body);
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(data['error'] ?? 'Swap failed');
  }
  return data;
}

/// Returns the latest committed block info { block_height, hash } or null.
Future<Map<String, dynamic>?> getLatestBlockInfoAPI() async {
  try {
    final res = await _getL1Request('/blocks?limit=1');
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body);
    if (data is List && data.isNotEmpty) {
      final block = data.first as Map<String, dynamic>;
      return {
        'block_height': block['block_height'],
        'hash': block['hash'] as String? ?? '',
      };
    }
  } catch (_) {}
  return null;
}

// ─── EVM Bridge endpoints ────────────────────────────────────────────────────

const String _piBackendUrl = String.fromEnvironment(
  'PI_BACKEND_URL',
  defaultValue: 'https://pi-backend-q2ye.onrender.com',
);

/// Notifies the backend that an EVM bridge TX was broadcast.
Future<void> bridgeEvmNotifyAPI({
  required String txHash,
  required int chainId,
  required String fromAddress,
  required String anetRecipient,
  required String amount,
  required String tokenSymbol,
}) async {
  try {
    await http
        .post(
          Uri.parse('$_piBackendUrl/api/bridge/evm/notify'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'txHash': txHash,
            'chainId': chainId,
            'fromAddress': fromAddress,
            'anetRecipient': anetRecipient,
            'amount': amount,
            'tokenSymbol': tokenSymbol,
          }),
        )
        .timeout(_requestTimeout);
  } catch (_) {}
}

/// Polls the backend for EVM bridge processing status.
Future<Map<String, dynamic>> bridgeEvmStatusAPI(String txHash) async {
  final res = await http
      .get(
        Uri.parse('$_piBackendUrl/api/bridge/evm/status/$txHash'),
        headers: {'Content-Type': 'application/json'},
      )
      .timeout(_requestTimeout);
  if (res.statusCode == 200) {
    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }
  return {'processed': false};
}

/// Fetches EVM bridge history for a given EVM address.
Future<List<Map<String, dynamic>>> bridgeEvmHistoryAPI(
  String evmAddress,
) async {
  try {
    final res = await http
        .get(
          Uri.parse('$_piBackendUrl/api/bridge/evm/history/$evmAddress'),
          headers: {'Content-Type': 'application/json'},
        )
        .timeout(_requestTimeout);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final swaps = data['swaps'];
      if (swaps is List) {
        return swaps.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }
  } catch (_) {}
  return [];
}

// ────────────────────────────────────────────────────────────────────────────

Future<Map<String, dynamic>> claimAnetAPI() async {
  final res = await _postRequest(
    '/mining/claim',
    authRequired: true,
    sensitive: true,
    body: const <String, dynamic>{},
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(data['error'] ?? data['message'] ?? 'Failed to claim ANET');
  }
  if (data['error'] != null) {
    throw Exception(data['error'].toString());
  }
  return data;
}

Future<Map<String, dynamic>> getMyNftsAPI() async {
  final res = await _getRequest(
    '/wallet/nft/mine',
    authRequired: true,
    sensitive: true,
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(data['error'] ?? 'Failed to load NFT collection');
  }
  return data;
}

Future<Map<String, dynamic>> getWalletNftStatusAPI() async {
  final res = await _getRequest(
    '/wallet/nft/status',
    authRequired: true,
    sensitive: true,
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(data['error'] ?? 'Failed to load NFT identity status');
  }
  return data;
}

Future<Map<String, dynamic>> getPublicNftProfileAPI(
  String walletAddress,
) async {
  final address = walletAddress.trim().toUpperCase();
  if (address.isEmpty || address.length < 20) {
    throw Exception('Invalid wallet address');
  }

  final res = await _getRequest(
    '/wallet/nft/public/$address',
    authRequired: false,
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200 && res.statusCode != 404) {
    throw Exception(data['error'] ?? 'Failed to load public profile');
  }
  if (res.statusCode == 404) {
    throw Exception(data['error'] ?? 'Profile not found');
  }
  return data;
}

Future<Map<String, dynamic>> createWalletNftProfileAPI({
  required String nftName,
  required String poweredBy,
  required String primaryColor,
  required String secondaryColor,
  required String glowColor,
  required String backgroundStyle,
  required String frameStyle,
  required double hologramLevel,
  bool useAsAvatar = true,
  Map<String, dynamic>? metadata,
}) async {
  final res = await _postRequest(
    '/wallet/nft/create',
    authRequired: true,
    sensitive: true,
    body: {
      'nftName': nftName.trim(),
      'poweredBy': poweredBy.trim(),
      'primaryColor': primaryColor.trim(),
      'secondaryColor': secondaryColor.trim(),
      'glowColor': glowColor.trim(),
      'backgroundStyle': backgroundStyle.trim(),
      'frameStyle': frameStyle.trim(),
      'hologramLevel': hologramLevel,
      'useAsAvatar': useAsAvatar,
      'metadata': ?metadata,
    },
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200 && res.statusCode != 201) {
    throw Exception(data['error'] ?? 'Failed to create NFT identity');
  }
  return data;
}

Future<Map<String, dynamic>> updateWalletNftProfileAPI({
  required String nftName,
  required String poweredBy,
  required String primaryColor,
  required String secondaryColor,
  required String glowColor,
  required String backgroundStyle,
  required String frameStyle,
  required double hologramLevel,
  bool useAsAvatar = true,
  Map<String, dynamic>? metadata,
}) async {
  final res = await _postRequest(
    '/wallet/nft/update',
    authRequired: true,
    sensitive: true,
    body: {
      'nftName': nftName.trim(),
      'poweredBy': poweredBy.trim(),
      'primaryColor': primaryColor.trim(),
      'secondaryColor': secondaryColor.trim(),
      'glowColor': glowColor.trim(),
      'backgroundStyle': backgroundStyle.trim(),
      'frameStyle': frameStyle.trim(),
      'hologramLevel': hologramLevel,
      'useAsAvatar': useAsAvatar,
      'metadata': ?metadata,
    },
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(data['error'] ?? 'Failed to update NFT identity');
  }
  return data;
}

Future<Map<String, dynamic>> mintNftAPI({
  required String title,
  required String description,
  String? imageUrl,
  Map<String, dynamic>? metadata,
}) async {
  final res = await _postRequest(
    '/wallet/nft/mint',
    authRequired: true,
    sensitive: true,
    body: {
      'title': title.trim(),
      'description': description.trim(),
      if (imageUrl != null && imageUrl.trim().isNotEmpty)
        'imageUrl': imageUrl.trim(),
      'metadata': ?metadata,
    },
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200 && res.statusCode != 201) {
    throw Exception(data['error'] ?? 'Failed to mint NFT');
  }
  return data;
}

Future<Map<String, dynamic>> changeEmailAPI(
  String newEmail,
  String password,
) async {
  final res = await _postRequest(
    '/auth/change-email',
    authRequired: true,
    sensitive: true,
    body: {'newEmail': newEmail, 'password': password},
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(data["error"] ?? "Failed to change email");
  }

  if (data["user"]?["email"] != null) {
    await _persistCurrentEmail(data['user']['email'].toString());
  }

  return data;
}

Future<Map<String, dynamic>> changePasswordAPI(
  String currentPassword,
  String newPassword,
) async {
  final res = await _postRequest(
    '/auth/change-password',
    authRequired: true,
    sensitive: true,
    body: {'currentPassword': currentPassword, 'newPassword': newPassword},
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(data["error"] ?? "Failed to change password");
  }

  return data;
}

Future<Map<String, dynamic>> getMiningStatus() async {
  final res = await _getRequest(
    '/mining/status/$currentUserId',
    authRequired: true,
    sensitive: true,
  );

  if (res.statusCode != 200) {
    throw Exception("Status failed: ${res.body}");
  }

  if (res.body.trim().isEmpty) {
    throw Exception("Status failed: empty response from server");
  }

  final data = jsonDecode(res.body) as Map<String, dynamic>;

  if (data["isMining"] == true) {
    try {
      await sendMiningHeartbeat();
    } catch (_) {
      // Keep the mining UI responsive even if heartbeat transport fails once.
    }
  }

  return data;
}

Future<Map<String, dynamic>> sendMiningHeartbeat() async {
  final res = await _postRequest(
    '/mining/heartbeat',
    authRequired: true,
    sensitive: true,
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(data["error"] ?? "Heartbeat failed");
  }

  return data;
}

Future<Map<String, dynamic>> getMiningSessionsAPI({
  int limit = 50,
  int offset = 0,
}) async {
  final res = await _getRequest(
    '/mining/sessions?limit=$limit&offset=$offset',
    authRequired: true,
    sensitive: true,
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode == 404) {
    return {
      'profile': const <String, dynamic>{},
      'sessions': const <dynamic>[],
      'total': 0,
    };
  }
  if (res.statusCode != 200) {
    throw Exception(data['error'] ?? 'Failed to load mining sessions');
  }

  return data;
}

Future<Map<String, dynamic>> getAdminMiningUsersAPI({
  int limit = 50,
  int offset = 0,
  int sessionLimit = 10,
}) async {
  final res = await _getRequest(
    '/admin/miners?limit=$limit&offset=$offset&sessionLimit=$sessionLimit',
    authRequired: true,
    sensitive: true,
  );

  final data = _decodeJsonMapSafely(res.body);
  if (res.statusCode == 404 || res.statusCode == 403) {
    return {
      'miners': const <dynamic>[],
      'summary': const <String, dynamic>{
        'total_miners': 0,
        'active_miners': 0,
        'total_recorded_sessions': 0,
      },
      'limit': limit,
      'offset': offset,
      'session_limit': sessionLimit,
    };
  }
  if (res.statusCode != 200) {
    throw Exception(data['error'] ?? 'Failed to load mining roster');
  }

  return data;
}

// recordAdImpressionAPI removed — Google AdSense/AdMob fully removed from app.

/// =========================
/// 🌐 NETWORK
/// =========================

Future<Map<String, dynamic>> getNetworkStats() async {
  final res = await _getRequest('/stats/network');

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  int readInt(List<String> keys, [int fallback = 0]) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value.toString());
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  double readDouble(List<String> keys, [double fallback = 0.0]) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value.toString());
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  final antsPerAnet = readInt(['antsPerAnet'], 100000000);
  final totalAnts = readInt(['totalANTSAccumulated', 'totalMinedAnts']);
  final totalAnetClaimed = readDouble([
    'totalANETClaimed',
    'totalAnetDistributed',
    'totalMined',
  ]);
  final currentRewardPerSession = readDouble([
    'currentRewardPerSession',
    'rewardPerSession',
    'currentRate',
    'reverseEraMiningReward',
    'bitcoinEraReward',
  ]);
  final nextRewardPerSession = readDouble([
    'nextRewardPerSession',
    'currentRewardPerSession',
    'rewardPerSession',
    'currentRate',
  ], currentRewardPerSession);
  final totalSessions = readInt(['totalSessions']);
  final remainingSessionsToHalving = readInt([
    'remainingSessionsToHalving',
    'remainingQualifiedUsersToNextLevel',
  ]);
  final totalUsers = readInt(['totalUsers', 'total_users']);
  final totalActiveMiners = readInt([
    'totalActiveMiners',
    'activeMiners',
  ], totalUsers);
  final usersOnline = readInt([
    'usersOnline',
    'onlineUsers',
  ], totalActiveMiners);
  final totalEligibleUsers = readInt([
    'totalEligibleUsers',
    'eligibleUsers',
    'qualifiedUsers',
  ]);
  final halvingStage = readInt(['halvingStage', 'halvingCount']);
  final nextHalvingProgress = readDouble([
    'nextHalvingProgress',
    'nextHalvingSessionsProgress',
    'nextHalvingUsersProgress',
  ]);
  final rewardPerSessionAnts = readInt([
    'currentRewardPerSessionAnts',
    'rewardPerSessionAnts',
  ], (currentRewardPerSession * antsPerAnet).round());
  final nextRewardPerSessionAnts = readInt([
    'nextRewardPerSessionAnts',
  ], (nextRewardPerSession * antsPerAnet).round());
  final halvingEligibilitySessions = readInt([
    'requiredSessionsForEligibility',
    'halvingEligibilitySessions',
  ], 1000);

  return {
    ...data,
    'totalRegisteredAccounts': readInt(['totalRegisteredAccounts'], totalUsers),
    'totalRealMiners': readInt(['totalRealMiners'], totalActiveMiners),
    'totalUsers': totalUsers,
    'usersOnline': usersOnline,
    'totalActiveMiners': totalActiveMiners,
    'totalMined': totalAnts / antsPerAnet,
    'totalMinedAnts': totalAnts,
    'rewardPerSession': currentRewardPerSession,
    'currentRate': currentRewardPerSession,
    'rewardPerSessionAnts': rewardPerSessionAnts,
    'nextRewardPerSession': nextRewardPerSession,
    'nextRewardPerSessionAnts': nextRewardPerSessionAnts,
    'halvingCount': halvingStage,
    'eligibleUsers': totalEligibleUsers,
    'qualifiedUsers': totalEligibleUsers,
    'maxHalvingLevel': readInt(['maxHalvingStage'], 3),
    'halvingEligibilitySessions': halvingEligibilitySessions,
    'halvingRuleSessions': halvingEligibilitySessions,
    'halvingRuleUsers': 0,
    'remainingQualifiedUsersToNextLevel': remainingSessionsToHalving,
    'nextLevelSessionsTarget': totalSessions + remainingSessionsToHalving,
    'nextHalvingUsersProgress': nextHalvingProgress,
    'nextHalvingSessionsProgress': nextHalvingProgress,
    'presenceWindowMinutes': readInt(['presenceWindowMinutes'], 5),
    'bitcoinEraReward': currentRewardPerSession,
    'reverseEraMiningReward': currentRewardPerSession,
    'totalAnetDistributed': totalAnetClaimed,
  };
}

Future<Map<String, dynamic>> getCountryUsersStats() async {
  final res = await _getRequest('/stats/countries');

  if (res.statusCode != 200) {
    throw Exception("Country stats failed: ${res.body}");
  }

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (data["error"] != null) {
    throw Exception(data["error"].toString());
  }
  return data;
}

Future<Map<String, dynamic>> getOnChainWalletData(String walletAddress) async {
  final res = await _getRequest('/stats/onchain/$walletAddress');

  if (res.statusCode != 200) {
    throw Exception("On-chain request failed: ${res.body}");
  }

  return jsonDecode(res.body);
}

Future<Map<String, dynamic>> getEvmTokenBalanceAPI({
  required String walletAddress,
  required String contractAddress,
  required String network,
  int decimals = 18,
}) async {
  final uri = Uri(
    path: '/stats/evm/token-balance',
    queryParameters: {
      'wallet': walletAddress.trim(),
      'contract': contractAddress.trim(),
      'network': network,
      'decimals': decimals.toString(),
    },
  ).toString();

  final res = await _getRequest(uri);
  if (res.statusCode != 200) {
    throw Exception("EVM token balance request failed: ${res.body}");
  }

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (data['error'] != null) {
    throw Exception(data['error'].toString());
  }

  return data;
}

/// =========================
/// 🏆 LEADERBOARD
/// =========================

Future<List<dynamic>> getLeaderboard() async {
  final res = await _getRequest('/leaderboard/top');

  return jsonDecode(res.body);
}

Future<Map<String, dynamic>> getUserRank() async {
  final res = await _getRequest('/leaderboard/rank/$currentUserId');
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode == 200 && data['rank'] != null) {
    return data;
  }

  return {
    'id': currentUserId,
    'rank': null,
    'balance': 0,
    'ant_balance': 0,
    'error': data['error'] ?? 'Leaderboard temporarily unavailable',
  };
}

Future<Map<String, dynamic>> getMyReferralStats() async {
  final res = await _getRequest(
    '/auth/referrals/me',
    authRequired: true,
    sensitive: true,
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(data["error"] ?? "Failed to load referral stats");
  }

  return data;
}

Future<Map<String, dynamic>> getReferralCommunityChat({
  int limit = 60,
  String? scope,
}) async {
  final safeLimit = limit.clamp(20, 100);
  final safeScope = scope == 'my-colony' || scope == 'upline-colony'
      ? '&scope=$scope'
      : '';
  final res = await _getRequest(
    '/auth/community-chat?limit=$safeLimit$safeScope',
    authRequired: true,
    sensitive: true,
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode == 200) {
    return data;
  }

  throw Exception(data['error'] ?? 'Failed to load community chat');
}

Future<Map<String, dynamic>> sendReferralCommunityMessage(
  String message, {
  String? scope,
}) async {
  final res = await _postRequest(
    '/auth/community-chat',
    authRequired: true,
    sensitive: true,
    body: {
      'message': message,
      if (scope == 'my-colony' || scope == 'upline-colony') 'scope': scope,
    },
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode == 201) {
    return data;
  }

  throw Exception(data['error'] ?? 'Failed to send community message');
}

Future<Map<String, dynamic>> updateReferralCommunityRoomName(
  String roomName, {
  String? scope,
}) async {
  final res = await _postRequest(
    '/auth/community-chat/room-name',
    authRequired: true,
    sensitive: true,
    body: {
      'roomName': roomName,
      if (scope == 'my-colony' || scope == 'upline-colony') 'scope': scope,
    },
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode == 200) {
    return data;
  }

  throw Exception(data['error'] ?? 'Failed to update room name');
}

Future<Map<String, dynamic>> claimAntCode(
  String antCode, {
  String? scope,
}) async {
  final res = await _postRequest(
    '/auth/ant-code/claim',
    authRequired: true,
    sensitive: true,
    body: {
      'antCode': antCode.trim(),
      if (scope == 'my-colony' || scope == 'upline-colony') 'scope': scope,
    },
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode == 200) {
    return data;
  }

  throw Exception(data['error'] ?? 'Failed to claim Ant Code');
}

Future<Map<String, dynamic>> getUserDashboardAPI() async {
  final res = await _getRequest(
    '/user/dashboard',
    authRequired: true,
    sensitive: true,
  );

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(
      data["message"] ?? data["error"] ?? "Failed to load dashboard",
    );
  }

  return data;
}

Future<String> getOrCreateDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  final existing =
      await _safeSecureRead(_deviceIdKey, prefs: prefs) ??
      prefs.getString('deviceId');
  if (existing != null && existing.trim().isNotEmpty) {
    await _safeSecureWrite(_deviceIdKey, existing, prefs: prefs);
    await prefs.remove('deviceId');
    return existing;
  }

  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rng = Random.secure();
  final suffix = List.generate(
    24,
    (_) => chars[rng.nextInt(chars.length)],
  ).join();
  final generated = 'dev_${DateTime.now().millisecondsSinceEpoch}_$suffix';
  await _safeSecureWrite(_deviceIdKey, generated, prefs: prefs);
  await prefs.remove('deviceId');
  return generated;
}

/// Fetch a short-lived JWT for Chatbase identity verification.
/// Returns null if the user is not logged in or the backend is unavailable.
Future<String?> getChatbotToken() async {
  if (token == null) return null;
  try {
    final res = await _getRequest('/chatbot/token', authRequired: true);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['token'] as String?;
    }
  } catch (_) {}
  return null;
}

/// Build the full URL for the backend-hosted Chatbase widget page.
String getChatbotWidgetUrl({String? identityToken}) {
  final resolvedBaseUrl = _activeBaseUrl ?? _resolveApiBaseUrls().first;
  final base = '$resolvedBaseUrl/chatbot/widget';
  if (identityToken != null && identityToken.isNotEmpty) {
    return '$base?token=${Uri.encodeComponent(identityToken)}';
  }
  return base;
}
