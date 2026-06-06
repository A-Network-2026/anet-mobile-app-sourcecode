import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'ads/unity_ads_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:app_links/app_links.dart';
import 'package:bip32/bip32.dart' as bip32;
import 'package:bip39/bip39.dart' as bip39;
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
// google_mobile_ads removed (Google AdSense/AdMob ban). Axon ads TBD.
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pointycastle/digests/ripemd160.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'api.dart';
import 'ads_service.dart';
import 'ai_support_page.dart';
import 'bridge_burn_page.dart';
import 'dex_page.dart';
import 'treasury_dashboard_page.dart';
import 'evm_wallet_page.dart';
import 'username_registry_service.dart';
import 'nft_identity_screen.dart';
import 'public_nft_profile_page.dart';
import 'notification_service.dart';
import 'referral_chat_page.dart';
import 'security_service.dart';

String _normalizeToBrowsableUrl(String input) {
  final raw = input.trim();
  if (raw.isEmpty) {
    return 'https://a-network.net';
  }

  if (raw.startsWith('intent://')) {
    final fallbackMatch = RegExp(
      r'S\\.browser_fallback_url=([^;]+)',
    ).firstMatch(raw);
    if (fallbackMatch != null) {
      final fallback = Uri.decodeComponent(fallbackMatch.group(1) ?? '');
      if (fallback.startsWith('http://') || fallback.startsWith('https://')) {
        return fallback;
      }
    }

    final packageMatch = RegExp(r'package=([^;]+)').firstMatch(raw);
    final packageName = packageMatch?.group(1) ?? '';
    if (packageName == 'com.twitter.android') {
      return 'https://x.com';
    }
    if (packageName.isNotEmpty) {
      return 'https://play.google.com/store/apps/details?id=$packageName';
    }
  }

  if (raw.startsWith('market://')) {
    final uri = Uri.tryParse(raw);
    final packageId = uri?.queryParameters['id'] ?? '';
    if (packageId == 'com.twitter.android') {
      return 'https://x.com';
    }
    if (packageId.isNotEmpty) {
      return 'https://play.google.com/store/apps/details?id=$packageId';
    }
    return 'https://play.google.com/store';
  }

  if (raw.startsWith('tg://')) {
    final uri = Uri.tryParse(raw);
    final host = (uri?.host ?? '').toLowerCase();
    if (host == 'resolve') {
      final domain = uri?.queryParameters['domain'] ?? '';
      final post = uri?.queryParameters['post'] ?? '';
      if (domain.isNotEmpty && post.isNotEmpty) {
        return 'https://t.me/$domain/$post';
      }
      if (domain.isNotEmpty) {
        return 'https://t.me/$domain';
      }
    }
    if (host == 'join') {
      final invite = uri?.queryParameters['invite'] ?? '';
      if (invite.isNotEmpty) {
        return 'https://t.me/+${Uri.encodeComponent(invite)}';
      }
    }
    return 'https://t.me';
  }

  if (raw.startsWith('twitter://') || raw.startsWith('x://')) {
    final uri = Uri.tryParse(raw);
    final screenName = uri?.queryParameters['screen_name'] ?? '';
    final statusId = uri?.queryParameters['id'] ?? '';
    if (screenName.isNotEmpty) {
      return 'https://x.com/$screenName';
    }
    if (statusId.isNotEmpty) {
      return 'https://x.com/i/status/$statusId';
    }
    return 'https://x.com';
  }

  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    return raw;
  }

  if (raw.contains('.') && !raw.contains(' ')) {
    return 'https://$raw';
  }

  final query = Uri.encodeQueryComponent(raw);
  return 'https://www.google.com/search?q=$query';
}

bool _isWalletDeepLinkScheme(String scheme) {
  return scheme == 'anetwork' || scheme == 'anet' || scheme == 'app';
}

Uri _normalizeWalletDeepLinkUri(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'anet') {
    return uri;
  }

  final host = uri.host.toLowerCase();
  if (host == 'dex' || host == 'invite') {
    final action = (uri.queryParameters['action'] ?? 'connect').trim();
    return Uri.parse(
      'anetwork://invite',
    ).replace(queryParameters: {'action': action.isEmpty ? 'connect' : action});
  }

  return uri;
}

Future<void> openLinkInsideApp(BuildContext context, String input) async {
  final finalUrl = _normalizeToBrowsableUrl(input);
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => InAppBrowserPage(initialUrl: finalUrl)),
  );
}

const String _chatSupportHost = 'https://www.chatbase.co';
const String _anetExplorerUrl = 'https://explorer.a-network.net';
// _anetDexUrl retained for reference; DEX is now the native DexSwapPage.
// ignore: unused_element
const String _anetDexUrl = 'https://a-network.net/dex.html?v=20260510-03';
const String _anetNftUrl = 'https://a-network.net/nft.html';
const String _anetNativeExplorerTxBase =
    'https://explorer.a-network.net/explorer?view=tx&hash=';
const String _anetWeb4Url = 'https://a-network.net/web4.html';
const String _anetWeb5Url = 'https://a-network.net/web5.html';
const String _aiLoginAdLastShownAtKey = 'ai_login_ad_last_shown_at_ms';
const String _miningEndsAtStorageKey = 'mining_session_ends_at_ms';
const String _pendingReferralCodeStorageKey = 'pending_referral_code';
const String _pendingPublicNftWalletStorageKey = 'pending_public_nft_wallet';
const String _languagePrefKey = 'app_language';
const String _evmNetworkPrefKey = 'wallet_evm_network';
const String _customCoinsPrefKey = 'wallet_custom_coins';
// Keep mining available during low ad-fill periods. Set true at build time
// only when strict ad-before-start enforcement is required.
const bool _requireAdBeforeAntWorkStart = bool.fromEnvironment(
  'REQUIRE_AD_BEFORE_MINING_START',
  defaultValue: false,
);
const Set<String> _walletDappAllowlistHosts = {
  'a-network.net',
  'www.a-network.net',
  'explorer.a-network.net',
  'app.uniswap.org',
  'pancakeswap.finance',
  'app.1inch.io',
  'walletconnect.com',
  'bridge.walletconnect.org',
};

const List<String> _supportedEvmNetworks = ['ANET L1 Bridge'];

const Map<String, String> _evmRpcByNetwork = {
  'BNB Smart Chain': 'https://bsc-dataseed.binance.org/',
  'Ethereum': 'https://cloudflare-eth.com',
  'Polygon': 'https://polygon-rpc.com',
  'Arbitrum One': 'https://arb1.arbitrum.io/rpc',
  'Optimism': 'https://mainnet.optimism.io',
  'Base': 'https://mainnet.base.org',
  'Avalanche C-Chain': 'https://api.avax.network/ext/bc/C/rpc',
  'Fantom': 'https://rpc.ftm.tools',
  'Linea': 'https://rpc.linea.build',
  'zkSync Era': 'https://mainnet.era.zksync.io',
  'opBNB': 'https://opbnb-mainnet-rpc.bnbchain.org',
};

const Map<String, int> _evmChainIdByNetwork = {
  'BNB Smart Chain': 56,
  'Ethereum': 1,
  'Polygon': 137,
  'Arbitrum One': 42161,
  'Optimism': 10,
  'Base': 8453,
  'Avalanche C-Chain': 43114,
  'Fantom': 250,
  'Linea': 59144,
  'zkSync Era': 324,
  'opBNB': 204,
};

const Map<String, String> _evmTxExplorerByNetwork = {
  'BNB Smart Chain': 'https://bscscan.com/tx/',
  'Ethereum': 'https://etherscan.io/tx/',
  'Polygon': 'https://polygonscan.com/tx/',
  'Arbitrum One': 'https://arbiscan.io/tx/',
  'Optimism': 'https://optimistic.etherscan.io/tx/',
  'Base': 'https://basescan.org/tx/',
  'Avalanche C-Chain': 'https://snowtrace.io/tx/',
  'Fantom': 'https://ftmscan.com/tx/',
  'Linea': 'https://lineascan.build/tx/',
  'zkSync Era': 'https://era.zksync.network/tx/',
  'opBNB': 'https://opbnbscan.com/tx/',
  'ANET L1 Bridge': _anetNativeExplorerTxBase,
};

String? _extractPublicNftWalletFromUri(Uri uri) {
  final host = uri.host.trim().toLowerCase();
  final scheme = uri.scheme.trim().toLowerCase();
  final segments = uri.pathSegments
      .where((segment) => segment.trim().isNotEmpty)
      .toList();

  if (segments.isNotEmpty) {
    final first = segments.first.trim().toLowerCase();
    if (first == 'profile' && segments.length >= 2) {
      final rawWallet = segments[1].trim();
      final cleaned = rawWallet
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '')
          .toUpperCase();
      if (cleaned.length >= 20) {
        return cleaned;
      }
    }
  }

  final walletFromQuery =
      (uri.queryParameters['wallet'] ?? uri.queryParameters['address'] ?? '')
          .trim()
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '')
          .toUpperCase();
  if (walletFromQuery.length >= 20) {
    return walletFromQuery;
  }

  final isAnetProfileScheme =
      (scheme == 'anet' || scheme == 'anetwork' || scheme == 'app') &&
      host == 'profile';
  if (isAnetProfileScheme && segments.isNotEmpty) {
    final rawWallet = segments.first.trim();
    final cleaned = rawWallet
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '')
        .toUpperCase();
    if (cleaned.length >= 20) {
      return cleaned;
    }
  }

  final isKnownWebHost =
      host == 'a-network.net' ||
      host == 'www.a-network.net' ||
      host == 'explorer.a-network.net';
  if (!isKnownWebHost && scheme.startsWith('http')) {
    return null;
  }

  return null;
}

bool _isAnetNativeNetwork(String network) => network == 'ANET L1 Bridge';

String? _rpcForNetwork(String network) {
  if (_isAnetNativeNetwork(network)) {
    return null;
  }
  return _evmRpcByNetwork[network];
}

int? _chainIdForNetwork(String network) {
  if (_isAnetNativeNetwork(network)) {
    return null;
  }
  return _evmChainIdByNetwork[network];
}

bool _hostMatchesAllowlist(String host, Set<String> allowlist) {
  final normalized = host.trim().toLowerCase();
  if (normalized.isEmpty) {
    return false;
  }

  for (final allowed in allowlist) {
    final candidate = allowed.trim().toLowerCase();
    if (candidate.isEmpty) {
      continue;
    }
    if (normalized == candidate || normalized.endsWith('.$candidate')) {
      return true;
    }
  }

  return false;
}

int _evmChainIdFromNetworkLabel(String network) {
  final normalized = network.trim().toLowerCase();
  if (normalized == 'ethereum') return 1;
  if (normalized == 'polygon') return 137;
  return 56;
}

Uint8List _deriveEvmPrivateKeyFromMnemonic(String mnemonic) {
  final normalized = mnemonic.trim().toLowerCase().replaceAll(
    RegExp(r'\s+'),
    ' ',
  );
  if (!bip39.validateMnemonic(normalized)) {
    // Backward compatibility for older ANET wallets created before BIP39 rollout.
    // These cannot be imported to MetaMask by phrase, only by private key.
    return _deriveAnetPrivateKeyFromSeed(normalized);
  }

  final seed = bip39.mnemonicToSeed(normalized);
  final root = bip32.BIP32.fromSeed(seed);
  final child = root.derivePath("m/44'/60'/0'/0/0");
  final privateKey = child.privateKey;
  if (privateKey == null || privateKey.isEmpty) {
    throw Exception('Unable to derive EVM signing key from seed phrase');
  }
  return Uint8List.fromList(privateKey);
}

const String _anetL1ChainId = 'anet-private-mainnet-1';
const int _antsPerAnet = 100000000;
const int _minL1FeeAnts = 1000;

String _hexSha256OfString(String input) {
  final digest = SHA256Digest().process(Uint8List.fromList(utf8.encode(input)));
  return bytesToHex(digest, include0x: false);
}

Uint8List _sha256Bytes(Uint8List input) {
  return SHA256Digest().process(input);
}

Uint8List _deriveAnetPrivateKeyFromSeed(String seedPhrase) {
  return _sha256Bytes(Uint8List.fromList(utf8.encode(seedPhrase.trim())));
}

String _deriveLegacyAnetWalletFromSeed(String seedPhrase) {
  final privateHex = _hexSha256OfString(seedPhrase.trim());
  final publicHex = _hexSha256OfString(privateHex);
  final ripemd = RIPEMD160Digest().process(
    Uint8List.fromList(utf8.encode(publicHex)),
  );
  final walletHash = bytesToHex(ripemd, include0x: false).toUpperCase();
  return 'ANET${walletHash.substring(0, 36)}';
}

String _deriveSecpAnetWalletFromSeed(String seedPhrase) {
  final privateKey = _deriveAnetPrivateKeyFromSeed(seedPhrase);
  final publicKey64 = privateKeyBytesToPublic(privateKey);
  final uncompressed = Uint8List.fromList([4, ...publicKey64]);
  final compressed = compressPublicKey(uncompressed);
  final ripemd = RIPEMD160Digest().process(compressed);
  final walletHash = bytesToHex(ripemd, include0x: false).toUpperCase();
  return 'ANET${walletHash.substring(0, 36)}';
}

/// Derives an ANET address directly from raw secp256k1 private key bytes.
/// Used for EVM-imported wallets where the private key is already available.
String _deriveAnetAddressFromPrivateKeyBytes(Uint8List privateKey) {
  final publicKey64 = privateKeyBytesToPublic(privateKey);
  final uncompressed = Uint8List.fromList([4, ...publicKey64]);
  final compressed = compressPublicKey(uncompressed);
  final ripemd = RIPEMD160Digest().process(compressed);
  final walletHash = bytesToHex(ripemd, include0x: false).toUpperCase();
  return 'ANET${walletHash.substring(0, 36)}';
}

/// Resolves the signing private key from a stored credential string.
///   - 'evmkey:HEX' → EVM-imported wallet: raw private key bytes from hex
///   - anything else → ANET native wallet: SHA256(seed phrase text)
Uint8List _resolveAnetPrivateKey(String seedOrEvmKey) {
  final trimmed = seedOrEvmKey.trim();
  if (trimmed.startsWith('evmkey:')) {
    final hex = trimmed.substring(7).replaceAll(RegExp(r'\s'), '');
    return Uint8List.fromList(hexToBytes(hex));
  }
  return _deriveAnetPrivateKeyFromSeed(trimmed);
}

Uint8List _bigIntTo32Bytes(BigInt value) {
  final out = Uint8List(32);
  var n = value;
  for (var i = 31; i >= 0 && n > BigInt.zero; i--) {
    out[i] = (n & BigInt.from(0xff)).toInt();
    n = n >> 8;
  }
  return out;
}

int _parseExpectedNonceFromError(String message) {
  final invalid = RegExp(
    r'invalid nonce: expected\s+(\d+),\s+got\s+\d+',
    caseSensitive: false,
  ).firstMatch(message);
  if (invalid != null) {
    return int.tryParse(invalid.group(1) ?? '') ?? 0;
  }

  final stale = RegExp(
    r'stale nonce: expected nonce greater than\s+(\d+)',
    caseSensitive: false,
  ).firstMatch(message);
  if (stale != null) {
    final current = int.tryParse(stale.group(1) ?? '') ?? 0;
    return current + 1;
  }

  return 0;
}

int? _parseAnetAmountToAnts(String amountText) {
  final clean = amountText.trim();
  final match = RegExp(r'^(\d+)(?:\.(\d{1,8}))?$').firstMatch(clean);
  if (match == null) return null;

  final whole = int.tryParse(match.group(1) ?? '');
  if (whole == null) return null;

  final fracRaw = match.group(2) ?? '';
  final frac = fracRaw.isEmpty ? 0 : int.parse(fracRaw.padRight(8, '0'));

  final wholeAnts = BigInt.from(whole) * BigInt.from(_antsPerAnet);
  final total = wholeAnts + BigInt.from(frac);

  if (total > BigInt.from(0x7fffffffffffffff)) {
    return null;
  }
  return total.toInt();
}

String _canonicalPayloadString(Map<String, dynamic> payload) {
  if (payload.isEmpty) return '{}';
  final sortedEntries = payload.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  final map = <String, dynamic>{
    for (final entry in sortedEntries) entry.key: entry.value,
  };
  return jsonEncode(map);
}

Map<String, dynamic> _buildSignedAnetTransferTx({
  required String seedPhrase,
  required String fromWallet,
  required String toWallet,
  required int amountAnts,
  required int nonce,
  int feeAnts = _minL1FeeAnts,
  DateTime? timestamp,
  Map<String, dynamic>? payload,
}) {
  final ts = (timestamp ?? DateTime.now().toUtc());
  final safePayload = payload ?? const <String, dynamic>{};
  final payloadCanonical = _canonicalPayloadString(safePayload);
  final preimage =
      'v1|transfer|${fromWallet.trim().toUpperCase()}|${toWallet.trim().toUpperCase()}|$amountAnts|$feeAnts|$nonce|${ts.millisecondsSinceEpoch}|$_anetL1ChainId|$payloadCanonical';

  final txHashBytes = _sha256Bytes(Uint8List.fromList(utf8.encode(preimage)));
  final txHash = bytesToHex(txHashBytes, include0x: false).toLowerCase();

  final privateKey = _resolveAnetPrivateKey(seedPhrase);
  final sig = sign(txHashBytes, privateKey);
  final sigBytes = Uint8List.fromList([
    ..._bigIntTo32Bytes(sig.r),
    ..._bigIntTo32Bytes(sig.s),
    sig.v,
  ]);
  final signatureHex = bytesToHex(sigBytes, include0x: false).toLowerCase();

  return {
    'tx_type': 'transfer',
    'from': fromWallet.trim().toUpperCase(),
    'to': toWallet.trim().toUpperCase(),
    'amount_ants': amountAnts,
    'fee_ants': feeAnts,
    'nonce': nonce,
    'timestamp': ts.toIso8601String(),
    'chain_id': _anetL1ChainId,
    'payload': safePayload,
    'signature': signatureHex,
    'tx_hash': txHash,
  };
}

/// Builds a signed action authorization for L1 DEX and other chain actions.
/// Uses ANET key derivation (SHA256 of seed phrase), matching the L1 verification.
Map<String, dynamic> _buildSignedActionAuth({
  required String seedPhrase,
  required String wallet,
  required String actionType,
}) {
  final privateKey = _resolveAnetPrivateKey(seedPhrase);
  return _buildSignedActionAuthFromKey(
    privateKeyBytes: privateKey,
    wallet: wallet,
    actionType: actionType,
  );
}

/// Builds a signed action authorization directly from raw secp256k1 private
/// key bytes.  Use this when the key is already loaded from secure storage —
/// it avoids an additional SHA-256 derivation step and never touches the seed
/// phrase string in memory after the initial PIN verification.
Map<String, dynamic> _buildSignedActionAuthFromKey({
  required Uint8List privateKeyBytes,
  required String wallet,
  required String actionType,
}) {
  final ts = DateTime.now().toUtc();
  final nonce = ts.millisecondsSinceEpoch;
  final payload = <String, dynamic>{'route': actionType};
  final payloadCanonical = _canonicalPayloadString(payload);
  final preimage =
      'action-v1|$actionType|${wallet.trim().toUpperCase()}|$nonce|${ts.millisecondsSinceEpoch}|$_anetL1ChainId|$payloadCanonical';

  final hashBytes = _sha256Bytes(Uint8List.fromList(utf8.encode(preimage)));
  final actionHash = bytesToHex(hashBytes, include0x: false).toLowerCase();

  final sig = sign(hashBytes, privateKeyBytes);
  final sigBytes = Uint8List.fromList([
    ..._bigIntTo32Bytes(sig.r),
    ..._bigIntTo32Bytes(sig.s),
    sig.v,
  ]);
  final signatureHex = bytesToHex(sigBytes, include0x: false).toLowerCase();

  return {
    'wallet': wallet.trim().toUpperCase(),
    'nonce': nonce,
    'timestamp': ts.toIso8601String(),
    'chain_id': _anetL1ChainId,
    'payload': payload,
    'signature': signatureHex,
    'action_hash': actionHash,
  };
}

const String _chatSupportHtml = r'''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>A-Network AI Support</title>
    <style>
      html, body {
        margin: 0;
        padding: 0;
        width: 100%;
        height: 100%;
        background: #07111F;
        overflow: hidden;
      }

      body {
        font-family: Arial, sans-serif;
      }

      .loading {
        position: fixed;
        inset: 0;
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        color: #D9F7FF;
        letter-spacing: 0.04em;
        background: radial-gradient(circle at top, #0F1C2E 0%, #07111F 70%);
        z-index: 9999;
        transition: opacity 0.3s ease;
      }

      .loading .spinner {
        width: 36px;
        height: 36px;
        border: 3px solid rgba(74,184,255,0.2);
        border-top: 3px solid #4AB8FF;
        border-radius: 50%;
        animation: spin 0.8s linear infinite;
        margin-bottom: 16px;
      }

      @keyframes spin {
        to { transform: rotate(360deg); }
      }

      .retry-btn {
        display: none;
        margin-top: 18px;
        padding: 10px 28px;
        background: linear-gradient(135deg, #4AB8FF, #2CF29C);
        color: #07111F;
        border: none;
        border-radius: 20px;
        font-size: 14px;
        font-weight: 700;
        cursor: pointer;
        letter-spacing: 0.03em;
      }

      .error-msg {
        display: none;
        margin-top: 10px;
        color: #F28B82;
        font-size: 13px;
        text-align: center;
        max-width: 280px;
      }
    </style>
  </head>
  <body>
    <div class="loading" id="loadingOverlay">
      <div class="spinner"></div>
      <div>Loading AI Support...</div>
      <div class="error-msg" id="errorMsg">Could not connect to AI Support. Please check your internet connection.</div>
      <button class="retry-btn" id="retryBtn" onclick="retryLoad()">Retry</button>
    </div>
    <script>
      var loadAttempts = 0;
      var maxAttempts = 3;

      function loadChatbase() {
        loadAttempts++;
        if(!window.chatbase||window.chatbase("getState")!=="initialized"){
          window.chatbase=(...arguments)=>{if(!window.chatbase.q){window.chatbase.q=[]}window.chatbase.q.push(arguments)};
          window.chatbase=new Proxy(window.chatbase,{get(target,prop){if(prop==="q"){return target.q}return(...args)=>target(prop,...args)}});
        }
        var old = document.getElementById('U4UFbbJofKx_YPZ8xVxbh');
        if(old) old.remove();

        var script = document.createElement("script");
        script.src = "https://www.chatbase.co/embed.min.js?" + Date.now();
        script.id = "U4UFbbJofKx_YPZ8xVxbh";
        script.domain = "www.chatbase.co";
        script.onload = function(){
          var el = document.getElementById('loadingOverlay');
          if(el) el.style.opacity = '0';
          setTimeout(function(){ if(el) el.style.display = 'none'; }, 300);
        };
        script.onerror = function(){
          showError();
        };
        document.body.appendChild(script);

        setTimeout(function(){
          var el = document.getElementById('loadingOverlay');
          if(el && el.style.display !== 'none') {
            showError();
          }
        }, 15000);
      }

      function showError() {
        var msg = document.getElementById('errorMsg');
        var btn = document.getElementById('retryBtn');
        if(msg) msg.style.display = 'block';
        if(btn && loadAttempts < maxAttempts) btn.style.display = 'inline-block';
        if(btn && loadAttempts >= maxAttempts) btn.textContent = 'Retry (' + loadAttempts + '/' + maxAttempts + ')';
      }

      function retryLoad() {
        var msg = document.getElementById('errorMsg');
        var btn = document.getElementById('retryBtn');
        if(msg) msg.style.display = 'none';
        if(btn) btn.style.display = 'none';
        loadChatbase();
      }

      if(document.readyState==="complete"){loadChatbase()}else{window.addEventListener("load",loadChatbase)}
    </script>
  </body>
</html>
''';

enum AppLanguage {
  system,
  english,
  hindi,
  urdu,
  chinese,
  spanish,
  vietnamese,
  arabic,
  turkish,
}

final ValueNotifier<AppLanguage> _appLanguageNotifier =
    ValueNotifier<AppLanguage>(AppLanguage.system);

const List<Locale> _supportedLocales = [
  Locale('en'),
  Locale('hi', 'IN'),
  Locale('ur', 'PK'),
  Locale('zh', 'CN'),
  Locale('es'),
  Locale('vi', 'VN'),
  Locale('ar'),
  Locale('tr', 'TR'),
];

String appLanguageLabel(AppLanguage language) {
  switch (language) {
    case AppLanguage.system:
      return 'Auto (Region)';
    case AppLanguage.english:
      return 'English';
    case AppLanguage.hindi:
      return 'Hindi';
    case AppLanguage.urdu:
      return 'Urdu';
    case AppLanguage.chinese:
      return 'Chinese';
    case AppLanguage.spanish:
      return 'Español';
    case AppLanguage.vietnamese:
      return 'Tieng Viet';
    case AppLanguage.arabic:
      return 'Arabic';
    case AppLanguage.turkish:
      return 'Turkish';
  }
}

String _serializeLanguage(AppLanguage language) {
  return language.name;
}

AppLanguage _deserializeLanguage(String? value) {
  if (value == null || value.isEmpty) {
    return AppLanguage.system;
  }
  return AppLanguage.values.firstWhere(
    (item) => item.name == value,
    orElse: () => AppLanguage.system,
  );
}

Locale _resolveSystemLocaleFallback(Locale systemLocale) {
  final country = (systemLocale.countryCode ?? '').toUpperCase();
  final lang = systemLocale.languageCode.toLowerCase();

  if (country == 'IN' || lang == 'hi') {
    return const Locale('hi', 'IN');
  }
  if (country == 'PK' || lang == 'ur') {
    return const Locale('ur', 'PK');
  }
  if (country == 'CN' || lang == 'zh') {
    return const Locale('zh', 'CN');
  }
  if (country == 'ES' ||
      country == 'MX' ||
      country == 'AR' ||
      country == 'CO' ||
      country == 'CL' ||
      country == 'PE' ||
      lang == 'es') {
    return const Locale('es');
  }
  if (country == 'VN' || lang == 'vi') {
    return const Locale('vi', 'VN');
  }
  if (country == 'SA' || country == 'AE' || country == 'EG' || lang == 'ar') {
    return const Locale('ar');
  }
  if (country == 'TR' || lang == 'tr') {
    return const Locale('tr', 'TR');
  }
  return const Locale('en');
}

Locale resolveSelectedAppLocale(AppLanguage language, Locale systemLocale) {
  switch (language) {
    case AppLanguage.system:
      return _resolveSystemLocaleFallback(systemLocale);
    case AppLanguage.english:
      return const Locale('en');
    case AppLanguage.hindi:
      return const Locale('hi', 'IN');
    case AppLanguage.urdu:
      return const Locale('ur', 'PK');
    case AppLanguage.chinese:
      return const Locale('zh', 'CN');
    case AppLanguage.spanish:
      return const Locale('es');
    case AppLanguage.vietnamese:
      return const Locale('vi', 'VN');
    case AppLanguage.arabic:
      return const Locale('ar');
    case AppLanguage.turkish:
      return const Locale('tr', 'TR');
  }
}

Future<void> loadAppLanguagePreference() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_languagePrefKey);
  _appLanguageNotifier.value = _deserializeLanguage(raw);
}

Future<void> setAppLanguagePreference(AppLanguage language) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_languagePrefKey, _serializeLanguage(language));
  _appLanguageNotifier.value = language;
}

Future<void> _runStartupTask(
  String name,
  Future<void> Function() task, {
  Duration timeout = const Duration(seconds: 6),
}) async {
  try {
    await task().timeout(timeout);
  } on TimeoutException {
    debugPrint('Startup task timed out: $name');
  } catch (e) {
    debugPrint('Startup task failed: $name -> $e');
  }
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

void main() async {
  // GPU & UI thread optimization for ANR prevention
  // Note: Debug frame banners disabled in release build automatically

  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Attach lifecycle observer for notification management
  WidgetsBinding.instance.addObserver(_AppLifecycleObserver());

  // Critical path: run in parallel, wait for all
  await Future.wait([
    _runStartupTask('security.initialize', SecurityService.initialize),
    _runStartupTask('language.preference', loadAppLanguagePreference),
    _runStartupTask('session.load', loadSession),
  ], eagerError: false);

  // Non-critical: defer to after app launch (fire and forget)
  unawaited(
    _runStartupTask('notifications.initialize', NotificationService.initialize),
  );

  // Unity Ads — INTERNAL TESTING BUILDS ONLY. The service is a no-op unless
  // the binary was compiled with --dart-define=ENABLE_ADS=true. Production
  // AABs (no flag) will skip this call entirely at the JIT/AOT level.
  unawaited(_runStartupTask('ads.initialize', UnityAdsService.instance.init));

  runApp(const MyApp());
}

/// Lifecycle observer to enforce privacy-focused notification policy:
/// Notifications only trigger while app is active (foreground).
/// Background activity is completely paused.
class _AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        AdsService.setAppVisibility(true);
        unawaited(NotificationService.onAppForegrounded());
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        AdsService.setAppVisibility(false);
        unawaited(NotificationService.onAppBackgrounded());
        break;
    }
  }
}

enum _DisplayTheme { classic, ants, studio, executive, paper }

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: _appLanguageNotifier,
      builder: (context, selectedLanguage, _) {
        final security = SecurityService.assessment;
        final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
        final appLocale = resolveSelectedAppLocale(
          selectedLanguage,
          systemLocale,
        );

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: appLocale,
          supportedLocales: _supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // Wrap every screen in an internal-test ribbon when the binary
          // was built with --dart-define=ENABLE_ADS=true. Production AABs
          // do not see this banner.
          builder: (context, child) {
            if (!UnityAdsService.enabled || child == null) {
              return child ?? const SizedBox.shrink();
            }
            return Banner(
              message: 'INTERNAL TEST · ADS',
              location: BannerLocation.topEnd,
              color: const Color(0xFFFF6F00),
              child: child,
            );
          },
          home: security.shouldBlockSensitiveActions
              ? const SecurityLockPage()
              : token == null
              ? const AuthPage()
              : const MiningPage(),
        );
      },
    );
  }
}

class SecurityLockPage extends StatelessWidget {
  const SecurityLockPage({super.key});

  @override
  Widget build(BuildContext context) {
    final assessment = SecurityService.assessment;
    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1C2E),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.45),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.32),
                      blurRadius: 24,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.security,
                      color: Colors.redAccent,
                      size: 44,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      context.l10n.securityLockTitle,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.securityLockMessage,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.84),
                        height: 1.45,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      context.l10n.detectedFlags(assessment.flags.join(', ')),
                      style: TextStyle(
                        color: Colors.orangeAccent.withValues(alpha: 0.92),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      context.l10n.platformRuntime(
                        assessment.platform,
                        assessment.runtimeLabel,
                      ),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.70),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        context.l10n.securityOverrideInfo,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// =======================
/// ✨ PARTICLES
/// =======================
class ParticleBackground extends StatefulWidget {
  final int particleCount;
  final double particleRadius;
  final double linkDistance;
  final double driftX;
  final double driftY;
  final Color particleColor;
  final Color linkColor;

  const ParticleBackground({
    super.key,
    this.particleCount = 80,
    this.particleRadius = 2.5,
    this.linkDistance = 0,
    this.driftX = 150,
    this.driftY = 100,
    this.particleColor = Colors.cyanAccent,
    this.linkColor = Colors.cyanAccent,
  });

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late final List<Offset> particles;

  @override
  void initState() {
    super.initState();
    particles = List.generate(
      widget.particleCount,
      (_) => Offset(Random().nextDouble(), Random().nextDouble()),
    );
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) {
        return CustomPaint(
          painter: ParticlePainter(
            particles: particles,
            progress: controller.value,
            particleRadius: widget.particleRadius,
            linkDistance: widget.linkDistance,
            driftX: widget.driftX,
            driftY: widget.driftY,
            particleColor: widget.particleColor,
            linkColor: widget.linkColor,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class ParticlePainter extends CustomPainter {
  final List<Offset> particles;
  final double progress;
  final double particleRadius;
  final double linkDistance;
  final double driftX;
  final double driftY;
  final Color particleColor;
  final Color linkColor;

  ParticlePainter({
    required this.particles,
    required this.progress,
    required this.particleRadius,
    required this.linkDistance,
    required this.driftX,
    required this.driftY,
    required this.particleColor,
    required this.linkColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final particlePaint = Paint()
      ..color = particleColor.withValues(alpha: 0.55);
    final linePaint = Paint()
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;

    final animatedPoints = particles.map((p) {
      final dx = (p.dx * size.width + progress * driftX) % size.width;
      final dy = (p.dy * size.height + progress * driftY) % size.height;
      return Offset(dx, dy);
    }).toList();

    if (linkDistance > 0) {
      final maxDistanceSquared = linkDistance * linkDistance;
      for (var i = 0; i < animatedPoints.length; i++) {
        for (var j = i + 1; j < animatedPoints.length; j++) {
          final delta = animatedPoints[i] - animatedPoints[j];
          final distanceSquared = delta.dx * delta.dx + delta.dy * delta.dy;
          if (distanceSquared <= maxDistanceSquared) {
            final opacity = 1 - (distanceSquared / maxDistanceSquared);
            canvas.drawLine(
              animatedPoints[i],
              animatedPoints[j],
              linePaint
                ..color = linkColor.withValues(alpha: 0.04 + opacity * 0.20),
            );
          }
        }
      }
    }

    for (final point in animatedPoints) {
      canvas.drawCircle(point, particleRadius, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// =======================
/// 🔐 AUTH PAGE
/// =======================
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with WidgetsBindingObserver {
  final AppLinks _appLinks = AppLinks();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final referralCtrl = TextEditingController();

  StreamSubscription<Uri>? _deepLinkSub;
  Timer? _videoInitTimer;

  bool isLogin = true;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _accountRestoreEligible = false;
  String message = "";
  DateTime? _lastHandledNftDeepLinkAt;
  String? _lastHandledNftDeepLinkWallet;

  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = VideoPlayerController.asset("assets/video.mp4");
    _videoInitTimer = Timer(
      const Duration(milliseconds: 400),
      () => unawaited(_initializeAuthBackgroundVideo()),
    );

    unawaited(_hydratePendingReferralCode());
    _initReferralDeepLinks();
  }

  Future<void> _initializeAuthBackgroundVideo() async {
    try {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) {
        return;
      }
      await _controller.initialize();
      await _controller.setLooping(true);
      await _controller.setVolume(0);
      await _controller.play();
      if (mounted) {
        setState(() {});
      }
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      unawaited(_controller.pause());
      return;
    }

    if (state == AppLifecycleState.resumed) {
      unawaited(_controller.play());
    }
  }

  Future<void> _hydratePendingReferralCode() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getString(_pendingReferralCodeStorageKey)?.trim();
    if (pending == null || pending.isEmpty || !mounted) {
      return;
    }
    _applyReferralCode(pending.toUpperCase(), announce: false);
  }

  void _initReferralDeepLinks() {
    unawaited(() async {
      try {
        final initialUri = await _appLinks.getInitialLink();
        if (initialUri != null) {
          await _applyIncomingAppUri(initialUri, announce: false);
        }
      } catch (_) {}

      _deepLinkSub = _appLinks.uriLinkStream.listen((uri) {
        unawaited(_applyIncomingAppUri(uri, announce: true));
      });
    }());
  }

  Future<void> _applyIncomingAppUri(Uri uri, {required bool announce}) async {
    final publicWallet = _extractPublicNftWalletFromUri(uri);
    if (publicWallet != null && publicWallet.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingPublicNftWalletStorageKey, publicWallet);
      if (!mounted) {
        return;
      }
      final sameWallet = _lastHandledNftDeepLinkWallet == publicWallet;
      final withinDebounce =
          _lastHandledNftDeepLinkAt != null &&
          DateTime.now().difference(_lastHandledNftDeepLinkAt!) <
              const Duration(seconds: 2);
      if (sameWallet && withinDebounce) {
        return;
      }
      _lastHandledNftDeepLinkWallet = publicWallet;
      _lastHandledNftDeepLinkAt = DateTime.now();
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PublicNftProfilePage(walletAddress: publicWallet),
        ),
      );
      return;
    }

    final candidates = <String?>[
      uri.queryParameters['ref'],
      uri.queryParameters['code'],
      uri.queryParameters['referral'],
      uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null,
    ];

    String? code;
    for (final candidate in candidates) {
      final value = candidate?.trim();
      if (value == null || value.isEmpty) {
        continue;
      }

      final cleaned = value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
      if (cleaned.isNotEmpty) {
        code = cleaned;
        break;
      }
    }

    if (code == null || code.isEmpty) {
      return;
    }

    final normalized = code.toUpperCase();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingReferralCodeStorageKey, normalized);
    if (!mounted) {
      return;
    }

    _applyReferralCode(normalized, announce: announce);
  }

  void _applyReferralCode(String code, {required bool announce}) {
    setState(() {
      isLogin = false;
      referralCtrl.text = code;
      if (announce) {
        message = 'Invitation Ant Code applied: $code';
      }
    });
  }

  bool _isDeviceLinkedAccountLimitMessage(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('maximum allowed linked accounts') ||
        (normalized.contains('linked accounts') &&
            normalized.contains('maximum'));
  }

  Future<void> submit() async {
    if (_isSubmitting) return;

    final email = emailCtrl.text.trim();
    final password = passCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        message = 'Email and password are required';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _accountRestoreEligible = false;
      message = '';
    });

    try {
      final deviceId = await getOrCreateDeviceId();
      final res = isLogin
          ? await login(email, password, deviceId)
          : await register(
              email,
              password,
              deviceId,
              referralCode: referralCtrl.text.trim(),
            );

      if (!mounted) return;

      if (res["token"] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_pendingReferralCodeStorageKey);
        final userEmail = res['user']?['email']?.toString();
        if (userEmail != null && userEmail.isNotEmpty) {
          currentEmail = userEmail;
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MiningPage()),
        );
      } else if (res['otp_required'] == true) {
        final otpEmail = (res['email']?.toString().trim().isNotEmpty ?? false)
            ? res['email'].toString().trim()
            : email;
        final otpDelivered = res['otpSent'] == true;
        final cooldownActive = res['cooldown'] == true;
        final initialOtpMessage =
            res['message']?.toString() ?? res['otpError']?.toString();

        if (!otpDelivered && !cooldownActive) {
          setState(() {
            message =
                res['message']?.toString() ??
                res['otpError']?.toString() ??
                'Login verification code could not be delivered. Please try again.';
          });
          return;
        }

        await _showLoginOtpDialog(
          otpEmail,
          deviceId,
          initialMessage: initialOtpMessage,
        );
      } else if (res['requiresVerification'] == true) {
        final otpEmail = (res['email']?.toString().trim().isNotEmpty ?? false)
            ? res['email'].toString().trim()
            : email;

        await _showOtpDialog(otpEmail);
      } else {
        setState(() {
          final nextMessage =
              res['message']?.toString() ??
              res['error']?.toString() ??
              'Authentication failed';
          final isDeviceLimit = _isDeviceLinkedAccountLimitMessage(nextMessage);
          _accountRestoreEligible =
              res['accountRestoreEligible'] == true ||
              nextMessage.toLowerCase().contains('scheduled for deletion');
          if (isDeviceLimit) {
            isLogin = true;
            message =
                'This device already reached the maximum linked accounts. '
                'Log in with an existing account, or use a different device to register.';
          } else {
            message = nextMessage;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => message = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _openSupportEmail() async {
    final emailUri = Uri(
      scheme: 'mailto',
      path: 'info@a-network.net',
      queryParameters: {'subject': 'A-Network Support Request'},
    );

    final launched = await launchUrl(emailUri);
    if (!launched) {
      await openLinkInsideApp(context, 'https://a-network.net');
    }
    if (!mounted) return;
    setState(() {
      message = launched
          ? 'Opening email app for info@a-network.net'
          : 'Email app not available, support page opened';
    });
  }

  Future<void> _forgotPasswordDialog() async {
    final emailInputCtrl = TextEditingController(text: emailCtrl.text.trim());
    final codeCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool codeSent = false;
    bool localSubmitting = false;
    bool obscureNew = true;
    bool obscureConfirm = true;
    String localMessage = '';

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
            backgroundColor: const Color(0xFF0A1224),
            title: Text(
              context.l10n.forgotPasswordTitle,
              style: TextStyle(color: Colors.cyanAccent),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.forgotPasswordInstructions,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailInputCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: context.l10n.emailHint,
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.35),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: localSubmitting
                              ? null
                              : () async {
                                  final enteredEmail = emailInputCtrl.text
                                      .trim()
                                      .toLowerCase();
                                  if (enteredEmail.isEmpty) {
                                    setLocalState(() {
                                      localMessage =
                                          'Please enter your email first';
                                    });
                                    return;
                                  }

                                  setLocalState(() {
                                    localSubmitting = true;
                                    localMessage = '';
                                  });

                                  try {
                                    final res = await requestPasswordResetOtp(
                                      enteredEmail,
                                    );
                                    setLocalState(() {
                                      codeSent = true;
                                      localMessage =
                                          res['message']?.toString() ??
                                          'Reset code sent';
                                    });
                                  } catch (e) {
                                    setLocalState(() {
                                      localMessage = e.toString().replaceFirst(
                                        'Exception: ',
                                        '',
                                      );
                                    });
                                  } finally {
                                    setLocalState(() {
                                      localSubmitting = false;
                                    });
                                  }
                                },
                          child: Text(
                            codeSent ? 'Resend Code' : 'Send Code',
                            style: const TextStyle(color: Colors.cyanAccent),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: codeCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: context.l10n.sixDigitCodeHint,
                      hintStyle: const TextStyle(color: Colors.white54),
                      counterText: '',
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.35),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: newPassCtrl,
                    obscureText: obscureNew,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: context.l10n.newPasswordHint,
                      hintStyle: const TextStyle(color: Colors.white54),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setLocalState(() {
                            obscureNew = !obscureNew;
                          });
                        },
                        icon: Icon(
                          obscureNew
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: Colors.white70,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.35),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmPassCtrl,
                    obscureText: obscureConfirm,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: context.l10n.confirmPasswordHint,
                      hintStyle: const TextStyle(color: Colors.white54),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setLocalState(() {
                            obscureConfirm = !obscureConfirm;
                          });
                        },
                        icon: Icon(
                          obscureConfirm
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: Colors.white70,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.35),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (localMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        localMessage,
                        style: TextStyle(
                          color: localMessage.toLowerCase().contains('success')
                              ? Colors.greenAccent
                              : Colors.redAccent,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openSupportEmail();
                },
                child: Text(
                  context.l10n.needHelpButton,
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  context.l10n.closeButton,
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              TextButton(
                onPressed: localSubmitting
                    ? null
                    : () async {
                        final enteredEmail = emailInputCtrl.text
                            .trim()
                            .toLowerCase();
                        final code = codeCtrl.text.trim();
                        final newPassword = newPassCtrl.text;
                        final confirmPassword = confirmPassCtrl.text;

                        if (enteredEmail.isEmpty ||
                            code.isEmpty ||
                            newPassword.isEmpty ||
                            confirmPassword.isEmpty) {
                          setLocalState(() {
                            localMessage = 'Please fill all fields';
                          });
                          return;
                        }

                        if (code.length != 6) {
                          setLocalState(() {
                            localMessage = 'Enter a valid 6-digit code';
                          });
                          return;
                        }

                        if (newPassword.length < 8) {
                          setLocalState(() {
                            localMessage =
                                'New password must be at least 8 characters';
                          });
                          return;
                        }

                        if (newPassword != confirmPassword) {
                          setLocalState(() {
                            localMessage = 'Passwords do not match';
                          });
                          return;
                        }

                        setLocalState(() {
                          localSubmitting = true;
                          localMessage = '';
                        });

                        try {
                          final res = await confirmPasswordReset(
                            enteredEmail,
                            code,
                            newPassword,
                          );

                          if (!mounted) return;

                          setState(() {
                            message =
                                res['message']?.toString() ??
                                'Password reset successful';
                            emailCtrl.text = enteredEmail;
                            passCtrl.text = newPassword;
                          });

                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                res['message']?.toString() ??
                                    'Password reset successful',
                              ),
                            ),
                          );
                        } catch (e) {
                          setLocalState(() {
                            localMessage = e.toString().replaceFirst(
                              'Exception: ',
                              '',
                            );
                          });
                        } finally {
                          setLocalState(() {
                            localSubmitting = false;
                          });
                        }
                      },
                child: Text(
                  localSubmitting ? 'Please wait...' : 'Reset Password',
                  style: const TextStyle(color: Colors.cyanAccent),
                ),
              ),
            ],
          ),
        );
      },
    );

    emailInputCtrl.dispose();
    codeCtrl.dispose();
    newPassCtrl.dispose();
    confirmPassCtrl.dispose();
  }

  Future<void> _accountRestoreDialog() async {
    final emailInputCtrl = TextEditingController(text: emailCtrl.text.trim());
    final codeCtrl = TextEditingController();
    bool codeSent = false;
    bool localSubmitting = false;
    String localMessage = '';

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
            backgroundColor: const Color(0xFF0A1224),
            title: const Text(
              'Restore Account',
              style: TextStyle(color: Colors.cyanAccent),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Use your email to restore this scheduled-for-deletion account. This recovery can only be used once.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailInputCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: context.l10n.emailHint,
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.35),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: localSubmitting
                        ? null
                        : () async {
                            final enteredEmail = emailInputCtrl.text
                                .trim()
                                .toLowerCase();
                            if (enteredEmail.isEmpty) {
                              setLocalState(() {
                                localMessage = 'Please enter your email first';
                              });
                              return;
                            }

                            setLocalState(() {
                              localSubmitting = true;
                              localMessage = '';
                            });

                            try {
                              final res = await requestAccountRestoreOtp(
                                enteredEmail,
                              );
                              setLocalState(() {
                                codeSent = true;
                                localMessage =
                                    res['message']?.toString() ??
                                    'Restore code sent';
                              });
                            } catch (e) {
                              setLocalState(() {
                                localMessage = e.toString().replaceFirst(
                                  'Exception: ',
                                  '',
                                );
                              });
                            } finally {
                              setLocalState(() {
                                localSubmitting = false;
                              });
                            }
                          },
                    child: Text(
                      codeSent ? 'Resend Restore Code' : 'Send Restore Code',
                      style: const TextStyle(color: Colors.cyanAccent),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: codeCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '6-digit restore code',
                      hintStyle: const TextStyle(color: Colors.white54),
                      counterText: '',
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.35),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (localMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        localMessage,
                        style: TextStyle(
                          color:
                              localMessage.toLowerCase().contains('sent') ||
                                  localMessage.toLowerCase().contains(
                                    'restored',
                                  )
                              ? Colors.greenAccent
                              : Colors.redAccent,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  context.l10n.closeButton,
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              TextButton(
                onPressed: localSubmitting
                    ? null
                    : () async {
                        final enteredEmail = emailInputCtrl.text
                            .trim()
                            .toLowerCase();
                        final code = codeCtrl.text.trim();

                        if (enteredEmail.isEmpty || code.isEmpty) {
                          setLocalState(() {
                            localMessage = 'Please fill all fields';
                          });
                          return;
                        }

                        if (code.length != 6) {
                          setLocalState(() {
                            localMessage = 'Enter a valid 6-digit code';
                          });
                          return;
                        }

                        setLocalState(() {
                          localSubmitting = true;
                          localMessage = '';
                        });

                        try {
                          final res = await confirmAccountRestore(
                            enteredEmail,
                            code,
                          );

                          if (!mounted) return;

                          setState(() {
                            _accountRestoreEligible = false;
                            message =
                                res['message']?.toString() ??
                                'Account restored successfully. Please log in again.';
                            emailCtrl.text = enteredEmail;
                          });

                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                res['message']?.toString() ??
                                    'Account restored successfully. Please log in again.',
                              ),
                            ),
                          );
                        } catch (e) {
                          setLocalState(() {
                            localMessage = e.toString().replaceFirst(
                              'Exception: ',
                              '',
                            );
                          });
                        } finally {
                          setLocalState(() {
                            localSubmitting = false;
                          });
                        }
                      },
                child: Text(
                  localSubmitting ? 'Please wait...' : 'Restore Account',
                  style: const TextStyle(color: Colors.cyanAccent),
                ),
              ),
            ],
          ),
        );
      },
    );

    emailInputCtrl.dispose();
    codeCtrl.dispose();
  }

  Future<void> _showOtpDialog(String email) async {
    final codeCtrl = TextEditingController();
    String localMessage = '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
            backgroundColor: const Color(0xFF0A1224),
            title: Text(
              context.l10n.verifyEmailTitle,
              style: TextStyle(color: Colors.cyanAccent),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter the 6-digit code sent to $email',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: codeCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  maxLength: 6,
                  decoration: InputDecoration(
                    hintText: context.l10n.otpCodeHint,
                    hintStyle: TextStyle(color: Colors.white54),
                    counterText: '',
                  ),
                ),
                if (localMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      localMessage,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  try {
                    final resend = await resendEmailOtp(email);
                    if (!mounted) return;
                    setLocalState(() {
                      localMessage =
                          resend['message']?.toString() ??
                          resend['error']?.toString() ??
                          '';
                    });
                  } catch (e) {
                    setLocalState(() {
                      localMessage = e.toString().replaceFirst(
                        'Exception: ',
                        '',
                      );
                    });
                  }
                },
                child: Text(
                  context.l10n.resendCodeButton,
                  style: TextStyle(color: Colors.cyanAccent),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    message =
                        'Email verification cancelled. Enter your last code later or tap Resend Code for a new one.';
                  });
                },
                child: Text(
                  context.l10n.cancelButton,
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final code = codeCtrl.text.trim();
                  if (code.length != 6) {
                    setLocalState(() {
                      localMessage = 'Enter a valid 6-digit code';
                    });
                    return;
                  }

                  try {
                    final verify = await verifyEmailOtp(email, code);
                    if (verify['token'] != null) {
                      if (!mounted) return;
                      currentEmail =
                          verify['user']?['email']?.toString() ?? email;
                      Navigator.pop(ctx);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const MiningPage()),
                      );
                      return;
                    }

                    setLocalState(() {
                      localMessage =
                          verify['message']?.toString() ??
                          verify['error']?.toString() ??
                          'Verification failed';
                    });
                  } catch (e) {
                    setLocalState(() {
                      localMessage = e.toString().replaceFirst(
                        'Exception: ',
                        '',
                      );
                    });
                  }
                },
                child: Text(
                  context.l10n.verifyButton,
                  style: TextStyle(color: Colors.cyanAccent),
                ),
              ),
            ],
          ),
        );
      },
    );

    codeCtrl.dispose();
  }

  Future<void> _showLoginOtpDialog(
    String email,
    String deviceId, {
    String? initialMessage,
  }) async {
    final codeCtrl = TextEditingController();
    String localMessage = initialMessage ?? '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
            backgroundColor: const Color(0xFF0A1224),
            title: Text(
              context.l10n.loginVerificationTitle,
              style: TextStyle(color: Colors.cyanAccent),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter the 6-digit login code sent to $email',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: codeCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  maxLength: 6,
                  decoration: InputDecoration(
                    hintText: context.l10n.otpCodeHint,
                    hintStyle: TextStyle(color: Colors.white54),
                    counterText: '',
                  ),
                ),
                if (localMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      localMessage,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    message =
                        'Login verification cancelled. Enter your latest code later or request a new one.';
                  });
                },
                child: Text(
                  context.l10n.cancelButton,
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    final resend = await resendLoginOtp(email, deviceId);
                    if (!mounted) return;

                    setLocalState(() {
                      localMessage =
                          resend['message']?.toString() ??
                          'A new login code was sent.';
                    });
                  } catch (e) {
                    setLocalState(() {
                      localMessage = e.toString().replaceFirst(
                        'Exception: ',
                        '',
                      );
                    });
                  }
                },
                child: const Text(
                  'Resend',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final code = codeCtrl.text.trim();
                  if (code.length != 6) {
                    setLocalState(() {
                      localMessage = 'Enter a valid 6-digit code';
                    });
                    return;
                  }

                  try {
                    final verify = await verifyLoginOtp(email, code, deviceId);
                    if (verify['token'] != null) {
                      if (!mounted) return;
                      currentEmail =
                          verify['user']?['email']?.toString() ?? email;
                      Navigator.pop(ctx);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const MiningPage()),
                      );
                      return;
                    }

                    setLocalState(() {
                      localMessage =
                          verify['message']?.toString() ??
                          verify['error']?.toString() ??
                          'Verification failed';
                    });
                  } catch (e) {
                    setLocalState(() {
                      localMessage = e.toString().replaceFirst(
                        'Exception: ',
                        '',
                      );
                    });
                  }
                },
                child: Text(
                  context.l10n.verifyButton,
                  style: TextStyle(color: Colors.cyanAccent),
                ),
              ),
            ],
          ),
        );
      },
    );

    codeCtrl.dispose();
  }

  Widget background() {
    return Stack(
      children: [
        SizedBox.expand(
          child: _controller.value.isInitialized
              ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                )
              : Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black,
                        Color(0xFF0F2027),
                        Color(0xFF2C5364),
                      ],
                    ),
                  ),
                ),
        ),
        const ParticleBackground(),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0x6607101A), Color(0x4D10243A), Color(0x7306111F)],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _videoInitTimer?.cancel();
    _deepLinkSub?.cancel();
    emailCtrl.dispose();
    passCtrl.dispose();
    referralCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  Widget _authInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.cyanAccent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final showDeviceLimitHelp = _isDeviceLinkedAccountLimitMessage(message);

    return Scaffold(
      body: Stack(
        children: [
          background(),
          Container(color: Colors.black.withValues(alpha: 0.6)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 20, 20, keyboardInset + 20),
                child: Container(
                  padding: const EdgeInsets.all(25),
                  constraints: const BoxConstraints(maxWidth: 460),
                  decoration: BoxDecoration(
                    color: const Color(0xCC081221),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.cyanAccent.withValues(alpha: 0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "A-Network",
                        style: TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(blurRadius: 20, color: Colors.cyanAccent),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.cyanAccent.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          context.l10n.authPageSubtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.cyanAccent.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: () => setState(() => isLogin = true),
                                style: FilledButton.styleFrom(
                                  backgroundColor: isLogin
                                      ? Colors.cyanAccent
                                      : Colors.transparent,
                                  foregroundColor: isLogin
                                      ? Colors.black
                                      : Colors.white70,
                                ),
                                child: Text(context.l10n.loginTab),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton(
                                onPressed: () =>
                                    setState(() => isLogin = false),
                                style: FilledButton.styleFrom(
                                  backgroundColor: !isLogin
                                      ? Colors.cyanAccent
                                      : Colors.transparent,
                                  foregroundColor: !isLogin
                                      ? Colors.black
                                      : Colors.white70,
                                ),
                                child: Text(context.l10n.registerTab),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: emailCtrl,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email,
                        ],
                        decoration: InputDecoration(
                          hintText: "Email",
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.black.withValues(alpha: 0.6),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: passCtrl,
                        style: const TextStyle(color: Colors.white),
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          hintText: "Password",
                          hintStyle: const TextStyle(color: Colors.white54),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: Colors.white70,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.black.withValues(alpha: 0.6),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      if (!isLogin) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: referralCtrl,
                          style: const TextStyle(color: Colors.white),
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            hintText: "Ant Code (Optional)",
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.black.withValues(alpha: 0.6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent,
                            foregroundColor: Colors.black,
                            elevation: 12,
                            shadowColor: Colors.cyanAccent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            _isSubmitting
                                ? 'Please wait...'
                                : (isLogin
                                      ? "Continue to Login"
                                      : "Continue to Register"),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _forgotPasswordDialog,
                        child: const Text(
                          "Forgot Password?",
                          style: TextStyle(color: Colors.cyanAccent),
                        ),
                      ),
                      if (showDeviceLimitHelp)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              isLogin = true;
                            });
                          },
                          child: Text(
                            context.l10n.useExistingAccountButton,
                            style: TextStyle(color: Colors.orangeAccent),
                          ),
                        ),
                      if (isLogin && _accountRestoreEligible)
                        TextButton(
                          onPressed: _accountRestoreDialog,
                          child: Text(
                            context.l10n.restoreDeletedAccountButton,
                            style: TextStyle(color: Colors.orangeAccent),
                          ),
                        ),
                      const SizedBox(height: 8),
                      _authInfoCard(
                        icon: Icons.schedule_rounded,
                        title: 'Session Model',
                        subtitle:
                            'Mining works in 6-hour cycles and progress syncs to your wallet account.',
                      ),
                      const SizedBox(height: 8),
                      _authInfoCard(
                        icon: Icons.verified_user_rounded,
                        title: 'Security Layer',
                        subtitle:
                            'Seed phrase, PIN, and account restore protections are built in.',
                      ),
                      if (message.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.redAccent.withValues(alpha: 0.28),
                              ),
                            ),
                            child: Text(
                              message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class InAppBrowserPage extends StatefulWidget {
  final String initialUrl;
  final String? initialHtml;
  final String title;
  final bool showUrlBar;
  final bool showLoadingBar;
  final bool walletExtensionMode;
  final String walletAddress;
  final String walletNetwork;
  final String walletSeedPhrase;
  final bool walletPinRequired;
  final Set<String> allowedHosts;
  final bool strictHostBlocking;

  /// Optional callback invoked when the user taps "Open DEX" in the browser
  /// quick-action bar. When provided, the caller handles PIN gating and
  /// navigation; otherwise the browser opens DexSwapPage directly.
  final Future<void> Function()? onOpenDex;

  /// Optional callback invoked when the user taps "Bridge to BSC" in the
  /// browser quick-action bar. When provided, the caller handles PIN gating
  /// and navigation to the BridgeBurnPage.
  final Future<void> Function()? onOpenBridge;

  const InAppBrowserPage({
    super.key,
    required this.initialUrl,
    this.initialHtml,
    this.title = 'ANTS Browser',
    this.showUrlBar = true,
    this.showLoadingBar = true,
    this.walletExtensionMode = false,
    this.walletAddress = '',
    this.walletNetwork = '',
    this.walletSeedPhrase = '',
    this.walletPinRequired = true,
    this.allowedHosts = const {},
    this.strictHostBlocking = true,
    this.onOpenDex,
    this.onOpenBridge,
  });

  @override
  State<InAppBrowserPage> createState() => _InAppBrowserPageState();
}

class _InAppBrowserPageState extends State<InAppBrowserPage> {
  late final WebViewController _controller;
  final TextEditingController _urlCtrl = TextEditingController();
  bool _loading = true;
  String _currentHost = '';
  String? _connectedHost;
  final Set<String> _sessionApprovedHosts = <String>{};
  DateTime? _signingSessionExpiresAt;

  @override
  void initState() {
    super.initState();
    _urlCtrl.text = widget.initialUrl;
    final initialUri = Uri.tryParse(widget.initialUrl);
    _currentHost = (initialUri?.host ?? '').toLowerCase();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() => _loading = true);
            }
          },
          onPageFinished: (url) {
            final host = (Uri.tryParse(url)?.host ?? '').toLowerCase();
            if (mounted) {
              setState(() {
                _loading = false;
                _urlCtrl.text = url;
                _currentHost = host;
              });
            }
            if (widget.walletExtensionMode && host.isNotEmpty) {
              unawaited(_autoConnectTrustedHost(host: host));
            }
            unawaited(_injectDexRuntimeCompat(url));
          },
          onNavigationRequest: (request) async {
            final uri = Uri.tryParse(request.url);
            final scheme = (uri?.scheme ?? '').toLowerCase();
            if (scheme.isNotEmpty &&
                scheme != 'http' &&
                scheme != 'https' &&
                scheme != 'about') {
              if (uri != null && _isWalletDeepLinkScheme(scheme)) {
                final walletUri = _normalizeWalletDeepLinkUri(uri);
                final launched = await launchUrl(
                  walletUri,
                  mode: LaunchMode.externalApplication,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        launched
                            ? 'Opening wallet app...'
                            : 'Wallet app not found. Install or update A Network wallet.',
                      ),
                    ),
                  );
                }
                return NavigationDecision.prevent;
              }

              final rewritten = _normalizeToBrowsableUrl(request.url);
              final rewrittenUri = Uri.tryParse(rewritten);
              if (rewrittenUri != null &&
                  (rewrittenUri.scheme == 'http' ||
                      rewrittenUri.scheme == 'https')) {
                _controller.loadRequest(rewrittenUri);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.convertedDeepLink)),
                  );
                }
                return NavigationDecision.prevent;
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.l10n.blockedUnsupportedScheme(scheme),
                    ),
                  ),
                );
              }
              return NavigationDecision.prevent;
            }

            if (!widget.walletExtensionMode) {
              return NavigationDecision.navigate;
            }

            final host = (uri?.host ?? '').toLowerCase();
            if (host.isEmpty) {
              return NavigationDecision.navigate;
            }

            final trusted = _isHostTrusted(host);
            if (trusted) {
              if (mounted) {
                setState(() {
                  _currentHost = host;
                });
              }
              return NavigationDecision.navigate;
            }

            if (!mounted) {
              return NavigationDecision.prevent;
            }

            if (widget.strictHostBlocking) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Blocked untrusted domain: $host')),
              );
              return NavigationDecision.prevent;
            }

            final approved = await _confirmUntrustedHost(
              host: host,
              url: request.url,
            );
            if (approved) {
              if (mounted) {
                setState(() {
                  _sessionApprovedHosts.add(host);
                  _currentHost = host;
                });
              }
              return NavigationDecision.navigate;
            }

            return NavigationDecision.prevent;
          },
        ),
      );

    if (widget.initialHtml != null) {
      _controller.loadHtmlString(
        widget.initialHtml!,
        baseUrl: _chatSupportHost,
      );
    } else {
      _controller.loadRequest(Uri.parse(widget.initialUrl));
    }
  }

  void _go() {
    final raw = _urlCtrl.text.trim();
    if (raw.isEmpty) return;

    final deepLink = Uri.tryParse(raw);
    final deepScheme = (deepLink?.scheme ?? '').toLowerCase();
    final isWalletDeepLink = _isWalletDeepLinkScheme(deepScheme);
    if (isWalletDeepLink && deepLink != null) {
      final walletUri = _normalizeWalletDeepLinkUri(deepLink);
      unawaited(() async {
        final launched = await launchUrl(
          walletUri,
          mode: LaunchMode.externalApplication,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              launched
                  ? 'Opening wallet app...'
                  : 'Wallet app not found. Use the Open DEX button below.',
            ),
          ),
        );
      }());
      return;
    }

    final url = _normalizeToBrowsableUrl(raw);
    _controller.loadRequest(Uri.parse(url));
  }

  bool _isHostTrusted(String host) {
    return _hostMatchesAllowlist(host, widget.allowedHosts) ||
        _hostMatchesAllowlist(host, _sessionApprovedHosts);
  }

  Future<bool> _confirmUntrustedHost({
    required String host,
    required String url,
  }) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1224),
        title: Text(
          context.l10n.untrustedDomainTitle,
          style: TextStyle(color: Colors.orangeAccent),
        ),
        content: Text(
          'This domain is not on the trusted dApp list:\n\n$host\n\nURL:\n$url\n\nOnly continue if you trust this site.',
          style: const TextStyle(color: Colors.white70, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              context.l10n.cancelButton,
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              context.l10n.trustForSessionButton,
              style: TextStyle(color: Colors.orangeAccent),
            ),
          ),
        ],
      ),
    );
    return approved == true;
  }

  Future<void> _approveConnectForCurrentHost() async {
    final url = await _controller.currentUrl();
    final host = (Uri.tryParse(url ?? '')?.host ?? _currentHost).toLowerCase();
    if (host.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.openDAppPageFirst)));
      return;
    }

    var trusted = _isHostTrusted(host);
    if (!trusted && !widget.strictHostBlocking) {
      final approved = await _confirmUntrustedHost(host: host, url: url ?? '');
      if (!approved) {
        return;
      }
      trusted = true;
      if (mounted) {
        setState(() {
          _sessionApprovedHosts.add(host);
        });
      }
    }

    if (!trusted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection blocked for untrusted domain: $host'),
        ),
      );
      return;
    }

    if (!mounted) return;
    final granted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1224),
        title: Text(
          context.l10n.connectWalletTooltip,
          style: TextStyle(color: Colors.cyanAccent),
        ),
        content: Text(
          'dApp: $host\nNetwork: ${widget.walletNetwork}\nWallet: ${widget.walletAddress}\n\nGrant session access to read your wallet address and request signatures?',
          style: const TextStyle(color: Colors.white70, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              context.l10n.rejectButton,
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              context.l10n.connectButton,
              style: TextStyle(color: Colors.cyanAccent),
            ),
          ),
        ],
      ),
    );

    if (granted == true) {
      await _connectHost(host, showSnackBar: true);
    }
  }

  Future<void> _autoConnectTrustedHost({required String host}) async {
    if (!_isHostTrusted(host)) return;
    await _connectHost(host);
  }

  Future<void> _connectHost(String host, {bool showSnackBar = false}) async {
    if (!mounted || host.isEmpty || _connectedHost == host) {
      return;
    }
    setState(() {
      _connectedHost = host;
    });
    await _injectWalletConnectPayload(host);
    if (showSnackBar && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Wallet connected to $host')));
    }
  }

  Future<void> _injectWalletConnectPayload(String host) async {
    final payload = {
      'type': 'wallet_connected',
      'wallet': widget.walletAddress,
      'network': widget.walletNetwork,
      'chainId': _evmChainIdFromNetworkLabel(widget.walletNetwork),
      'host': host,
      'issuedAt': DateTime.now().toUtc().toIso8601String(),
    };
    final jsonPayload = jsonEncode(payload);
    await _controller.runJavaScript('''
(() => {
  const payload = $jsonPayload;
  try { window.__ANET_CONNECTED_WALLET = payload; } catch (_) {}
  try { localStorage.setItem('anet:walletConnection', JSON.stringify(payload)); } catch (_) {}
  try { window.dispatchEvent(new CustomEvent('anet:wallet-connected', { detail: payload })); } catch (_) {}
})();
''');
  }

  Future<void> _injectDexRuntimeCompat(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    final isDexPage =
        (host == 'a-network.net' || host == 'www.a-network.net') &&
        path.endsWith('/dex.html');
    if (!isDexPage) return;

    await _controller.runJavaScript('''
(() => {
  try {
    const STORAGE_KEY = 'anet:walletConnection';
    const syncWalletFromStorage = () => {
      try {
        const raw = localStorage.getItem(STORAGE_KEY);
        if (!raw) return false;
        const payload = JSON.parse(raw);
        if (!payload || !payload.wallet) return false;
        if (window.state && window.state.evmWallet) {
          window.state.evmWallet.address = String(payload.wallet).trim();
          window.state.evmWallet.chainId = parseInt(payload.chainId || 56, 10) || 56;
          window.state.evmWallet.balance = null;
          if (typeof window.updateEvmWalletUI === 'function') {
            window.updateEvmWalletUI();
          }
        }
        return true;
      } catch (_) {
        return false;
      }
    };

    window.openWalletApp = function(actionLabel = 'connect') {
      const action = String(actionLabel || 'connect').trim().toLowerCase();
      if (action === 'connect' && syncWalletFromStorage()) {
        if (typeof window.toast === 'function') {
          window.toast('Wallet connected from app session.', 'success', 2200);
        }
        return;
      }
      window.location.href = 'anetwork://invite?action=' + encodeURIComponent(action);
    };

    window.connectEvmWallet = async function() {
      if (syncWalletFromStorage()) {
        if (typeof window.toast === 'function') {
          window.toast('Wallet connected from app session.', 'success', 2400);
        }
        return;
      }
      window.openWalletApp('connect');
    };

    const evmBtn = document.getElementById('evm-wallet-btn');
    if (evmBtn) {
      evmBtn.innerHTML = '<span class="dot"></span><span>Open Wallet App</span>';
      evmBtn.onclick = () => window.openWalletApp('connect');
    }

    window.addEventListener('anet:wallet-connected', () => {
      syncWalletFromStorage();
    });

    syncWalletFromStorage();
  } catch (_) {}
})();
''');
  }

  Future<bool> _ensureSigningSession() async {
    final now = DateTime.now();
    if (_signingSessionExpiresAt != null &&
        _signingSessionExpiresAt!.isAfter(now)) {
      return true;
    }

    if (!widget.walletPinRequired) {
      _signingSessionExpiresAt = now.add(const Duration(minutes: 5));
      return true;
    }

    final pinCtrl = TextEditingController();
    final pinFocus = FocusNode();
    String localMessage = '';
    bool submitting = false;
    bool approved = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setLocalState) => AlertDialog(
          backgroundColor: const Color(0xFF0A1224),
          title: Text(
            context.l10n.walletPINVerificationTitle,
            style: TextStyle(color: Colors.cyanAccent),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.walletPINInstructions,
                style: TextStyle(color: Colors.white70, height: 1.35),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () =>
                    FocusScope.of(dialogContext).requestFocus(pinFocus),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final pinBoxCount = pinCtrl.text.length > 6 ? 8 : 6;
                    const gap = 8.0;
                    final raw =
                        (constraints.maxWidth - ((pinBoxCount - 1) * gap)) /
                        pinBoxCount;
                    final boxSize = raw.clamp(34.0, 52.0).toDouble();

                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: List.generate(pinBoxCount, (index) {
                        final hasValue = index < pinCtrl.text.length;
                        return Container(
                          width: boxSize,
                          height: boxSize + 4,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: hasValue
                                  ? Colors.cyanAccent
                                  : Colors.white24,
                            ),
                          ),
                          child: Text(
                            hasValue ? '•' : '',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: boxSize * 0.46,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 0,
                height: 0,
                child: TextField(
                  controller: pinCtrl,
                  focusNode: pinFocus,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  enableInteractiveSelection: false,
                  showCursor: false,
                  onChanged: (_) => setLocalState(() {}),
                  decoration: InputDecoration(counterText: ''),
                ),
              ),
              if (localMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    localMessage,
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: Text(
                context.l10n.cancelButton,
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final pin = pinCtrl.text.trim();
                      if (pin.length < 4 || pin.length > 8) {
                        setLocalState(() {
                          localMessage = 'PIN must be 4 to 8 digits';
                        });
                        return;
                      }

                      setLocalState(() {
                        submitting = true;
                        localMessage = '';
                      });

                      try {
                        await verifyWalletPinAPI(pin);
                        approved = true;
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                      } catch (e) {
                        setLocalState(() {
                          localMessage = e.toString().replaceFirst(
                            'Exception: ',
                            '',
                          );
                        });
                      } finally {
                        setLocalState(() {
                          submitting = false;
                        });
                      }
                    },
              child: Text(
                submitting ? 'Verifying...' : 'Verify',
                style: const TextStyle(color: Colors.cyanAccent),
              ),
            ),
          ],
        ),
      ),
    );

    pinFocus.dispose();
    pinCtrl.dispose();
    if (!approved) {
      return false;
    }

    _signingSessionExpiresAt = DateTime.now().add(const Duration(minutes: 5));
    return true;
  }

  Future<void> _approveSignatureRequest() async {
    final host = _connectedHost;
    if (host == null || host.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.connectWalletToDApp)));
      return;
    }

    final signingSessionReady = await _ensureSigningSession();
    if (!signingSessionReady) {
      return;
    }

    final seedPhrase = widget.walletSeedPhrase.trim();
    if (seedPhrase.isEmpty ||
        seedPhrase == 'Hidden for security' ||
        seedPhrase == 'No wallet created yet') {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.seedPhraseRequired)));
      return;
    }

    final messageCtrl = TextEditingController(
      text:
          'A-Network sign request on ${DateTime.now().toUtc().toIso8601String()}',
    );
    bool approved = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setLocalState) => AlertDialog(
          backgroundColor: const Color(0xFF0A1224),
          title: Text(
            context.l10n.signRequestTitle,
            style: TextStyle(color: Colors.cyanAccent),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'dApp: $host\nNetwork: ${widget.walletNetwork}',
                style: const TextStyle(color: Colors.white70, height: 1.35),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: messageCtrl,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: context.l10n.messageToSign,
                  hintStyle: TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: approved,
                onChanged: (v) {
                  setLocalState(() {
                    approved = v == true;
                  });
                },
                contentPadding: EdgeInsets.zero,
                title: Text(
                  context.l10n.approveSignature,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                context.l10n.cancelButton,
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: approved ? () => Navigator.pop(ctx) : null,
              child: Text(
                context.l10n.signButton,
                style: TextStyle(color: Colors.cyanAccent),
              ),
            ),
          ],
        ),
      ),
    );

    if (!approved || !mounted) {
      messageCtrl.dispose();
      return;
    }

    late final EthPrivateKey credentials;
    try {
      credentials = EthPrivateKey(_deriveEvmPrivateKeyFromMnemonic(seedPhrase));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      messageCtrl.dispose();
      return;
    }

    final message = messageCtrl.text.trim();
    final msgBytes = Uint8List.fromList(utf8.encode(message));
    final sigBytes = credentials.signPersonalMessageToUint8List(msgBytes);
    final signature = bytesToHex(sigBytes, include0x: true);
    final signerAddress = credentials.address.hexEip55;
    final payload = {
      'type': 'personal_sign',
      'host': host,
      'network': widget.walletNetwork,
      'chainId': _evmChainIdFromNetworkLabel(widget.walletNetwork),
      'walletAddress': widget.walletAddress,
      'signerAddress': signerAddress,
      'message': message,
      'messageHex': bytesToHex(msgBytes, include0x: true),
      'signature': signature,
      'signatureType': 'EIP-191 personal_sign',
      'issuedAt': DateTime.now().toUtc().toIso8601String(),
    };
    final jsonPayload = jsonEncode(payload);
    await _controller.runJavaScript('''
(() => {
  const payload = $jsonPayload;
  try { window.__ANET_LAST_SIGNATURE = payload; } catch (_) {}
  try { localStorage.setItem('anet:lastSignature', JSON.stringify(payload)); } catch (_) {}
  try { window.dispatchEvent(new CustomEvent('anet:wallet-signature', { detail: payload })); } catch (_) {}
})();
''');
    messageCtrl.dispose();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1224),
        title: Text(
          context.l10n.signatureApprovedTitle,
          style: TextStyle(color: Colors.greenAccent),
        ),
        content: SingleChildScrollView(
          child: SelectableText(
            jsonEncode(payload),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: jsonEncode(payload)));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.l10n.signaturePayloadCopied)),
              );
            },
            child: Text(
              context.l10n.copyButton,
              style: TextStyle(color: Colors.cyanAccent),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.l10n.closeButton,
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1224),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 4,
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.cyanAccent,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.cyanAccent),
        actions: [
          if (widget.walletExtensionMode)
            IconButton(
              tooltip: _connectedHost == null ? 'Connect wallet' : 'Disconnect',
              onPressed: () {
                if (_connectedHost == null) {
                  _approveConnectForCurrentHost();
                } else {
                  final host = _connectedHost;
                  setState(() {
                    _connectedHost = null;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Disconnected from ${host ?? 'dApp'}'),
                    ),
                  );
                }
              },
              icon: Icon(
                _connectedHost == null
                    ? Icons.link_rounded
                    : Icons.link_off_rounded,
                color: _connectedHost == null
                    ? Colors.cyanAccent
                    : Colors.orangeAccent,
              ),
            ),
          if (widget.walletExtensionMode)
            IconButton(
              tooltip: context.l10n.approveSignTooltip,
              onPressed: _approveSignatureRequest,
              icon: const Icon(Icons.draw_rounded, color: Colors.cyanAccent),
            ),
        ],
      ),
      body: Column(
        children: [
          if (widget.walletExtensionMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.white.withValues(alpha: 0.05),
              child: Text(
                _connectedHost == null
                    ? 'Wallet not connected. Trusted hosts only. Current: ${_currentHost.isEmpty ? 'none' : _currentHost}'
                    : 'Connected: $_connectedHost • ${widget.walletNetwork}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (widget.showUrlBar && widget.initialHtml == null)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _urlCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: context.l10n.enterURL,
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _go(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _go,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black,
                      ),
                      child: Text(context.l10n.goButton),
                    ),
                  ),
                ],
              ),
            ),
          if (widget.showUrlBar && widget.initialHtml == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.cyanAccent.withValues(alpha: 0.22),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Wallet Tip',
                      style: TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Use buttons for DEX/NFT/Explorer. Do not search deep links in Google.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _browserQuickBtn(
                          'Open DEX',
                          Icons.currency_exchange_rounded,
                          () {
                            if (widget.onOpenDex != null) {
                              widget.onOpenDex!();
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => DexSwapPage(
                                    walletAddress: widget.walletAddress,
                                    seedPhrase: widget.walletSeedPhrase,
                                    // The wallet field in the signed auth
                                    // MUST equal the address the chain
                                    // recovers from the signature (secp).
                                    // Using the legacy DB-stored address
                                    // here causes the chain to reject with
                                    // 'signature recovery does not match
                                    // action wallet'.
                                    signActionAuth: (actionType, seedPhrase) =>
                                        _buildSignedActionAuth(
                                          seedPhrase: seedPhrase,
                                          wallet: _deriveSecpAnetWalletFromSeed(
                                            seedPhrase,
                                          ),
                                          actionType: actionType,
                                        ),
                                    signWithKeyAuth: (actionType, keyBytes) =>
                                        _buildSignedActionAuthFromKey(
                                          privateKeyBytes: keyBytes,
                                          wallet:
                                              _deriveAnetAddressFromPrivateKeyBytes(
                                                keyBytes,
                                              ),
                                          actionType: actionType,
                                        ),
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                        if (widget.onOpenBridge != null)
                          _browserQuickBtn(
                            'Bridge to BSC',
                            Icons.swap_horiz_rounded,
                            () {
                              widget.onOpenBridge!();
                            },
                          ),
                        _browserQuickBtn(
                          'Open NFT',
                          Icons.emoji_objects_rounded,
                          () {
                            _urlCtrl.text = _anetNftUrl;
                            _controller.loadRequest(Uri.parse(_anetNftUrl));
                          },
                        ),
                        _browserQuickBtn(
                          'Explorer',
                          Icons.travel_explore_rounded,
                          () {
                            final url = '$_anetExplorerUrl/explorer';
                            _urlCtrl.text = url;
                            _controller.loadRequest(Uri.parse(url));
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (widget.showLoadingBar && _loading)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }

  Widget _browserQuickBtn(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.cyanAccent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.cyanAccent),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.cyanAccent,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// =======================
/// 📢 ADMOB BANNER AD
/// =======================
/// Stubbed out — Google AdMob has been fully removed (AdSense/AdMob ban).
/// Axon ads will replace this in a future release.
class BannerAdWidget extends StatelessWidget {
  const BannerAdWidget({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// =======================
/// ⛏ MINING PAGE
/// =======================
class MiningPage extends StatefulWidget {
  const MiningPage({super.key});

  @override
  State<MiningPage> createState() => _MiningPageState();
}

class _MiningPageState extends State<MiningPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _deepLinkSub;
  final PageController _pageController = PageController(initialPage: 0);
  late VideoPlayerController _mainVideoController;
  late final AnimationController _antWorkPulseController;
  late final Animation<double> _antWorkPulseScale;
  late final Animation<double> _antWorkPulseGlow;
  int _pageIndex = 0;
  // Footer banner ad fields removed (Google AdSense/AdMob ban). Axon ads TBD.
  _DisplayTheme _displayTheme = _DisplayTheme.classic;
  double balance = 0;
  bool isMining = false;
  bool isStartingMining = false;
  int remainingSeconds = 0;
  Map<String, dynamic>? network;
  Map<String, dynamic>? myRank;
  Map<String, dynamic>? _myReferralStats;
  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? _myProfile;
  Timer? timer;
  Timer? _statsRefreshTimer;
  final TextEditingController targetPriceController = TextEditingController();
  final TextEditingController webSearchController = TextEditingController();
  String walletAddress = 'Not created yet';
  String walletProvider = 'ANET Web2 Wallet';
  String createdWalletAddress = 'Not created';
  String createdSeedPhrase = 'Hidden for security';
  String migrationWalletAddress = 'Not set';
  bool hasCreatedWallet = false;
  bool walletPinEnabled = false;
  bool walletSeedOtpRequired = true;
  String walletScheme = 'legacy_hash_v1';
  bool walletL1SendEnabled = false;
  bool sessionGateBypassEnabled = false;
  bool _walletUnlockedForSession = false;
  Timer? _mainVideoInitTimer;
  String walletAnetBalance = '-- ANET';
  String walletOnchainBalance = '-- ANET';
  int walletTrackedAnts = 0;
  List<Map<String, dynamic>> _walletCoinHistory = const [];
  bool _walletHistoryLoading = false;
  String _selectedEvmNetwork = 'ANET L1 Bridge';
  List<Map<String, String>> _customCoins = const [];
  Map<String, String> _customCoinBalances = const {};
  bool _customCoinBalanceLoading = false;
  List<Map<String, dynamic>> _customTokenActivity = const [];
  bool _customTokenActivityLoading = false;
  int _walletTabIndex = 0; // 0=Home, 1=Assets, 2=Activity, 3=Sessions
  List<Map<String, dynamic>> _miningSessionHistory = const [];
  bool _miningSessionHistoryLoading = false;
  bool _miningSessionHistoryLoadingMore = false;
  Map<String, dynamic> _miningProfileData = const {};
  int _miningSessionTotal = 0;
  List<Map<String, dynamic>> _networkMiningRoster = const [];
  Map<String, dynamic> _networkMiningSummary = const {};
  bool _networkMiningRosterLoading = false;
  String? _networkMiningRosterError;
  int _miningSessionOldestOffset = 0;
  static const int _miningSessionPageSize = 50;
  final PageController _announcementPageController = PageController();
  Timer? _announcementTimer;
  int _announcementPage = 0;
  String globalAnetMined = '-- ANET';
  String tokenPrice = 'Future market reference';
  String autoStatus = 'Idle';
  String anetContract = '0x791055A7d52AA392eaE8De04250497f33807E46A';
  String anetDexPair = '0xb90071e377a31a6ea2cfdebe19a4d5226c420b6b';
  static final Uri _privacyPolicyUri = Uri.parse(
    'https://a-network.net/privacy.html',
  );
  static final Uri _termsUri = Uri.parse('https://a-network.net/terms.html');
  static const String _xAnnouncementUrl = 'https://x.com/Mr_A_Awakening';
  bool _isCompletingMining = false;
  bool _miningCompletionNotificationShown = false;
  DateTime? _miningEndsAt;
  Map<String, int> _countryUsersMap = {};
  List<String> _countryNames = const [];

  bool get _isAntsTheme => _displayTheme == _DisplayTheme.ants;
  bool get _isStudioTheme => _displayTheme == _DisplayTheme.studio;
  bool get _isExecutiveTheme => _displayTheme == _DisplayTheme.executive;
  bool get _isPaperTheme => _displayTheme == _DisplayTheme.paper;
  bool get _isLightStageTheme => _isStudioTheme || _isPaperTheme;
  String get _displayThemeLabel => switch (_displayTheme) {
    _DisplayTheme.classic => 'Classic',
    _DisplayTheme.ants => 'ANTS',
    _DisplayTheme.studio => 'Studio Light',
    _DisplayTheme.executive => 'Executive Dark',
    _DisplayTheme.paper => 'Paper Light',
  };
  Color get _themeAccent => switch (_displayTheme) {
    _DisplayTheme.classic => const Color(0xFF68D2FF),
    _DisplayTheme.ants => const Color(0xFF6AE7B1),
    _DisplayTheme.studio => const Color(0xFF2C74B7),
    _DisplayTheme.executive => const Color(0xFFD6C08A),
    _DisplayTheme.paper => const Color(0xFF315E7F),
  };
  Color get _themeAccentAlt => switch (_displayTheme) {
    _DisplayTheme.classic => const Color(0xFF2FAEF7),
    _DisplayTheme.ants => const Color(0xFF59C9FF),
    _DisplayTheme.studio => const Color(0xFF5B96C9),
    _DisplayTheme.executive => const Color(0xFF8FB5D6),
    _DisplayTheme.paper => const Color(0xFF6A8CA5),
  };
  Color get _themeGold => switch (_displayTheme) {
    _DisplayTheme.classic => const Color(0xFFFFB74D),
    _DisplayTheme.ants => const Color(0xFFFFC35D),
    _DisplayTheme.studio => const Color(0xFFE2AA52),
    _DisplayTheme.executive => const Color(0xFFE0B66E),
    _DisplayTheme.paper => const Color(0xFFC58E57),
  };
  Color get _themeLime => switch (_displayTheme) {
    _DisplayTheme.classic => const Color(0xFF9AF7D8),
    _DisplayTheme.ants => const Color(0xFFD3FF78),
    _DisplayTheme.studio => const Color(0xFF9FD7C1),
    _DisplayTheme.executive => const Color(0xFFA9D4C0),
    _DisplayTheme.paper => const Color(0xFF89B99A),
  };
  Color get _themeBackground => switch (_displayTheme) {
    _DisplayTheme.classic => const Color(0xFF02040F),
    _DisplayTheme.ants => const Color(0xFF041019),
    _DisplayTheme.studio => const Color(0xFF102236),
    _DisplayTheme.executive => const Color(0xFF0A1019),
    _DisplayTheme.paper => const Color(0xFFEEE5D8),
  };
  Color get _themeBackgroundAlt => switch (_displayTheme) {
    _DisplayTheme.classic => const Color(0xFF05070F),
    _DisplayTheme.ants => const Color(0xFF081827),
    _DisplayTheme.studio => const Color(0xFF162C43),
    _DisplayTheme.executive => const Color(0xFF141D29),
    _DisplayTheme.paper => const Color(0xFFD9CDBD),
  };
  Color get _themePanel => switch (_displayTheme) {
    _DisplayTheme.classic => const Color(0xCC08162B),
    _DisplayTheme.ants => const Color(0xDD0A1827),
    _DisplayTheme.studio => const Color(0xD6112134),
    _DisplayTheme.executive => const Color(0xD7172433),
    _DisplayTheme.paper => const Color(0xD91B2A36),
  };
  Color get _themeMutedText => switch (_displayTheme) {
    _DisplayTheme.classic => Colors.white70,
    _DisplayTheme.ants => const Color(0xFF9AB3C8),
    _DisplayTheme.studio => const Color(0xFFB8C8D8),
    _DisplayTheme.executive => const Color(0xFFB8C0CB),
    _DisplayTheme.paper => const Color(0xFFD3D9DF),
  };
  Color get _themeOnAccent => switch (_displayTheme) {
    _DisplayTheme.classic => Colors.black,
    _DisplayTheme.ants => Colors.black,
    _DisplayTheme.studio => Colors.white,
    _DisplayTheme.executive => const Color(0xFF101722),
    _DisplayTheme.paper => Colors.white,
  };
  Color get _themeTabShell => switch (_displayTheme) {
    _DisplayTheme.classic => const Color(0xFF0D2340),
    _DisplayTheme.ants => const Color(0xFF0D2032),
    _DisplayTheme.studio => const Color(0xFF18314A),
    _DisplayTheme.executive => const Color(0xFF141C28),
    _DisplayTheme.paper => const Color(0xFF223240),
  };
  Color get _themeTabSelectedFill => switch (_displayTheme) {
    _DisplayTheme.classic => const Color(0xFF103662),
    _DisplayTheme.ants => const Color(0xFF163555),
    _DisplayTheme.studio => const Color(0xFF21486A),
    _DisplayTheme.executive => const Color(0xFF243246),
    _DisplayTheme.paper => const Color(0xFF35546A),
  };
  Color get _themeTabSelectedIcon => switch (_displayTheme) {
    _DisplayTheme.classic => const Color(0xFF68D2FF),
    _DisplayTheme.ants => _themeAccent,
    _DisplayTheme.studio => const Color(0xFFEAF6FF),
    _DisplayTheme.executive => _themeAccent,
    _DisplayTheme.paper => const Color(0xFFF5F1EA),
  };
  Color get _themeTabIdleIcon => switch (_displayTheme) {
    _DisplayTheme.classic => const Color(0xFF86A0BC),
    _DisplayTheme.ants => const Color(0xFF93A8BD),
    _DisplayTheme.studio => const Color(0xFF9BB2C8),
    _DisplayTheme.executive => const Color(0xFF97A1AF),
    _DisplayTheme.paper => const Color(0xFFBAC3CB),
  };
  Color get _themeTabSelectedLabel => switch (_displayTheme) {
    _DisplayTheme.classic => const Color(0xFFEAF6FF),
    _DisplayTheme.ants => const Color(0xFFF4FBFF),
    _DisplayTheme.studio => const Color(0xFFF7FBFF),
    _DisplayTheme.executive => const Color(0xFFF7F1E5),
    _DisplayTheme.paper => const Color(0xFFF6F2EB),
  };
  Color get _themeTabIdleLabel => switch (_displayTheme) {
    _DisplayTheme.classic => const Color(0xFF86A0BC),
    _DisplayTheme.ants => const Color(0xFF9EB0C2),
    _DisplayTheme.studio => const Color(0xFF9BB2C8),
    _DisplayTheme.executive => const Color(0xFF9AA4B2),
    _DisplayTheme.paper => const Color(0xFFC5CDD3),
  };
  List<Color> get _themeStageGradient => switch (_displayTheme) {
    _DisplayTheme.classic => [
      _themeBackground,
      _themeBackgroundAlt,
      Colors.black,
    ],
    _DisplayTheme.ants => [_themeBackground, _themeBackgroundAlt, Colors.black],
    _DisplayTheme.studio => const [
      Color(0xFFF9FBFD),
      Color(0xFFE8EEF4),
      Color(0xFFD7E2EE),
    ],
    _DisplayTheme.executive => const [
      Color(0xFF121822),
      Color(0xFF090D14),
      Color(0xFF05070B),
    ],
    _DisplayTheme.paper => const [
      Color(0xFFF6EFE6),
      Color(0xFFE7DCCD),
      Color(0xFFD7C7B4),
    ],
  };
  double get _themeStageOverlayOpacity => switch (_displayTheme) {
    _DisplayTheme.classic => 0.56,
    _DisplayTheme.ants => 0.34,
    _DisplayTheme.studio => 0.42,
    _DisplayTheme.executive => 0.50,
    _DisplayTheme.paper => 0.20,
  };
  double get _themeHomeOverlayOpacity => switch (_displayTheme) {
    _DisplayTheme.classic => 0.46,
    _DisplayTheme.ants => 0.34,
    _DisplayTheme.studio => 0.14,
    _DisplayTheme.executive => 0.38,
    _DisplayTheme.paper => 0.12,
  };

  Widget _themedParticleBackground() {
    return ParticleBackground(
      particleCount: _isStudioTheme
          ? 92
          : (_isPaperTheme ? 86 : (_isExecutiveTheme ? 88 : 80)),
      particleRadius: _isLightStageTheme
          ? 1.65
          : (_isExecutiveTheme ? 1.9 : 2.5),
      linkDistance: _isLightStageTheme ? 110 : (_isExecutiveTheme ? 70 : 0),
      driftX: _isStudioTheme
          ? 72
          : (_isPaperTheme ? 54 : (_isExecutiveTheme ? 84 : 150)),
      driftY: _isStudioTheme
          ? 52
          : (_isPaperTheme ? 38 : (_isExecutiveTheme ? 60 : 100)),
      particleColor: switch (_displayTheme) {
        _DisplayTheme.studio => const Color(0xFF4D7CA6),
        _DisplayTheme.executive => const Color(0xFFB8A67D),
        _DisplayTheme.paper => const Color(0xFF9C8369),
        _ => _themeAccent,
      },
      linkColor: switch (_displayTheme) {
        _DisplayTheme.studio => const Color(0xFF8EB0CF),
        _DisplayTheme.executive => const Color(0xFF7E96B0),
        _DisplayTheme.paper => const Color(0xFF8DA4B5),
        _ => _themeAccentAlt,
      },
    );
  }

  BoxDecoration _panelDecoration({bool emphasis = false, bool warm = false}) {
    final start = warm
        ? _themeGold.withValues(
            alpha: _isStudioTheme ? 0.18 : (_isAntsTheme ? 0.16 : 0.12),
          )
        : (emphasis
              ? _themeAccent.withValues(
                  alpha: _isStudioTheme ? 0.18 : (_isAntsTheme ? 0.20 : 0.14),
                )
              : Colors.white.withValues(
                  alpha: _isStudioTheme ? 0.05 : (_isAntsTheme ? 0.03 : 0.04),
                ));
    final end = warm
        ? _themeAccent.withValues(
            alpha: _isStudioTheme ? 0.08 : (_isAntsTheme ? 0.08 : 0.04),
          )
        : _themePanel;

    return BoxDecoration(
      gradient: LinearGradient(
        colors: [start, end],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      color: _themePanel,
      borderRadius: BorderRadius.circular(emphasis ? 22 : 18),
      border: Border.all(
        color: (warm ? _themeGold : _themeAccentAlt).withValues(
          alpha: _isStudioTheme ? 0.24 : (_isAntsTheme ? 0.28 : 0.22),
        ),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(
            alpha: _isStudioTheme ? 0.20 : (_isAntsTheme ? 0.28 : 0.40),
          ),
          blurRadius: emphasis ? 28 : 22,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: (warm ? _themeGold : _themeAccentAlt).withValues(
            alpha: _isStudioTheme ? 0.07 : (_isAntsTheme ? 0.10 : 0.08),
          ),
          blurRadius: emphasis ? 32 : 24,
          spreadRadius: 1,
        ),
      ],
    );
  }

  Future<void> _loadDisplayTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('display_theme_mode') ?? 'classic';
    if (!mounted) return;
    setState(() {
      _displayTheme = switch (savedTheme) {
        'ants' => _DisplayTheme.ants,
        'studio' => _DisplayTheme.studio,
        'executive' => _DisplayTheme.executive,
        'paper' => _DisplayTheme.paper,
        _ => _DisplayTheme.classic,
      };
    });
  }

  Future<void> _setDisplayTheme(_DisplayTheme nextTheme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('display_theme_mode', switch (nextTheme) {
      _DisplayTheme.ants => 'ants',
      _DisplayTheme.studio => 'studio',
      _DisplayTheme.executive => 'executive',
      _DisplayTheme.paper => 'paper',
      _DisplayTheme.classic => 'classic',
    });
    if (!mounted) return;
    setState(() {
      _displayTheme = nextTheme;
    });
  }

  Future<void> _persistMiningEnd(DateTime endsAt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_miningEndsAtStorageKey, endsAt.millisecondsSinceEpoch);
  }

  Future<void> _clearPersistedMiningEnd() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_miningEndsAtStorageKey);
  }

  Future<void> _syncMiningReminder({
    DateTime? endsAt,
    bool clear = false,
  }) async {
    if (clear) {
      await _clearPersistedMiningEnd();
      await NotificationService.cancelMiningNotification();
      return;
    }

    if (endsAt == null) {
      return;
    }

    await _persistMiningEnd(endsAt);

    if (endsAt.isAfter(DateTime.now())) {
      await NotificationService.scheduleMiningCompleteNotificationAt(endsAt);
    }
  }

  Future<void> _restoreMiningReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final persistedEndsAtMs = prefs.getInt(_miningEndsAtStorageKey);
    if (persistedEndsAtMs == null) {
      return;
    }

    final persistedEndsAt = DateTime.fromMillisecondsSinceEpoch(
      persistedEndsAtMs,
    );

    _miningEndsAt = persistedEndsAt;

    if (persistedEndsAt.isAfter(DateTime.now())) {
      await NotificationService.scheduleMiningCompleteNotificationAt(
        persistedEndsAt,
      );
    }
  }

  bool _hasUsableLocalSeedPhrase([String? seed]) {
    final candidate = (seed ?? createdSeedPhrase).trim();
    if (candidate.isEmpty) return false;
    if (candidate == 'Hidden for security' ||
        candidate == 'No wallet created yet') {
      return false;
    }
    // EVM-imported wallets store raw private key as 'evmkey:HEX'
    if (candidate.startsWith('evmkey:') && candidate.length > 14) return true;
    return candidate.contains(' ');
  }

  Future<void> _copyText(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied')));
  }

  Future<void> _openReferralUrl(String rawUrl) async {
    final uri = Uri.parse(rawUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open referral link')),
      );
    }
  }

  Future<Map<String, String>> _resolveReferralLinks() async {
    String inviteCode = '';
    try {
      final stats = await getMyReferralStats();
      inviteCode = stats['inviteCode']?.toString().trim() ?? '';
      if (mounted) {
        setState(() {
          _myReferralStats = stats;
        });
      }
    } catch (_) {
      final stats = _myReferralStats ?? const {};
      inviteCode = stats['inviteCode']?.toString().trim() ?? '';
    }

    if (inviteCode.isEmpty) {
      throw Exception('Invite code is not available yet. Please try again.');
    }

    final google = 'https://a-network.net/?ref=$inviteCode&src=google';
    final apk = 'https://a-network.net/?ref=$inviteCode&src=apk';
    final share =
        'Join my A-Network colony with my Ant Code: $inviteCode\n'
        'Google link: $google\n'
        'APK link: $apk';

    return {
      'inviteCode': inviteCode,
      'google': google,
      'apk': apk,
      'share': share,
    };
  }

  Future<void> _showAntLinkActions() async {
    try {
      final links = await _resolveReferralLinks();
      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0A1224),
          title: Text(
            context.l10n.myAntCodeTitle,
            style: TextStyle(color: Colors.cyanAccent),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ant Code: ${links['inviteCode']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                links['google']!,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 4),
              SelectableText(
                links['apk']!,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => _openReferralUrl(links['google']!),
              child: Text(
                context.l10n.openGoogleLink,
                style: TextStyle(color: Colors.cyanAccent),
              ),
            ),
            TextButton(
              onPressed: () => _openReferralUrl(links['apk']!),
              child: Text(
                context.l10n.openAPKLink,
                style: TextStyle(color: Colors.cyanAccent),
              ),
            ),
            TextButton(
              onPressed: () => _copyText(links['share']!, 'Share message'),
              child: Text(
                context.l10n.copyShareText,
                style: TextStyle(color: Colors.cyanAccent),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                context.l10n.closeButton,
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _loadReferralStats() async {
    try {
      final stats = await getMyReferralStats();
      if (!mounted) return;
      setState(() {
        _myReferralStats = stats;
      });
    } catch (_) {}
  }

  Future<void> _showReferralTrackerDialog() async {
    await _loadReferralStats();

    final stats = _myReferralStats ?? {};
    final inviteCode =
        (stats['inviteCode']?.toString().trim().isNotEmpty ?? false)
        ? stats['inviteCode'].toString().trim()
        : 'Loading...';
    final directReferrals =
        int.tryParse((stats['directReferrals'] ?? 0).toString()) ?? 0;
    final completed1k =
        int.tryParse((stats['directReferralsCompleted1k'] ?? 0).toString()) ??
        0;
    final totalReferralSessions =
        int.tryParse((stats['totalReferralSessions'] ?? 0).toString()) ?? 0;
    final mySessions =
        int.tryParse((stats['mySuccessfulSessions'] ?? 0).toString()) ?? 0;
    final remaining =
        int.tryParse((stats['myRemainingTo1k'] ?? 1000).toString()) ?? 1000;
    final target =
        int.tryParse((stats['levelTargetSessions'] ?? 1000).toString()) ?? 1000;
    final referralProgress =
        (stats['referralProgress'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map(
              (item) => Map<String, dynamic>.from(item.cast<String, dynamic>()),
            )
            .toList();
    final shareLinkGoogle = 'https://a-network.net/?ref=$inviteCode&src=google';
    final shareLinkApk = 'https://a-network.net/?ref=$inviteCode&src=apk';
    final shareText =
        'Join my A-Network colony with my Ant Code: $inviteCode\n'
        'Google link: $shareLinkGoogle\n'
        'APK link: $shareLinkApk';
    final hasCoreWallet =
        hasCreatedWallet && createdWalletAddress.startsWith('0x');

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF08162B),
        title: Text(
          context.l10n.colonyTrackerTitle,
          style: TextStyle(color: Colors.cyanAccent),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.62,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.colonyDescription,
                    style: TextStyle(color: Colors.white70, height: 1.35),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.l10n.operatingModel,
                    style: TextStyle(color: Colors.white70, height: 1.35),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    hasCoreWallet
                        ? 'Future ANET Core note: this account already has a Web3 wallet ready for later partner onboarding. If a future BNB Chain buy-in rule such as 10 USDT equivalent is introduced, it will be enforced separately from mining and separately from colony scoring.'
                        : 'Future ANET Core note: later partner onboarding may use a separate Web3 wallet requirement, but no buy-in or buyer gate is enforced in this build.',
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.yourAntCode,
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    inviteCode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.referralLinksLabel,
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    shareLinkGoogle,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    shareLinkApk,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.l10n.directColonyAnts(directReferrals.toString()),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Text(
                    context.l10n.colonyCompleted1K(completed1k.toString()),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Text(
                    context.l10n.totalColonySessions(
                      totalReferralSessions.toString(),
                    ),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.communityVisibilityOnly,
                    style: TextStyle(color: Colors.cyanAccent, height: 1.35),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.blockchainTransparency,
                    style: TextStyle(color: Colors.white70, height: 1.35),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your Completed Sessions: $mySessions / $target',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Text(
                    'Remaining to 1k: $remaining',
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    context.l10n.colonySessionProgress,
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (referralProgress.isEmpty)
                    Text(
                      context.l10n.noColonyAnts,
                      style: TextStyle(color: Colors.white54),
                    ),
                  ...referralProgress.map((item) {
                    final label = (item['label'] ?? 'Colony Ant').toString();
                    final sessions =
                        int.tryParse(
                          (item['successfulSessions'] ?? 0).toString(),
                        ) ??
                        0;
                    final referralRemaining =
                        int.tryParse(
                          (item['remainingTo1k'] ?? 1000).toString(),
                        ) ??
                        1000;
                    final completed = item['completed1k'] == true;

                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D213E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Completed Sessions: $sessions / 1000',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          Text(
                            completed
                                ? 'Qualified for 1k milestone'
                                : 'Remaining to 1k: $referralRemaining',
                            style: TextStyle(
                              color: completed
                                  ? Colors.greenAccent
                                  : Colors.orangeAccent,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _copyText(inviteCode, 'Ant Code'),
            child: Text(
              context.l10n.copyAntCode,
              style: TextStyle(color: Colors.cyanAccent),
            ),
          ),
          TextButton(
            onPressed: () => _copyText(shareText, 'Share message'),
            child: Text(
              context.l10n.shareColony,
              style: TextStyle(color: Colors.cyanAccent),
            ),
          ),
          TextButton(
            onPressed: () => _copyText(shareLinkGoogle, 'Google referral link'),
            child: Text(
              context.l10n.copyGoogleLink,
              style: TextStyle(color: Colors.cyanAccent),
            ),
          ),
          TextButton(
            onPressed: () => _copyText(shareLinkApk, 'APK referral link'),
            child: Text(
              context.l10n.copyAPKLink,
              style: TextStyle(color: Colors.cyanAccent),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.l10n.closeButton,
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  /// Shown when an in-app "Open DEX" / "Bridge" action can't get the wallet
  /// seed from the server (it's missing or corrupt). Instead of dead-ending on
  /// a snackbar, this offers a one-tap route into the wallet Reveal / recovery
  /// dialog, which auto-restores from a local backup if one exists or lets the
  /// user create a fresh wallet (balance & history preserved).
  Future<void> _promptSeedRecovery(BuildContext ctx, String message) async {
    if (!ctx.mounted) return;
    final go = await showDialog<bool>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1224),
        title: const Text(
          'Wallet recovery needed',
          style: TextStyle(color: Colors.cyanAccent),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: const Text(
              'Not now',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dctx, true),
            child: const Text(
              'Open Wallet',
              style: TextStyle(color: Colors.cyanAccent),
            ),
          ),
        ],
      ),
    );
    if (go == true && mounted) {
      await _showSeedPhraseDialog();
    }
  }

  Future<void> _showSeedPhraseDialog() async {
    if (!hasCreatedWallet) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Create wallet first')));
      return;
    }

    final pinCtrl = TextEditingController();
    final otpCtrl = TextEditingController();
    bool otpRequested = false;
    String revealedSeed = '';
    bool revealedSeedIsBip39 = false;
    String revealedPrivateKey =
        ''; // Set when wallet was imported by private key.
    bool revealedIsImported =
        false; // True for evmkey: imports (no seed phrase exists).
    String localMessage = '';
    // True when the server seed is unreadable AND this device has no local
    // seed → the only recovery is to provision a brand-new wallet.
    bool offerWalletRecovery = false;
    bool recoveringWallet = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          backgroundColor: const Color(0xFF0A1224),
          title: Text(
            context.l10n.seedPhraseBackupTitle,
            style: TextStyle(color: Colors.cyanAccent),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.securityCheckRequired,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: context.l10n.walletPINHint,
                    hintStyle: TextStyle(color: Colors.white54),
                    counterText: '',
                  ),
                ),
                if (walletSeedOtpRequired) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () async {
                          try {
                            final data = await requestSeedOtpAPI(
                              pinCtrl.text.trim(),
                            );
                            if (!mounted) return;
                            setLocalState(() {
                              otpRequested = true;
                              localMessage =
                                  data['message']?.toString() ??
                                  'Verification code sent';
                            });
                          } catch (e) {
                            setLocalState(() {
                              localMessage = e.toString().replaceFirst(
                                'Exception: ',
                                '',
                              );
                            });
                          }
                        },
                        child: Text(
                          context.l10n.sendOTPButton,
                          style: TextStyle(color: Colors.cyanAccent),
                        ),
                      ),
                    ],
                  ),
                  if (otpRequested) ...[
                    TextField(
                      controller: otpCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: context.l10n.emailOTPHint,
                        hintStyle: TextStyle(color: Colors.white54),
                        counterText: '',
                      ),
                    ),
                  ],
                ],
                if (localMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      localMessage,
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                  ),
                if (revealedPrivateKey.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.neverSharePhrase,
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    revealedIsImported
                        ? 'This wallet was imported using a private key. There is no 12-word seed phrase for this account. Export the private key below to import into MetaMask or another wallet.'
                        : 'Legacy wallet detected. The 12-word phrase is not available, but the private key below can import this wallet into MetaMask (choose "Import Account" → "Private Key").',
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    revealedPrivateKey,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
                if (revealedSeed.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.neverSharePhrase,
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!revealedSeedIsBip39) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Legacy seed detected. MetaMask import by phrase may fail. Use "Copy Private Key" and import with Private Key in MetaMask.',
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SelectableText(
                    revealedSeed,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (revealedSeed.isNotEmpty)
              TextButton(
                onPressed: () => _copyText(revealedSeed, 'Seed phrase'),
                child: Text(
                  context.l10n.copyButton,
                  style: TextStyle(color: Colors.cyanAccent),
                ),
              ),
            if (revealedPrivateKey.isNotEmpty)
              TextButton(
                onPressed: () => _copyText(revealedPrivateKey, 'Private key'),
                child: const Text(
                  'Copy Private Key',
                  style: TextStyle(color: Colors.amberAccent),
                ),
              ),
            if (revealedSeed.isNotEmpty && !revealedSeedIsBip39)
              TextButton(
                onPressed: () {
                  final legacyPrivHex = bytesToHex(
                    _deriveAnetPrivateKeyFromSeed(revealedSeed),
                    include0x: false,
                  );
                  _copyText(legacyPrivHex, 'Private key');
                },
                child: const Text(
                  'Copy Private Key',
                  style: TextStyle(color: Colors.amberAccent),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                context.l10n.closeButton,
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () async {
                if (walletSeedOtpRequired && !otpRequested) {
                  setLocalState(() {
                    localMessage =
                        'Tap "Send OTP" first to receive your verification code.';
                  });
                  return;
                }
                try {
                  final reveal = await revealSeedAPI(
                    pinCtrl.text.trim(),
                    otp: walletSeedOtpRequired ? otpCtrl.text.trim() : null,
                  );
                  final localSeed = _hasUsableLocalSeedPhrase()
                      ? createdSeedPhrase.trim()
                      : '';
                  final serverSeedFromApi =
                      reveal['seedPhrase']?.toString().trim() ?? '';
                  final localFallback = reveal['localSeedFallback'] == true;
                  final serverCorrupt = reveal['serverSeedCorrupt'] == true;
                  final serverMessage =
                      reveal['message']?.toString().trim() ?? '';

                  // Auto-heal: server can't decrypt our seed but the device
                  // still has a valid local backup. Push it back to the
                  // server (which verifies it derives to our wallet address
                  // before accepting) so future reveals work normally.
                  bool autoHealed = false;
                  if (serverCorrupt &&
                      serverSeedFromApi.isEmpty &&
                      localSeed.isNotEmpty &&
                      !localSeed.startsWith('evmkey:')) {
                    final normalizedLocal = localSeed
                        .trim()
                        .toLowerCase()
                        .replaceAll(RegExp(r'\s+'), ' ');
                    if (bip39.validateMnemonic(normalizedLocal)) {
                      try {
                        await backupSeedAPI(pinCtrl.text.trim(), localSeed);
                        autoHealed = true;
                      } catch (healErr) {
                        // Heal failed — still show the local seed; user can
                        // re-try backup later. Don't block the reveal.
                        debugPrint('[reveal] backup heal failed: $healErr');
                      }
                    }
                  }

                  setLocalState(() {
                    // Reset all reveal outputs before deciding which to show.
                    revealedSeed = '';
                    revealedSeedIsBip39 = false;
                    revealedPrivateKey = '';
                    revealedIsImported = false;

                    // Pick the best available source: server first, then local.
                    String candidate = serverSeedFromApi;
                    bool candidateFromLocal = false;
                    if (candidate.isEmpty &&
                        (localFallback || serverCorrupt) &&
                        localSeed.isNotEmpty) {
                      candidate = localSeed;
                      candidateFromLocal = true;
                    }

                    if (candidate.isEmpty) {
                      // Nothing recoverable from server or device.
                      if (serverCorrupt) {
                        // Server seed is lost AND no local seed exists here.
                        // Offer to provision a fresh wallet for this account.
                        offerWalletRecovery = true;
                        localMessage =
                            'Your old wallet recovery key could not be restored, and this device has no saved copy. You can create a new secure wallet below — your balance and history stay on your account.';
                      } else {
                        localMessage = serverMessage.isNotEmpty
                            ? serverMessage
                            : 'No seed phrase backup is stored for this account, and this device has no local copy. If you created this wallet on another device, sign in there to reveal it.';
                      }
                      return;
                    }

                    if (candidate.startsWith('evmkey:')) {
                      // Imported wallet — there is no seed phrase. Surface the
                      // raw private key with appropriate labeling instead of
                      // pretending the evmkey: string is a mnemonic.
                      revealedPrivateKey = candidate
                          .substring('evmkey:'.length)
                          .trim();
                      revealedIsImported = true;
                      localMessage =
                          'This wallet was imported by private key — no 12-word seed phrase exists for it.';
                      return;
                    }

                    revealedSeed = candidate;
                    final normalizedSeed = revealedSeed
                        .trim()
                        .toLowerCase()
                        .replaceAll(RegExp(r'\s+'), ' ');
                    revealedSeedIsBip39 = bip39.validateMnemonic(
                      normalizedSeed,
                    );

                    if (!candidateFromLocal) {
                      localMessage = revealedSeedIsBip39
                          ? 'Seed phrase revealed securely'
                          : 'Legacy seed revealed. For MetaMask, import using Private Key.';
                    } else if (autoHealed) {
                      localMessage =
                          'Server backup was unreadable — restored from this device. Your seed is now safely backed up again.';
                    } else {
                      localMessage =
                          'Recovered your older local backup seed on this device';
                    }
                  });
                } catch (e) {
                  setLocalState(() {
                    localMessage = e.toString().replaceFirst('Exception: ', '');
                  });
                }
              },
              child: Text(
                context.l10n.revealButton,
                style: TextStyle(color: Colors.cyanAccent),
              ),
            ),
            if (offerWalletRecovery)
              TextButton(
                onPressed: recoveringWallet
                    ? null
                    : () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dctx) => AlertDialog(
                            backgroundColor: const Color(0xFF0A1224),
                            title: const Text(
                              'Create a new wallet?',
                              style: TextStyle(color: Colors.cyanAccent),
                            ),
                            content: const Text(
                              'This creates a brand-new wallet and recovery '
                              'phrase for your account. Your balance and '
                              'history are preserved. Your old wallet address '
                              'and its unreadable seed will be replaced and '
                              'cannot be restored afterward. Continue?',
                              style: TextStyle(
                                color: Colors.white70,
                                height: 1.35,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dctx, false),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(dctx, true),
                                child: const Text(
                                  'Create new wallet',
                                  style: TextStyle(color: Colors.cyanAccent),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true) return;
                        setLocalState(() {
                          recoveringWallet = true;
                          localMessage = 'Creating your new secure wallet…';
                        });
                        try {
                          final res = await recoverNewWalletAPI(
                            pinCtrl.text.trim(),
                          );
                          final newSeed =
                              res['oneTimeSeedPhrase']?.toString().trim() ?? '';
                          final newAddr =
                              (res['wallet']
                                      as Map<
                                        String,
                                        dynamic
                                      >?)?['displayAddress']
                                  ?.toString() ??
                              '';
                          if (newSeed.isNotEmpty) {
                            await saveWalletSeedSecure(newSeed);
                          }
                          if (!mounted) return;
                          await _syncWalletFromServer();
                          setLocalState(() {
                            recoveringWallet = false;
                            offerWalletRecovery = false;
                            revealedSeed = newSeed;
                            revealedSeedIsBip39 = newSeed.contains(' ');
                            localMessage =
                                'New wallet created${newAddr.isNotEmpty ? ' ($newAddr)' : ''}. Write down your new recovery phrase now — it is shown only once.';
                          });
                        } catch (e) {
                          setLocalState(() {
                            recoveringWallet = false;
                            localMessage = e.toString().replaceFirst(
                              'Exception: ',
                              '',
                            );
                          });
                        }
                      },
                child: Text(
                  recoveringWallet ? 'Creating…' : 'Create New Wallet',
                  style: const TextStyle(color: Colors.amberAccent),
                ),
              ),
          ],
        ),
      ),
    );

    pinCtrl.dispose();
    otpCtrl.dispose();
  }

  Future<void> _showSetPinDialog({bool isChange = false}) async {
    final emailCtrl = TextEditingController(text: (currentEmail ?? '').trim());
    final otpCtrl = TextEditingController();
    final currentCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool otpRequested = false;
    bool localSubmitting = false;
    String localMessage = '';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          backgroundColor: const Color(0xFF0A1224),
          title: Text(
            isChange ? 'Change Wallet PIN' : 'Set Wallet PIN',
            style: const TextStyle(color: Colors.cyanAccent),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isChange)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      context.l10n.changePINRequiresOTP,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.35,
                      ),
                    ),
                  ),
                if (isChange)
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: context.l10n.registeredEmail,
                    ),
                  ),
                if (isChange) const SizedBox(height: 8),
                if (isChange)
                  TextField(
                    controller: currentCtrl,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 8,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: context.l10n.currentPIN,
                      counterText: '',
                    ),
                  ),
                if (isChange)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: localSubmitting
                          ? null
                          : () async {
                              final email = emailCtrl.text.trim().toLowerCase();
                              if (email.isEmpty) {
                                setLocalState(
                                  () => localMessage =
                                      'Enter your registered email first',
                                );
                                return;
                              }

                              try {
                                final res = await requestPinResetAPI(email);
                                setLocalState(() {
                                  otpRequested = true;
                                  localMessage =
                                      res['message']?.toString() ??
                                      'OTP sent to your email';
                                });
                              } catch (e) {
                                setLocalState(() {
                                  localMessage = e.toString().replaceFirst(
                                    'Exception: ',
                                    '',
                                  );
                                });
                              }
                            },
                      child: Text(
                        otpRequested ? 'Resend OTP' : 'Send OTP',
                        style: const TextStyle(color: Colors.cyanAccent),
                      ),
                    ),
                  ),
                if (isChange && otpRequested)
                  TextField(
                    controller: otpCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '6-digit OTP',
                      counterText: '',
                    ),
                  ),
                TextField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 8,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: context.l10n.newPINHint,
                    counterText: '',
                  ),
                ),
                TextField(
                  controller: confirmCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 8,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Confirm New PIN',
                    counterText: '',
                  ),
                ),
                if (localMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      localMessage,
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            if (isChange)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showForgotPinDialog();
                },
                child: Text(
                  context.l10n.forgotPINButton,
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                context.l10n.cancelButton,
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: localSubmitting
                  ? null
                  : () async {
                      final pin = pinCtrl.text.trim();
                      final confirm = confirmCtrl.text.trim();
                      if (pin.length < 4 || pin.length > 8) {
                        setLocalState(
                          () => localMessage = 'PIN must be 4 to 8 digits',
                        );
                        return;
                      }
                      if (pin != confirm) {
                        setLocalState(
                          () =>
                              localMessage = 'PIN confirmation does not match',
                        );
                        return;
                      }

                      if (isChange) {
                        final email = emailCtrl.text.trim().toLowerCase();
                        final otp = otpCtrl.text.trim();
                        final currentPin = currentCtrl.text.trim();
                        if (email.isEmpty) {
                          setLocalState(
                            () => localMessage = 'Registered email is required',
                          );
                          return;
                        }
                        if (!otpRequested) {
                          setLocalState(
                            () => localMessage = 'Please request OTP first',
                          );
                          return;
                        }
                        if (otp.length != 6) {
                          setLocalState(
                            () => localMessage = 'Enter a valid 6-digit OTP',
                          );
                          return;
                        }
                        if (currentPin.length < 4 || currentPin.length > 8) {
                          setLocalState(
                            () => localMessage =
                                'Current PIN must be 4 to 8 digits',
                          );
                          return;
                        }
                      }

                      setLocalState(() {
                        localSubmitting = true;
                        localMessage = '';
                      });

                      try {
                        if (isChange) {
                          final email = emailCtrl.text.trim().toLowerCase();
                          final otp = otpCtrl.text.trim();
                          final currentPin = currentCtrl.text.trim();
                          await verifyWalletPinAPI(currentPin);
                          await confirmPinResetAPI(email, otp, pin);
                        } else {
                          await setWalletPinAPI(pin);
                        }

                        if (!mounted) return;
                        setState(() {
                          walletPinEnabled = true;
                        });
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isChange
                                  ? 'PIN changed successfully'
                                  : 'PIN set successfully',
                            ),
                          ),
                        );
                      } catch (e) {
                        setLocalState(() {
                          localMessage = e.toString().replaceFirst(
                            'Exception: ',
                            '',
                          );
                        });
                      } finally {
                        setLocalState(() {
                          localSubmitting = false;
                        });
                      }
                    },
              child: Text(
                localSubmitting ? 'Saving...' : 'Save',
                style: const TextStyle(color: Colors.cyanAccent),
              ),
            ),
          ],
        ),
      ),
    );

    emailCtrl.dispose();
    otpCtrl.dispose();
    currentCtrl.dispose();
    pinCtrl.dispose();
    confirmCtrl.dispose();
  }

  Future<void> _showForgotPinDialog() async {
    final emailCtrl = TextEditingController(text: (currentEmail ?? '').trim());
    final codeCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool codeSent = false;
    bool localSubmitting = false;
    String localMessage = '';

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
            backgroundColor: const Color(0xFF0A1224),
            title: Text(
              context.l10n.forgotWalletPINTitle,
              style: TextStyle(color: Colors.cyanAccent),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.forgotPINInstructions,
                    style: TextStyle(color: Colors.white70, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: context.l10n.registeredEmail,
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.35),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: localSubmitting
                          ? null
                          : () async {
                              final email = emailCtrl.text.trim().toLowerCase();
                              if (email.isEmpty) {
                                setLocalState(() {
                                  localMessage =
                                      'Please enter your registered email first';
                                });
                                return;
                              }

                              setLocalState(() {
                                localSubmitting = true;
                                localMessage = '';
                              });

                              try {
                                final res = await requestPinResetAPI(email);
                                setLocalState(() {
                                  codeSent = true;
                                  localMessage =
                                      res['message']?.toString() ??
                                      'PIN reset code sent';
                                });
                              } catch (e) {
                                setLocalState(() {
                                  localMessage = e.toString().replaceFirst(
                                    'Exception: ',
                                    '',
                                  );
                                });
                              } finally {
                                setLocalState(() {
                                  localSubmitting = false;
                                });
                              }
                            },
                      child: Text(
                        codeSent ? 'Resend Code' : 'Send Code',
                        style: const TextStyle(color: Colors.cyanAccent),
                      ),
                    ),
                  ),
                  TextField(
                    controller: codeCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: context.l10n.sixDigitVerificationCode,
                      hintStyle: const TextStyle(color: Colors.white54),
                      counterText: '',
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.35),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: pinCtrl,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 8,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: context.l10n.newPINHint,
                      hintStyle: const TextStyle(color: Colors.white54),
                      counterText: '',
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.35),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmCtrl,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 8,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Confirm new PIN',
                      hintStyle: const TextStyle(color: Colors.white54),
                      counterText: '',
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.35),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (localMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        localMessage,
                        style: TextStyle(
                          color:
                              localMessage.toLowerCase().contains('sent') ||
                                  localMessage.toLowerCase().contains(
                                    'successful',
                                  )
                              ? Colors.greenAccent
                              : Colors.orangeAccent,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  context.l10n.cancelButton,
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              TextButton(
                onPressed: localSubmitting
                    ? null
                    : () async {
                        final email = emailCtrl.text.trim().toLowerCase();
                        final code = codeCtrl.text.trim();
                        final pin = pinCtrl.text.trim();
                        final confirm = confirmCtrl.text.trim();

                        if (email.isEmpty ||
                            code.isEmpty ||
                            pin.isEmpty ||
                            confirm.isEmpty) {
                          setLocalState(() {
                            localMessage = 'Please fill all fields';
                          });
                          return;
                        }
                        if (code.length != 6) {
                          setLocalState(() {
                            localMessage =
                                'Enter a valid 6-digit verification code';
                          });
                          return;
                        }
                        if (pin.length < 4 || pin.length > 8) {
                          setLocalState(() {
                            localMessage = 'PIN must be 4 to 8 digits';
                          });
                          return;
                        }
                        if (pin != confirm) {
                          setLocalState(() {
                            localMessage = 'PIN confirmation does not match';
                          });
                          return;
                        }

                        setLocalState(() {
                          localSubmitting = true;
                          localMessage = '';
                        });

                        try {
                          final res = await confirmPinResetAPI(
                            email,
                            code,
                            pin,
                          );
                          if (!mounted) return;

                          setState(() {
                            walletPinEnabled = true;
                          });

                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                res['message']?.toString() ??
                                    'PIN reset successful',
                              ),
                            ),
                          );
                        } catch (e) {
                          setLocalState(() {
                            localMessage = e.toString().replaceFirst(
                              'Exception: ',
                              '',
                            );
                          });
                        } finally {
                          setLocalState(() {
                            localSubmitting = false;
                          });
                        }
                      },
                child: Text(
                  localSubmitting ? 'Please wait...' : 'Reset PIN',
                  style: const TextStyle(color: Colors.cyanAccent),
                ),
              ),
            ],
          ),
        );
      },
    );

    emailCtrl.dispose();
    codeCtrl.dispose();
    pinCtrl.dispose();
    confirmCtrl.dispose();
  }

  Future<void> _requestAccountDelete() async {
    final pinCtrl = TextEditingController();
    String localMessage = '';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          backgroundColor: const Color(0xFF0A1224),
          title: Text(
            context.l10n.deleteAccountTitle,
            style: TextStyle(color: Colors.redAccent),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.deleteAccountMessage,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: pinCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 8,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: context.l10n.enterPINToConfirm,
                  counterText: '',
                ),
              ),
              if (localMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    localMessage,
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                context.l10n.cancelButton,
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () async {
                try {
                  final data = await requestAccountDeleteAPI(
                    pin: pinCtrl.text.trim(),
                  );
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        data['message']?.toString() ?? 'Deletion requested',
                      ),
                    ),
                  );
                  await logout();
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthPage()),
                    (route) => false,
                  );
                } catch (e) {
                  setLocalState(() {
                    localMessage = e.toString().replaceFirst('Exception: ', '');
                  });
                }
              },
              child: Text(
                context.l10n.deleteButton,
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        ),
      ),
    );

    pinCtrl.dispose();
  }

  final List<String> _fallbackCountries = const [
    'USA',
    'Canada',
    'Brazil',
    'UK',
    'Germany',
    'France',
    'Spain',
    'Italy',
    'Nigeria',
    'South Africa',
    'Egypt',
    'Kenya',
    'India',
    'Pakistan',
    'Bangladesh',
    'China',
    'Japan',
    'South Korea',
    'Indonesia',
    'Philippines',
    'Australia',
    'New Zealand',
    'UAE',
    'Saudi Arabia',
    'Turkey',
    'Mexico',
    'Argentina',
    'Colombia',
    'Vietnam',
    'Thailand',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAppDeepLinks();
    Future.microtask(_consumePendingPublicNftWalletDeepLink);
    _antWorkPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _antWorkPulseScale = Tween<double>(begin: 1.0, end: 1.045).animate(
      CurvedAnimation(parent: _antWorkPulseController, curve: Curves.easeInOut),
    );
    _antWorkPulseGlow = Tween<double>(begin: 0.18, end: 0.42).animate(
      CurvedAnimation(parent: _antWorkPulseController, curve: Curves.easeInOut),
    );
    _loadDisplayTheme();
    Future.microtask(_restoreMiningReminder);
    _mainVideoController = VideoPlayerController.asset('assets/video.mp4');
    _mainVideoInitTimer = Timer(
      const Duration(milliseconds: 600),
      () => unawaited(_initializeMiningBackgroundVideo()),
    );

    if (AdsService.adsEnabled) {
      AdsService.scheduleForegroundWarmup();
    }
    _hydrateWalletState();
    _refreshProfile();
    _startStatsRefreshTimer();
    _startAnnouncementAutoSlide();
    loadAll();
    Future.microtask(_showFirstTimeTutorialIfNeeded);
  }

  Future<void> _initializeMiningBackgroundVideo() async {
    try {
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) {
        return;
      }
      await _mainVideoController.initialize();
      await _mainVideoController.setLooping(true);
      await _mainVideoController.setVolume(0);
      await _mainVideoController.play();
      if (mounted) {
        setState(() {});
      }
    } catch (_) {}
  }

  void _initAppDeepLinks() {
    unawaited(() async {
      try {
        final initialUri = await _appLinks.getInitialLink();
        if (initialUri != null) {
          await _handleIncomingAppUri(initialUri);
        }
      } catch (_) {}

      _deepLinkSub = _appLinks.uriLinkStream.listen((uri) {
        unawaited(_handleIncomingAppUri(uri));
      });
    }());
  }

  Future<void> _consumePendingPublicNftWalletDeepLink() async {
    final prefs = await SharedPreferences.getInstance();
    final wallet = prefs.getString(_pendingPublicNftWalletStorageKey)?.trim();
    if (wallet == null || wallet.isEmpty || !mounted) {
      return;
    }
    await prefs.remove(_pendingPublicNftWalletStorageKey);
    await _openPublicNftProfile(walletAddress: wallet);
  }

  Future<void> _handleIncomingAppUri(Uri uri) async {
    final wallet = _extractPublicNftWalletFromUri(uri);
    if (wallet == null || wallet.isEmpty || !mounted) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingPublicNftWalletStorageKey);
    await _openPublicNftProfile(walletAddress: wallet);
  }

  void _startAnnouncementAutoSlide() {
    _announcementTimer?.cancel();
    _announcementTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!mounted || !_announcementPageController.hasClients) return;
      final next = (_announcementPage + 1) % 2;
      _announcementPageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.inactive ||
            state == AppLifecycleState.hidden ||
            state == AppLifecycleState.paused) &&
        isMining &&
        _miningEndsAt != null) {
      _syncMiningReminder(endsAt: _miningEndsAt);
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _walletUnlockedForSession = false;
      if (_mainVideoController.value.isInitialized) {
        unawaited(_mainVideoController.pause());
      }
    }

    if (state == AppLifecycleState.resumed) {
      if (_mainVideoController.value.isInitialized) {
        unawaited(_mainVideoController.play());
      }
      _restoreMiningReminder();
      _refreshProfile();
      loadAll();
    }
  }

  void _startStatsRefreshTimer() {
    _statsRefreshTimer?.cancel();
    _statsRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshLiveStats();
    });
  }

  String _pageTitleForIndex(int page) {
    final l = context.l10n;
    switch (page) {
      case 0:
        return l.pageTitleEcosystem;
      case 1:
        return l.pageTitleAntWork;
      case 2:
        return l.pageTitleWallet;
      case 3:
        return l.pageTitleWeb4;
      case 4:
        return l.pageTitleWhitepaper;
      case 5:
        return l.pageTitleColony;
      default:
        return l.pageTitleMore;
    }
  }

  String _pageSubtitleForIndex(int page) {
    switch (page) {
      case 0:
        return _wt('page_subtitle_ecosystem');
      case 1:
        return _wt('page_subtitle_antwork');
      case 2:
        return _wt('page_subtitle_wallet');
      case 3:
        return _wt('page_subtitle_web4');
      case 4:
        return _wt('page_subtitle_whitepaper');
      case 5:
        return _wt('page_subtitle_colony');
      default:
        return _wt('page_subtitle_more');
    }
  }

  String _pageInfoBodyForIndex(int page) {
    switch (page) {
      case 0:
        return _wt('page_info_ecosystem');
      case 1:
        return _wt('page_info_antwork');
      case 2:
        return _wt('page_info_wallet');
      case 3:
        return _wt('page_info_web4');
      case 4:
        return _wt('page_info_whitepaper');
      case 5:
        return _wt('page_info_colony');
      default:
        return _wt('page_info_more');
    }
  }

  Future<void> _showInfoSheet({
    required String title,
    required String body,
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF070C1B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _themeAccent.withValues(alpha: 0.14),
                      border: Border.all(
                        color: _themeAccent.withValues(alpha: 0.20),
                      ),
                    ),
                    child: Icon(
                      Icons.info_outline_rounded,
                      color: _themeAccent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                body,
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: Text(
                    context.l10n.closeButton,
                    style: TextStyle(color: Colors.cyanAccent),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoIconButton({
    required String title,
    required String body,
    Color? color,
  }) {
    final tone = color ?? _themeAccent;
    return IconButton(
      onPressed: () => _showInfoSheet(title: title, body: body),
      tooltip: context.l10n.moreInfo,
      splashRadius: 18,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      icon: Icon(Icons.info_outline_rounded, size: 18, color: tone),
    );
  }

  void _showCurrentPageInfo() {
    _showInfoSheet(
      title: _pageTitleForIndex(_pageIndex),
      body: _pageInfoBodyForIndex(_pageIndex),
    );
  }

  List<String> _parseCountryNames(Map<String, dynamic> data) {
    final list = (data['countries'] as List?) ?? const [];
    final names = <String>[];
    for (final entry in list) {
      if (entry is Map<String, dynamic>) {
        final key = (entry['country'] ?? '').toString().trim();
        if (key.isNotEmpty) {
          names.add(key);
        }
      }
    }
    return names;
  }

  Map<String, int> _parseCountryUsersMap(Map<String, dynamic> data) {
    final list = (data['countries'] as List?) ?? const [];
    final map = <String, int>{};
    for (final entry in list) {
      if (entry is Map<String, dynamic>) {
        final key = (entry['country'] ?? '').toString().trim();
        final value = int.tryParse((entry['users'] ?? '0').toString()) ?? 0;
        if (key.isNotEmpty) {
          map[key] = value;
        }
      }
    }
    return map;
  }

  Future<void> _refreshCountryStats() async {
    final data = await getCountryUsersStats();
    _countryUsersMap = _parseCountryUsersMap(data);
    _countryNames = _parseCountryNames(data);
  }

  Future<void> _refreshLiveStats() async {
    try {
      final latestNetwork = await getNetworkStats();
      await _refreshCountryStats();
      if (!mounted) return;
      setState(() {
        network = latestNetwork;
      });
    } catch (_) {}
  }

  Future<void> _refreshProfile() async {
    try {
      final profile = await getMyProfile();
      final email = profile['user']?['email']?.toString();
      if (!mounted || email == null || email.isEmpty) return;
      setState(() {
        _myProfile = profile['user'] as Map<String, dynamic>?;
        currentEmail = email;
      });
    } catch (_) {}
  }

  Future<void> _showFirstTimeTutorialIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('tutorial_v1_0_3_shown') ?? false;
    if (shown || !mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1224),
        title: Text(
          context.l10n.welcomeTitle,
          style: TextStyle(color: Colors.cyanAccent),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.tutorialStep1,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.tutorialStep2,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.tutorialStep3,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.tutorialStep4,
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.l10n.gotItButton,
              style: TextStyle(color: Colors.cyanAccent),
            ),
          ),
        ],
      ),
    );

    await prefs.setBool('tutorial_v1_0_3_shown', true);
  }

  Future<void> _showProfileDetailsDialog() async {
    await _refreshProfile();
    await _loadReferralStats();

    final profile = _myProfile ?? const {};
    final userId = (profile['id'] ?? currentUserId ?? '--').toString();
    final email = (profile['email'] ?? currentEmail ?? 'Not available')
        .toString();
    final wallet = hasCreatedWallet ? createdWalletAddress : 'Not created yet';
    final migrationWallet = migrationWalletAddress;
    final rank = (myRank?['rank'] ?? '--').toString();
    final totalMined = (network?['totalMined'] ?? '--').toString();

    // Reverse-resolve on-chain @username from BSC AnetUsernameRegistry.
    String? primaryUsername;
    final mwClean = migrationWallet.trim();
    if (mwClean.isNotEmpty &&
        mwClean.toLowerCase() != 'not set' &&
        RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(mwClean)) {
      try {
        primaryUsername = await usernameRegistry.reverseResolve(mwClean);
      } catch (_) {}
    }

    final stats = _myReferralStats ?? const {};
    final dashboardCompletedSessions =
        int.tryParse((_dashboardData?['completed_sessions'] ?? 0).toString()) ??
        0;
    final successfulSessions =
        int.tryParse(
          (stats['mySuccessfulSessions'] ?? profile['successful_sessions'] ?? 0)
              .toString(),
        ) ??
        0;
    final displayedSessions = dashboardCompletedSessions > 0
        ? dashboardCompletedSessions
        : successfulSessions;
    final levelTarget =
        int.tryParse((stats['levelTargetSessions'] ?? 1000).toString()) ?? 1000;
    final remaining = (levelTarget - displayedSessions) > 0
        ? (levelTarget - displayedSessions)
        : 0;
    final eligible = displayedSessions >= levelTarget;

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1224),
        title: Text(
          context.l10n.accountProfileTitle,
          style: TextStyle(color: Colors.cyanAccent),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                'User ID: $userId',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              SelectableText(
                'Email: $email',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              SelectableText(
                'Wallet Address: $wallet',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              SelectableText(
                'Web4 Migration Wallet: $migrationWallet',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              if (primaryUsername != null && primaryUsername.isNotEmpty)
                Row(
                  children: [
                    const Text(
                      'Username: ',
                      style: TextStyle(color: Colors.white70),
                    ),
                    Text(
                      '@$primaryUsername',
                      style: const TextStyle(
                        color: Color(0xFF25C474),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified_rounded,
                      color: Color(0xFF25C474),
                      size: 14,
                    ),
                  ],
                )
              else
                const Text(
                  'Username: Not claimed (claim in EVM Wallet)',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              const SizedBox(height: 8),
              Text(
                'Rank: $rank',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                'Global User Mined: $totalMined ANET',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                'Successful Sessions: $displayedSessions / $levelTarget',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                eligible
                    ? context.l10n.levelEligible
                    : context.l10n.levelNotEligible(remaining.toString()),
                style: TextStyle(
                  color: eligible ? Colors.greenAccent : Colors.orangeAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.l10n.closeButton,
              style: TextStyle(color: Colors.cyanAccent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _hydrateWalletState() async {
    await _loadSavedWalletLocal();
    await _loadEvmWalletPrefs();
    await _syncWalletFromServer();
  }

  Future<void> _loadEvmWalletPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedNetwork =
        prefs.getString(_evmNetworkPrefKey) ?? 'ANET L1 Bridge';
    final effectiveNetwork = _supportedEvmNetworks.contains(savedNetwork)
        ? savedNetwork
        : 'ANET L1 Bridge';
    final savedCoins =
        prefs.getStringList(_customCoinsPrefKey) ?? const <String>[];

    final parsedCoins = savedCoins
        .map((entry) {
          final parts = entry.split('|');
          if (parts.length != 4) {
            return <String, String>{};
          }
          return {
            'name': parts[0],
            'symbol': parts[1],
            'contract': parts[2],
            'decimals': parts[3],
          };
        })
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);

    if (!mounted) return;
    setState(() {
      _selectedEvmNetwork = effectiveNetwork;
      _customCoins = parsedCoins;
    });

    if (_customCoins.isNotEmpty &&
        createdWalletAddress.trim().isNotEmpty &&
        createdWalletAddress != 'Not created') {
      await _refreshCustomCoinBalances();
      await _refreshCustomTokenActivity();
    }
  }

  Future<void> _persistEvmWalletPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_evmNetworkPrefKey, _selectedEvmNetwork);
    await prefs.setStringList(
      _customCoinsPrefKey,
      _customCoins
          .map(
            (coin) =>
                '${coin['name']}|${coin['symbol']}|${coin['contract']}|${coin['decimals']}',
          )
          .toList(growable: false),
    );
  }

  Future<String?> _derivePrimaryEvmAddress() async {
    final seed = createdSeedPhrase.trim();
    if (seed.isEmpty ||
        seed == 'Hidden for security' ||
        seed == 'No wallet created yet') {
      return null;
    }

    try {
      final credentials = EthPrivateKey(_deriveEvmPrivateKeyFromMnemonic(seed));
      final address = await credentials.extractAddress();
      return address.hexEip55;
    } catch (_) {
      return null;
    }
  }

  String _formatTokenAmount(BigInt raw, int decimals) {
    if (raw == BigInt.zero) return '0';
    if (decimals <= 0) return raw.toString();

    final divisor = BigInt.from(10).pow(decimals);
    final whole = raw ~/ divisor;
    final fraction = (raw % divisor).toString().padLeft(decimals, '0');
    final trimmed = fraction.replaceFirst(RegExp(r'0+$'), '');
    if (trimmed.isEmpty) return whole.toString();
    return '$whole.$trimmed';
  }

  String _formatCompactCount(int value) {
    final abs = value.abs();
    if (abs >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)}B';
    }
    if (abs >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (abs >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }

  Future<void> _refreshCustomCoinBalances() async {
    if (_customCoins.isEmpty) {
      if (!mounted) return;
      setState(() {
        _customCoinBalances = const {};
        _customCoinBalanceLoading = false;
      });
      return;
    }

    if (_isAnetNativeNetwork(_selectedEvmNetwork)) {
      if (!mounted) return;
      setState(() {
        _customCoinBalances = {
          for (final coin in _customCoins)
            ((coin['contract'] ?? '').toLowerCase()): '--',
        };
        _customCoinBalanceLoading = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _customCoinBalanceLoading = true;
      });
    }

    final evmWallet = await _derivePrimaryEvmAddress();
    final walletForBackend = createdWalletAddress.trim();
    final rpcUrl = _rpcForNetwork(_selectedEvmNetwork);

    final nextBalances = <String, String>{};

    Web3Client? web3;
    if (evmWallet != null && rpcUrl != null) {
      web3 = Web3Client(rpcUrl, http.Client());
    }

    try {
      for (final coin in _customCoins) {
        final contract = (coin['contract'] ?? '').trim();
        if (contract.isEmpty) {
          continue;
        }

        final decimals = int.tryParse((coin['decimals'] ?? '18').trim()) ?? 18;
        try {
          if (web3 != null && evmWallet != null) {
            const balanceOfAbi =
                '[{"constant":true,"inputs":[{"name":"owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"}]';
            final token = DeployedContract(
              ContractAbi.fromJson(balanceOfAbi, 'ERC20'),
              EthereumAddress.fromHex(contract),
            );
            final balanceFn = token.function('balanceOf');
            final results = await web3.call(
              contract: token,
              function: balanceFn,
              params: [EthereumAddress.fromHex(evmWallet)],
            );
            final rawBalance = (results.first as BigInt? ?? BigInt.zero);
            nextBalances[contract.toLowerCase()] = _formatTokenAmount(
              rawBalance,
              decimals,
            );
            continue;
          }

          // Fallback path for legacy sessions where seed is unavailable locally.
          if (walletForBackend.isNotEmpty &&
              walletForBackend != 'Not created') {
            final balanceData = await getEvmTokenBalanceAPI(
              walletAddress: walletForBackend,
              contractAddress: contract,
              network: _selectedEvmNetwork,
              decimals: decimals,
            );
            nextBalances[contract.toLowerCase()] =
                (balanceData['balanceFormatted'] ?? '0').toString();
          } else {
            nextBalances[contract.toLowerCase()] = '--';
          }
        } catch (_) {
          nextBalances[contract.toLowerCase()] = '--';
        }
      }
    } finally {
      web3?.dispose();
    }

    if (!mounted) return;
    setState(() {
      _customCoinBalances = nextBalances;
      _customCoinBalanceLoading = false;
    });
  }

  Future<Map<String, dynamic>?> _rpcCall(
    String rpcUrl,
    String method,
    List<dynamic> params,
  ) async {
    try {
      final res = await http.post(
        Uri.parse(rpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'id': DateTime.now().millisecondsSinceEpoch,
          'method': method,
          'params': params,
        }),
      );
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['error'] != null) return null;
      return body;
    } catch (_) {
      return null;
    }
  }

  String _paddedTopicAddress(String hexAddress) {
    final clean = hexAddress.toLowerCase().replaceFirst('0x', '');
    return '0x${clean.padLeft(64, '0')}';
  }

  Future<void> _refreshCustomTokenActivity() async {
    if (_customCoins.isEmpty) {
      if (!mounted) return;
      setState(() {
        _customTokenActivity = const [];
        _customTokenActivityLoading = false;
      });
      return;
    }

    if (_isAnetNativeNetwork(_selectedEvmNetwork)) {
      if (!mounted) return;
      setState(() {
        _customTokenActivity = const [];
        _customTokenActivityLoading = false;
      });
      return;
    }

    final wallet = await _derivePrimaryEvmAddress();
    final rpcUrl = _rpcForNetwork(_selectedEvmNetwork);
    if (wallet == null || rpcUrl == null) {
      if (!mounted) return;
      setState(() {
        _customTokenActivity = const [];
        _customTokenActivityLoading = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _customTokenActivityLoading = true;
      });
    }

    final latestRes = await _rpcCall(rpcUrl, 'eth_blockNumber', const []);
    final latestHex = latestRes?['result']?.toString() ?? '0x0';
    final latest =
        int.tryParse(latestHex.replaceFirst('0x', ''), radix: 16) ?? 0;
    final fromBlock = max(0, latest - 120000);

    final transferTopic =
        '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef';
    final walletTopic = _paddedTopicAddress(wallet);
    final activity = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final coin in _customCoins) {
      final contract = (coin['contract'] ?? '').trim();
      final symbol = (coin['symbol'] ?? '').trim();
      final decimals = int.tryParse((coin['decimals'] ?? '18').trim()) ?? 18;
      if (contract.isEmpty) continue;

      final sharedFilter = {
        'fromBlock': '0x${fromBlock.toRadixString(16)}',
        'toBlock': 'latest',
        'address': contract,
      };

      final outgoing = await _rpcCall(rpcUrl, 'eth_getLogs', [
        {
          ...sharedFilter,
          'topics': [transferTopic, walletTopic],
        },
      ]);

      final incoming = await _rpcCall(rpcUrl, 'eth_getLogs', [
        {
          ...sharedFilter,
          'topics': [transferTopic, null, walletTopic],
        },
      ]);

      final logs = <Map<String, dynamic>>[];
      logs.addAll(
        (outgoing?['result'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e)),
      );
      logs.addAll(
        (incoming?['result'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e)),
      );

      for (final log in logs) {
        final txHash = (log['transactionHash'] ?? '').toString();
        final logIndex = (log['logIndex'] ?? '').toString();
        final key = '$txHash:$logIndex';
        if (txHash.isEmpty || !seen.add(key)) continue;

        final topics = (log['topics'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(growable: false);
        if (topics.length < 3) continue;
        final from = '0x${topics[1].replaceFirst('0x', '').substring(24)}';
        final to = '0x${topics[2].replaceFirst('0x', '').substring(24)}';
        final outgoingTx = from.toLowerCase() == wallet.toLowerCase();
        final dataHex = (log['data'] ?? '0x0').toString().replaceFirst(
          '0x',
          '',
        );
        final rawValue =
            BigInt.tryParse(dataHex.isEmpty ? '0' : dataHex, radix: 16) ??
            BigInt.zero;
        final amount = _formatTokenAmount(rawValue, decimals);
        final blockHex = (log['blockNumber'] ?? '0x0').toString().replaceFirst(
          '0x',
          '',
        );
        final blockNum =
            int.tryParse(blockHex.isEmpty ? '0' : blockHex, radix: 16) ?? 0;

        activity.add({
          'txHash': txHash,
          'type': outgoingTx ? 'Sent' : 'Received',
          'counterparty': outgoingTx ? to : from,
          'symbol': symbol,
          'amount': amount,
          'blockNumber': blockNum,
          'network': _selectedEvmNetwork,
        });
      }
    }

    final byHash = <String, List<Map<String, dynamic>>>{};
    for (final tx in activity) {
      final hash = (tx['txHash'] ?? '').toString();
      byHash.putIfAbsent(hash, () => <Map<String, dynamic>>[]).add(tx);
    }
    byHash.forEach((_, list) {
      final hasSent = list.any((e) => e['type'] == 'Sent');
      final hasReceived = list.any((e) => e['type'] == 'Received');
      if (hasSent && hasReceived) {
        for (final e in list) {
          e['type'] = 'Swapped';
        }
      }
    });

    activity.sort(
      (a, b) => (b['blockNumber'] as int).compareTo(a['blockNumber'] as int),
    );

    if (!mounted) return;
    setState(() {
      _customTokenActivity = activity.take(30).toList(growable: false);
      _customTokenActivityLoading = false;
    });
  }

  Future<void> _loadSavedWalletLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final created = prefs.getBool('hasCreatedWallet') ?? false;
    if (!created) return;
    // One-time migration: move seed from plaintext SharedPreferences to secure storage.
    await migrateWalletSeedToSecureStorage(prefs);
    final savedSeed = (await loadWalletSeedSecure() ?? '').trim();

    if (!mounted) return;
    setState(() {
      hasCreatedWallet = true;
      createdWalletAddress =
          prefs.getString('createdWalletAddress') ?? 'Not created';
      createdSeedPhrase = _hasUsableLocalSeedPhrase(savedSeed)
          ? savedSeed
          : 'Hidden for security';
      migrationWalletAddress =
          prefs.getString('migrationWalletAddress') ?? 'Not set';
      walletPinEnabled = prefs.getBool('walletPinEnabled') ?? false;
      walletScheme = prefs.getString('walletScheme') ?? 'legacy_hash_v1';
      walletL1SendEnabled = prefs.getBool('walletL1SendEnabled') ?? false;
      sessionGateBypassEnabled =
          prefs.getBool('sessionGateBypassEnabled') ?? false;
      walletAddress = createdWalletAddress;
      walletProvider = savedSeed.startsWith('evmkey:')
          ? 'EVM Import'
          : 'ANET Web2 Wallet';
    });
  }

  Future<void> _syncWalletFromServer() async {
    // EVM-imported wallets have no server account — skip server sync.
    if (createdSeedPhrase.startsWith('evmkey:')) return;
    try {
      final walletData = await getMyWalletAPI();
      final prefs = await SharedPreferences.getInstance();
      final savedSeed = (await loadWalletSeedSecure() ?? '').trim();
      final hasWalletServer = walletData['hasWallet'] == true;
      final wallet = walletData['wallet'] as Map<String, dynamic>?;
      final security = walletData['security'] as Map<String, dynamic>?;
      final eligibility = walletData['eligibility'] as Map<String, dynamic>?;
      final address =
          wallet?['customAddress']?.toString() ??
          wallet?['displayAddress']?.toString() ??
          wallet?['address']?.toString() ??
          'Not created';
      final migration = wallet?['migrationAddress']?.toString().trim();
      final scheme = wallet?['walletScheme']?.toString() ?? 'legacy_hash_v1';
      final l1Enabled = wallet?['l1SendEnabled'] == true;
      final gateBypass = eligibility?['bypassEnabled'] == true;
      final appBalance =
          double.tryParse((wallet?['appBalance'] ?? 0).toString()) ?? balance;
      final appBalanceAnts =
          int.tryParse((wallet?['appBalanceAnts'] ?? 0).toString()) ?? 0;

      if (!mounted) return;
      setState(() {
        hasCreatedWallet = hasWalletServer;
        createdWalletAddress = hasWalletServer ? address : 'Not created';
        createdSeedPhrase = hasWalletServer
            ? (_hasUsableLocalSeedPhrase(savedSeed)
                  ? savedSeed
                  : 'Hidden for security')
            : 'No wallet created yet';
        migrationWalletAddress = (migration != null && migration.isNotEmpty)
            ? migration
            : 'Not set';
        walletPinEnabled = security?['pinEnabled'] == true;
        walletSeedOtpRequired = security?['seedOtpRequired'] != false;
        walletScheme = scheme;
        walletL1SendEnabled = l1Enabled;
        sessionGateBypassEnabled = gateBypass;
        walletAddress = hasWalletServer ? address : 'Not created yet';
        walletProvider = 'ANET Web2 Wallet';
        walletAnetBalance = hasWalletServer
            ? '${appBalance.toStringAsFixed(4)} ANET'
            : '-- ANET';
        walletOnchainBalance = hasWalletServer
            ? '${appBalance.toStringAsFixed(4)} ANET'
            : '-- ANET';
        walletTrackedAnts = hasWalletServer ? appBalanceAnts : 0;
        if (!hasWalletServer || security?['pinEnabled'] != true) {
          _walletUnlockedForSession = false;
        }
      });

      if (hasWalletServer) {
        await _saveWallet(
          address,
          migration: migration,
          pinEnabled: walletPinEnabled,
          walletSchemeValue: scheme,
          l1SendEnabledValue: l1Enabled,
          sessionGateBypassValue: gateBypass,
          seed: _hasUsableLocalSeedPhrase(savedSeed) ? savedSeed : null,
        );
        await _refreshCustomCoinBalances();
      }
    } catch (_) {
      // Keep local fallback state when network is temporarily unavailable.
    }
  }

  Future<void> _saveWallet(
    String address, {
    String? migration,
    bool? pinEnabled,
    String? walletSchemeValue,
    bool? l1SendEnabledValue,
    bool? sessionGateBypassValue,
    String? seed,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasCreatedWallet', true);
    await prefs.setString('createdWalletAddress', address);
    await prefs.setString(
      'migrationWalletAddress',
      (migration != null && migration.trim().isNotEmpty)
          ? migration.trim()
          : migrationWalletAddress,
    );
    if (seed != null && _hasUsableLocalSeedPhrase(seed)) {
      await saveWalletSeedSecure(seed.trim());
    }
    if (pinEnabled != null) {
      await prefs.setBool('walletPinEnabled', pinEnabled);
    }
    if (walletSchemeValue != null && walletSchemeValue.trim().isNotEmpty) {
      await prefs.setString('walletScheme', walletSchemeValue.trim());
    }
    if (l1SendEnabledValue != null) {
      await prefs.setBool('walletL1SendEnabled', l1SendEnabledValue);
    }
    if (sessionGateBypassValue != null) {
      await prefs.setBool('sessionGateBypassEnabled', sessionGateBypassValue);
    }
  }

  Future<void> _openInAppBrowser(String input) async {
    final raw = input.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.typeWebsite)));
      return;
    }

    final browserUrl = _normalizeToBrowsableUrl(raw);
    final from = createdWalletAddress.trim();

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InAppBrowserPage(
          initialUrl: browserUrl,
          title: 'ANTS Browser',
          walletExtensionMode: true,
          walletAddress: (from.isNotEmpty && from != 'Not created') ? from : '',
          walletNetwork: _selectedEvmNetwork,
          walletSeedPhrase: createdSeedPhrase,
          walletPinRequired: walletPinEnabled,
          allowedHosts: _walletDappAllowlistHosts,
          strictHostBlocking: false,
          onOpenDex: () => _openDexWithPinGate(context),
          onOpenBridge: () => _openBridgeBurnWithPinGate(context),
        ),
      ),
    );
  }

  /// Prompts the user to create a wallet PIN (entered twice to confirm) and
  /// registers it with the server via [setWalletPinAPI]. Returns the new PIN
  /// on success, or `null` if the user cancelled or it failed. Setting the PIN
  /// makes the server PIN-encrypt the wallet seed so the DEX can retrieve it.
  Future<String?> _promptCreateWalletPin(BuildContext ctx) async {
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String localMessage = '';
    bool submitting = false;
    String? result;

    await showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (_, setS) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0F1C2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Column(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  color: Color(0xFF1677FF),
                  size: 32,
                ),
                SizedBox(height: 8),
                Text(
                  'Create a Wallet PIN',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4),
                Text(
                  'Set a 4 to 8 digit PIN to securely unlock the DEX. '
                  'You only need to do this once.',
                  style: TextStyle(color: Color(0xFF7B829A), fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: pinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  style: const TextStyle(color: Colors.white, letterSpacing: 4),
                  decoration: const InputDecoration(
                    counterText: '',
                    labelText: 'New PIN',
                    labelStyle: TextStyle(color: Color(0xFF7B829A)),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF1677FF)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  style: const TextStyle(color: Colors.white, letterSpacing: 4),
                  decoration: const InputDecoration(
                    counterText: '',
                    labelText: 'Confirm PIN',
                    labelStyle: TextStyle(color: Color(0xFF7B829A)),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF1677FF)),
                    ),
                  ),
                ),
                if (localMessage.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    localMessage,
                    style: const TextStyle(
                      color: Color(0xFFFF6B6B),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(dialogCtx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color(0xFF7B829A)),
                ),
              ),
              TextButton(
                onPressed: submitting
                    ? null
                    : () async {
                        final pin = pinCtrl.text.trim();
                        final confirm = confirmCtrl.text.trim();
                        if (pin.length < 4 || pin.length > 8) {
                          setS(
                            () => localMessage = 'PIN must be 4 to 8 digits',
                          );
                          return;
                        }
                        if (!RegExp(r'^\d+$').hasMatch(pin)) {
                          setS(() => localMessage = 'PIN must be digits only');
                          return;
                        }
                        if (pin != confirm) {
                          setS(() => localMessage = 'PINs do not match');
                          return;
                        }
                        setS(() {
                          submitting = true;
                          localMessage = '';
                        });
                        try {
                          await setWalletPinAPI(pin);
                          if (mounted) {
                            setState(() => walletPinEnabled = true);
                          }
                          result = pin;
                          if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        } catch (e) {
                          setS(() {
                            submitting = false;
                            localMessage = e.toString().replaceFirst(
                              'Exception: ',
                              '',
                            );
                          });
                        }
                      },
                child: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF1677FF),
                        ),
                      )
                    : const Text(
                        'Set PIN',
                        style: TextStyle(
                          color: Color(0xFF1677FF),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );

    return result;
  }

  /// Retrieves the wallet seed from the server using [pin], caches it on-device
  /// for future PIN-free opens, and launches the DEX. Shows a snackbar on
  /// failure. Returns true on success.
  Future<bool> _retrieveServerSeedAndLaunchDex(
    BuildContext ctx,
    String pin,
  ) async {
    String? resolvedSeed;
    try {
      final reveal = await revealSeedForDexAPI(pin);
      final s = (reveal['seedPhrase']?.toString() ?? '').trim();
      if (s.isNotEmpty) resolvedSeed = s;
    } on SeedUnavailableException catch (e) {
      await _promptSeedRecovery(ctx, e.message);
      return false;
    } catch (e) {
      final errText = e.toString().replaceFirst('Exception: ', '');
      if (ctx.mounted) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(SnackBar(content: Text(errText)));
      }
      return false;
    }

    if (resolvedSeed == null || resolvedSeed.isEmpty) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Could not retrieve wallet seed from server'),
          ),
        );
      }
      return false;
    }

    if (_hasUsableLocalSeedPhrase(resolvedSeed)) {
      try {
        await saveWalletSeedSecure(resolvedSeed);
      } catch (_) {}
    }

    await _launchDex(ctx, resolvedSeed);
    return true;
  }

  /// Opens the DEX. Checks for a locally-stored seed first (no PIN needed).
  /// Only shows the PIN dialog when the seed must be fetched from the server.
  Future<void> _openDexWithPinGate(BuildContext ctx) async {
    // ── Step 1: try on-device seed (skip PIN entirely if found) ──────────────
    String? localSeed;
    try {
      final s = (await loadWalletSeedSecure() ?? '').trim();
      if (s.isNotEmpty &&
          s != 'Hidden for security' &&
          s != 'No wallet created yet') {
        localSeed = s;
      }
    } catch (_) {}

    if (localSeed != null) {
      await _launchDex(ctx, localSeed);
      return;
    }

    // ── Step 2: no local seed and no PIN — let the user create a PIN inline ──
    // so they can unlock the DEX in one step instead of being bounced to a
    // settings screen. Setting a PIN makes the server PIN-encrypt the seed,
    // after which Step 3's reveal succeeds immediately.
    if (!walletPinEnabled) {
      if (!ctx.mounted) return;
      final newPin = await _promptCreateWalletPin(ctx);
      if (newPin == null) return; // user cancelled
      await _retrieveServerSeedAndLaunchDex(ctx, newPin);
      return;
    }

    // ── Step 3: PIN dialog — retrieves seed from server ───────────────────────
    final pinCtrl = TextEditingController();
    final pinFocus = FocusNode();
    bool approved = false;
    String? approvedPin;
    String localMessage = '';
    bool submitting = false;

    await showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (_, setS) {
          final pin = pinCtrl.text;
          return AlertDialog(
            backgroundColor: const Color(0xFF0F1C2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Column(
              children: [
                Icon(
                  Icons.currency_exchange_rounded,
                  color: Color(0xFF1677FF),
                  size: 32,
                ),
                SizedBox(height: 8),
                Text(
                  'Open DEX',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4),
                Text(
                  'Enter your wallet PIN to authorise DEX access.',
                  style: TextStyle(color: Color(0xFF7B829A), fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (i) {
                      final filled = i < pin.length;
                      final active = i == pin.length && pin.length < 6;
                      return Container(
                        width: 42,
                        height: 52,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A1224),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: active
                                ? const Color(0xFF1677FF)
                                : (filled
                                      ? const Color(
                                          0xFF1677FF,
                                        ).withValues(alpha: 0.5)
                                      : Colors.white12),
                            width: active ? 2 : 1.5,
                          ),
                        ),
                        child: Center(
                          child: filled
                              ? Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : const SizedBox(),
                        ),
                      );
                    }),
                  ),
                ),
                SizedBox(
                  height: 1,
                  child: Opacity(
                    opacity: 0.01,
                    child: TextField(
                      controller: pinCtrl,
                      focusNode: pinFocus,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      autofocus: true,
                      onChanged: (_) => setS(() {}),
                      onSubmitted: (_) async {
                        if (submitting) return;
                        final p = pinCtrl.text.trim();
                        if (p.length < 4) {
                          setS(() => localMessage = 'PIN must be 4–8 digits');
                          return;
                        }
                        setS(() {
                          submitting = true;
                          localMessage = '';
                        });
                        try {
                          await verifyWalletPinAPI(p);
                          approved = true;
                          approvedPin = p;
                          if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        } catch (e) {
                          setS(() {
                            submitting = false;
                            localMessage = e.toString().replaceFirst(
                              'Exception: ',
                              '',
                            );
                          });
                        }
                      },
                    ),
                  ),
                ),
                if (localMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      localMessage,
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: submitting
                          ? null
                          : () => Navigator.pop(dialogCtx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF7B829A),
                        side: const BorderSide(color: Colors.white12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1677FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: submitting
                          ? null
                          : () async {
                              final p = pinCtrl.text.trim();
                              if (p.length < 4) {
                                setS(
                                  () => localMessage = 'PIN must be 4–8 digits',
                                );
                                return;
                              }
                              setS(() {
                                submitting = true;
                                localMessage = '';
                              });
                              try {
                                await verifyWalletPinAPI(p);
                                approved = true;
                                approvedPin = p;
                                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                              } catch (e) {
                                setS(() {
                                  submitting = false;
                                  localMessage = e.toString().replaceFirst(
                                    'Exception: ',
                                    '',
                                  );
                                });
                              }
                            },
                      child: submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Open DEX',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    pinFocus.dispose();
    pinCtrl.dispose();

    if (!approved || approvedPin == null) return;

    // Retrieve seed from server using the verified PIN.
    String? resolvedSeed;
    try {
      final reveal = await revealSeedForDexAPI(approvedPin!);
      final s = (reveal['seedPhrase']?.toString() ?? '').trim();
      if (s.isNotEmpty) resolvedSeed = s;
    } on SeedUnavailableException catch (e) {
      await _promptSeedRecovery(ctx, e.message);
      return;
    } catch (e) {
      final errText = e.toString().replaceFirst('Exception: ', '');
      if (ctx.mounted) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(SnackBar(content: Text(errText)));
      }
      return;
    }

    if (resolvedSeed == null || resolvedSeed.isEmpty) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Could not retrieve wallet seed from server'),
          ),
        );
      }
      return;
    }

    // Cache the server-retrieved seed locally so future opens skip the PIN.
    if (_hasUsableLocalSeedPhrase(resolvedSeed)) {
      try {
        await saveWalletSeedSecure(resolvedSeed);
      } catch (_) {}
    }

    await _launchDex(ctx, resolvedSeed);
  }

  /// Derives the EVM address from [resolvedSeed] and pushes [DexSwapPage].
  Future<void> _launchDex(BuildContext ctx, String resolvedSeed) async {
    String? evmAddr;
    final seedTrimmed = resolvedSeed.trim();
    Uint8List? anetSigningKey;

    if (seedTrimmed.isNotEmpty &&
        seedTrimmed != 'Hidden for security' &&
        seedTrimmed != 'No wallet created yet') {
      try {
        final Uint8List keyBytes;
        if (seedTrimmed.startsWith('evmkey:')) {
          final hexStr = seedTrimmed.substring(7).replaceAll(RegExp(r'\s'), '');
          keyBytes = Uint8List.fromList(hexToBytes(hexStr));
        } else {
          keyBytes = _deriveEvmPrivateKeyFromMnemonic(seedTrimmed);
        }
        final creds = EthPrivateKey(keyBytes);
        final addr = await creds.extractAddress();
        evmAddr = addr.hexEip55;
      } catch (_) {}

      // Derive and cache both signing keys for offline auto-sign:
      //   • ANET L1 key (used to sign DEX action-auth blobs on the L1 server)
      //   • EVM key      (used to sign EVM bridge tx broadcast to BSC/Eth/etc.)
      // Scoped by the active ANET wallet so multi-account devices don't collide.
      try {
        anetSigningKey = _resolveAnetPrivateKey(seedTrimmed);
        await saveDexAnetSigningKeySecure(
          createdWalletAddress,
          bytesToHex(anetSigningKey, include0x: false),
        );
      } catch (_) {}
      try {
        final Uint8List evmKeyBytes;
        if (seedTrimmed.startsWith('evmkey:')) {
          final hexStr = seedTrimmed.substring(7).replaceAll(RegExp(r'\s'), '');
          evmKeyBytes = Uint8List.fromList(hexToBytes(hexStr));
        } else {
          evmKeyBytes = _deriveEvmPrivateKeyFromMnemonic(seedTrimmed);
        }
        await saveDexEvmSigningKeySecure(
          createdWalletAddress,
          bytesToHex(evmKeyBytes, include0x: false),
        );
      } catch (_) {}
    }

    if (!ctx.mounted) return;
    await Navigator.push(
      ctx,
      MaterialPageRoute<void>(
        builder: (_) => DexSwapPage(
          walletAddress: createdWalletAddress,
          seedPhrase: resolvedSeed,
          // wallet field MUST be the secp address — the chain recovers
          // the secp address from the signature and rejects auth.wallet
          // mismatches with 'signature recovery does not match action
          // wallet'.  createdWalletAddress can still be the legacy form
          // until the on-chain migrate succeeds, so derive at sign time.
          signActionAuth: (actionType, seedPhrase) => _buildSignedActionAuth(
            seedPhrase: seedPhrase,
            wallet: _deriveSecpAnetWalletFromSeed(seedPhrase),
            actionType: actionType,
          ),
          signWithKeyAuth: (actionType, keyBytes) =>
              _buildSignedActionAuthFromKey(
                privateKeyBytes: keyBytes,
                wallet: _deriveAnetAddressFromPrivateKeyBytes(keyBytes),
                actionType: actionType,
              ),
          preResolvedSeed: resolvedSeed,
          cachedSigningKey: anetSigningKey,
          evmWalletAddress: evmAddr,
        ),
      ),
    );
  }

  /// Opens the L1 → BSC bridge burn page. Uses the locally-cached wallet seed
  /// when available; otherwise shows the same PIN dialog used by the DEX.
  Future<void> _openBridgeBurnWithPinGate(BuildContext ctx) async {
    // ── Step 1: try on-device seed (skip PIN entirely if found) ──────────────
    String? localSeed;
    try {
      final s = (await loadWalletSeedSecure() ?? '').trim();
      if (s.isNotEmpty &&
          s != 'Hidden for security' &&
          s != 'No wallet created yet') {
        localSeed = s;
      }
    } catch (_) {}

    if (localSeed != null) {
      await _launchBridgeBurn(ctx, localSeed);
      return;
    }

    // ── Step 2: no local seed — need PIN to retrieve from server ─────────────
    if (!walletPinEnabled) {
      if (!ctx.mounted) return;
      await showDialog<void>(
        context: ctx,
        builder: (dCtx) => AlertDialog(
          backgroundColor: const Color(0xFF0F1C2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'PIN Required',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Your wallet seed is not stored on this device.\n\n'
            'Go to Wallet Settings → Change PIN to set a wallet PIN. '
            'This allows the server to securely return your seed for bridge signing.',
            style: TextStyle(color: Color(0xFF7B829A)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text(
                'OK',
                style: TextStyle(color: Color(0xFF1677FF)),
              ),
            ),
          ],
        ),
      );
      return;
    }

    // ── Step 3: PIN dialog — retrieves seed from server ───────────────────────
    final pinCtrl = TextEditingController();
    final pinFocus = FocusNode();
    bool approved = false;
    String? approvedPin;
    String localMessage = '';
    bool submitting = false;

    await showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (_, setS) {
          final pin = pinCtrl.text;
          return AlertDialog(
            backgroundColor: const Color(0xFF0F1C2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Column(
              children: [
                Icon(
                  Icons.swap_horiz_rounded,
                  color: Color(0xFF1677FF),
                  size: 32,
                ),
                SizedBox(height: 8),
                Text(
                  'Bridge to BSC',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4),
                Text(
                  'Enter your wallet PIN to authorise bridge burn.',
                  style: TextStyle(color: Color(0xFF7B829A), fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (i) {
                      final filled = i < pin.length;
                      final active = i == pin.length && pin.length < 6;
                      return Container(
                        width: 42,
                        height: 52,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A1224),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: active
                                ? const Color(0xFF1677FF)
                                : (filled
                                      ? const Color(
                                          0xFF1677FF,
                                        ).withValues(alpha: 0.5)
                                      : Colors.white12),
                            width: active ? 2 : 1.5,
                          ),
                        ),
                        child: Center(
                          child: filled
                              ? Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : const SizedBox(),
                        ),
                      );
                    }),
                  ),
                ),
                SizedBox(
                  height: 1,
                  child: Opacity(
                    opacity: 0.01,
                    child: TextField(
                      controller: pinCtrl,
                      focusNode: pinFocus,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      autofocus: true,
                      onChanged: (_) => setS(() {}),
                      onSubmitted: (_) async {
                        if (submitting) return;
                        final p = pinCtrl.text.trim();
                        if (p.length < 4) {
                          setS(() => localMessage = 'PIN must be 4–8 digits');
                          return;
                        }
                        setS(() {
                          submitting = true;
                          localMessage = '';
                        });
                        try {
                          await verifyWalletPinAPI(p);
                          approved = true;
                          approvedPin = p;
                          if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        } catch (e) {
                          setS(() {
                            submitting = false;
                            localMessage = e.toString().replaceFirst(
                              'Exception: ',
                              '',
                            );
                          });
                        }
                      },
                    ),
                  ),
                ),
                if (localMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      localMessage,
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: submitting
                          ? null
                          : () => Navigator.pop(dialogCtx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF7B829A),
                        side: const BorderSide(color: Colors.white12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1677FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: submitting
                          ? null
                          : () async {
                              final p = pinCtrl.text.trim();
                              if (p.length < 4) {
                                setS(
                                  () => localMessage = 'PIN must be 4–8 digits',
                                );
                                return;
                              }
                              setS(() {
                                submitting = true;
                                localMessage = '';
                              });
                              try {
                                await verifyWalletPinAPI(p);
                                approved = true;
                                approvedPin = p;
                                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                              } catch (e) {
                                setS(() {
                                  submitting = false;
                                  localMessage = e.toString().replaceFirst(
                                    'Exception: ',
                                    '',
                                  );
                                });
                              }
                            },
                      child: submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Continue',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    pinFocus.dispose();
    pinCtrl.dispose();

    if (!approved || approvedPin == null) return;

    String? resolvedSeed;
    try {
      final reveal = await revealSeedForDexAPI(approvedPin!);
      final s = (reveal['seedPhrase']?.toString() ?? '').trim();
      if (s.isNotEmpty) resolvedSeed = s;
    } on SeedUnavailableException catch (e) {
      await _promptSeedRecovery(ctx, e.message);
      return;
    } catch (e) {
      final errText = e.toString().replaceFirst('Exception: ', '');
      if (ctx.mounted) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(SnackBar(content: Text(errText)));
      }
      return;
    }

    if (resolvedSeed == null || resolvedSeed.isEmpty) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Could not retrieve wallet seed from server'),
          ),
        );
      }
      return;
    }

    if (_hasUsableLocalSeedPhrase(resolvedSeed)) {
      try {
        await saveWalletSeedSecure(resolvedSeed);
      } catch (_) {}
    }

    await _launchBridgeBurn(ctx, resolvedSeed);
  }

  /// Derives the user's BSC (0x…) address from [resolvedSeed] and pushes
  /// [BridgeBurnPage] with it pre-filled as the default recipient.
  Future<void> _launchBridgeBurn(BuildContext ctx, String resolvedSeed) async {
    String? evmAddr;
    Uint8List? anetSigningKey;
    final seedTrimmed = resolvedSeed.trim();

    if (seedTrimmed.isNotEmpty &&
        seedTrimmed != 'Hidden for security' &&
        seedTrimmed != 'No wallet created yet') {
      try {
        final Uint8List keyBytes;
        if (seedTrimmed.startsWith('evmkey:')) {
          final hexStr = seedTrimmed.substring(7).replaceAll(RegExp(r'\s'), '');
          keyBytes = Uint8List.fromList(hexToBytes(hexStr));
        } else {
          keyBytes = _deriveEvmPrivateKeyFromMnemonic(seedTrimmed);
        }
        final creds = EthPrivateKey(keyBytes);
        final addr = await creds.extractAddress();
        evmAddr = addr.hexEip55;
      } catch (_) {}

      try {
        anetSigningKey = _resolveAnetPrivateKey(seedTrimmed);
      } catch (_) {}
    }

    if (!ctx.mounted) return;
    await Navigator.push(
      ctx,
      MaterialPageRoute<void>(
        builder: (_) => BridgeBurnPage(
          walletAddress: createdWalletAddress,
          seedPhrase: resolvedSeed,
          // wallet field MUST be the secp address (see DEX comment above).
          signActionAuth: (actionType, seedPhrase) => _buildSignedActionAuth(
            seedPhrase: seedPhrase,
            wallet: _deriveSecpAnetWalletFromSeed(seedPhrase),
            actionType: actionType,
          ),
          signWithKeyAuth: (actionType, keyBytes) =>
              _buildSignedActionAuthFromKey(
                privateKeyBytes: keyBytes,
                wallet: _deriveAnetAddressFromPrivateKeyBytes(keyBytes),
                actionType: actionType,
              ),
          cachedSigningKey: anetSigningKey,
          defaultBscRecipient: evmAddr,
        ),
      ),
    );
  }

  Future<void> loadAll() async {
    try {
      network = await getNetworkStats();
      await _refreshCountryStats();
      myRank = await getUserRank();
      _myReferralStats = await getMyReferralStats();
      final dashboard = await getUserDashboardAPI();
      _dashboardData = dashboard['data'] as Map<String, dynamic>?;
      await _loadWalletCoinHistory();
      unawaited(_loadMiningSessionHistory());

      final rankData = await getUserRank();
      if (rankData['rank'] != null) {
        myRank = rankData;
      }

      final antsPerAnet =
          int.tryParse((network?['antsPerAnet'] ?? 100000000).toString()) ??
          100000000;
      final latestBalance =
          double.tryParse(
            (_dashboardData?['anet_balance'] ?? myRank?['balance'] ?? 0)
                .toString(),
          ) ??
          balance;
      final latestBalanceAnts =
          int.tryParse((_dashboardData?['ants_balance'] ?? 0).toString()) ??
          walletTrackedAnts;
      final effectiveTrackedAnts = latestBalanceAnts;
      final effectiveBalance =
          latestBalance > (effectiveTrackedAnts / antsPerAnet)
          ? latestBalance
          : (effectiveTrackedAnts / antsPerAnet);
      final latestGlobalMined =
          double.tryParse((network?['totalMined'] ?? 0).toString()) ?? 0;

      balance = effectiveBalance;
      walletAnetBalance = '${effectiveBalance.toStringAsFixed(4)} ANET';
      walletTrackedAnts = effectiveTrackedAnts;
      globalAnetMined = '${latestGlobalMined.toStringAsFixed(8)} ANET';

      final status = await getMiningStatus();
      if (await _applyAutoCompletedMiningStatus(status)) {
        setState(() {});
        return;
      }
      if (status["isMining"] == true) {
        isMining = true;
        remainingSeconds = status["remainingSeconds"] ?? 0;
        if (remainingSeconds > 0) {
          _miningEndsAt = DateTime.now().add(
            Duration(seconds: remainingSeconds),
          );
          startTimer();
          await _syncMiningReminder(endsAt: _miningEndsAt);
        } else {
          // If 6 hours already passed while app was closed, complete and credit now.
          if (!_miningCompletionNotificationShown && mounted) {
            _miningCompletionNotificationShown = true;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.sixHourAntWorkComplete),
                duration: const Duration(seconds: 2),
              ),
            );
          }
          await completeMining();
          return;
        }
      }

      setState(() {});
    } catch (e) {
      debugPrint("Load error: $e");
    }
  }

  Future<void> _loadWalletCoinHistory() async {
    try {
      if (mounted) {
        setState(() {
          _walletHistoryLoading = true;
        });
      }

      final data = await getWalletCoinHistoryAPI(limit: 12, offset: 0);
      final raw = (data['history'] as List<dynamic>? ?? const []);
      final normalized = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _walletCoinHistory = normalized;
        _walletHistoryLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _walletHistoryLoading = false;
      });
    }
  }

  Future<void> _loadMiningSessionHistory() async {
    try {
      if (mounted) {
        setState(() {
          _miningSessionHistoryLoading = true;
          _miningSessionHistoryLoadingMore = false;
        });
      }

      // Probe total/profile first, then fetch the newest page so active mining is visible.
      final probe = await getMiningSessionsAPI(limit: 1, offset: 0);
      final total = int.tryParse((probe['total'] ?? 0).toString()) ?? 0;
      final profile = (probe['profile'] as Map<String, dynamic>?) ?? const {};
      final data = await getMiningSessionsAPI(
        limit: _miningSessionPageSize,
        offset: 0,
      );
      final raw = (data['sessions'] as List<dynamic>? ?? const []);
      final sessions = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _miningSessionHistory = sessions;
        _miningProfileData = profile;
        _miningSessionTotal = total;
        _miningSessionOldestOffset = sessions.length;
        _miningSessionHistoryLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _miningSessionHistoryLoading = false;
      });
    }
  }

  Future<void> _loadOlderMiningSessions() async {
    if (_miningSessionHistoryLoading || _miningSessionHistoryLoadingMore) {
      return;
    }
    if (_miningSessionOldestOffset >= _miningSessionTotal) return;

    try {
      if (mounted) {
        setState(() {
          _miningSessionHistoryLoadingMore = true;
        });
      }

      final nextOffset = _miningSessionOldestOffset;
      final remaining = _miningSessionTotal - _miningSessionOldestOffset;
      final nextLimit = remaining > _miningSessionPageSize
          ? _miningSessionPageSize
          : remaining;
      if (nextLimit <= 0) {
        if (mounted) {
          setState(() {
            _miningSessionHistoryLoadingMore = false;
          });
        }
        return;
      }
      final data = await getMiningSessionsAPI(
        limit: nextLimit,
        offset: nextOffset,
      );
      final raw = (data['sessions'] as List<dynamic>? ?? const []);
      final older = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        final existingIds = _miningSessionHistory
            .map((s) => s['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();
        final olderUnique = older
            .where((s) {
              final id = s['id']?.toString() ?? '';
              return id.isEmpty || !existingIds.contains(id);
            })
            .toList(growable: false);

        _miningSessionHistory = [..._miningSessionHistory, ...olderUnique];
        _miningSessionOldestOffset = nextOffset + older.length;
        _miningSessionHistoryLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _miningSessionHistoryLoadingMore = false;
      });
    }
  }

  Future<void> _loadNetworkMiningRoster() async {
    if (_networkMiningRosterLoading) return;

    try {
      if (mounted) {
        setState(() {
          _networkMiningRosterLoading = true;
          _networkMiningRosterError = null;
        });
      }

      final data = await getAdminMiningUsersAPI(
        limit: 50,
        offset: 0,
        sessionLimit: 5,
      );
      final rawMiners = (data['miners'] as List<dynamic>? ?? const []);
      final miners = rawMiners
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _networkMiningRoster = miners;
        _networkMiningSummary =
            (data['summary'] as Map<String, dynamic>?) ?? const {};
        _networkMiningRosterLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _networkMiningRosterLoading = false;
        _networkMiningRosterError = e.toString().replaceFirst(
          'Exception: ',
          '',
        );
      });
    }
  }

  Widget mainSlidePage() {
    final screenWidth = MediaQuery.of(context).size.width;
    final compact = screenWidth < 780;
    final statCardWidth = compact
        ? (screenWidth - 46) / 2
        : (screenWidth - 62) / 4;
    final actionCardWidth = compact
        ? (screenWidth - 46) / 2
        : (screenWidth - 46) / 2;
    final totalUsersCount = network == null
        ? null
        : int.tryParse((network!['totalUsers'] ?? '').toString());
    final usersOnlineCount = network == null
        ? null
        : int.tryParse(
            (network!['usersOnline'] ?? network!['totalActiveMiners'] ?? '')
                .toString(),
          );
    final usersCount = _formattedCountFromNetwork(
      network?['totalUsersFormatted'],
      totalUsersCount,
    );
    final usersOnlineText = usersOnlineCount == null
        ? usersCount
        : '$usersOnlineCount';
    final totalRegisteredCount = network == null
        ? null
        : int.tryParse((network!['totalRegisteredAccounts'] ?? '').toString());
    final totalRegisteredText = _formattedCountFromNetwork(
      network?['totalRegisteredAccountsFormatted'],
      totalRegisteredCount,
    );
    final totalRealMinersCount = network == null
        ? null
        : int.tryParse((network!['totalRealMiners'] ?? '').toString());
    final totalRealMinersText = _formattedCountFromNetwork(
      network?['totalRealMinersFormatted'],
      totalRealMinersCount,
    );
    final totalSessionsCount = network == null
        ? null
        : int.tryParse((network!['totalSessions'] ?? '').toString());
    final totalSessionsText = _formattedCountFromNetwork(
      network?['totalSessionsFormatted'],
      totalSessionsCount,
    );
    final rewardPerSessionNum = network == null
        ? 0.0
        : (double.tryParse(
                (network!['rewardPerSession'] ?? network!['currentRate'] ?? 0)
                    .toString(),
              ) ??
              0.0);
    final rewardPerSessionAnts = network == null
        ? 0
        : (int.tryParse((network!['rewardPerSessionAnts'] ?? 0).toString()) ??
              0);
    final rewardPerSessionAntsText = '$rewardPerSessionAnts ANTS / session';
    final miningStatusLabel = isStartingMining
        ? context.l10n.startingAntWork
        : (isMining ? context.l10n.antWorkActive : context.l10n.readyToStart);
    final miningStatusDetail = isMining
        ? context.l10n.sessionEndsIn(formatTime(remainingSeconds))
        : context.l10n.startAnyTime;
    final countriesCount = _countryNames.isNotEmpty
        ? _countryNames.length
        : _fallbackCountries.length;
    final activeTerritories = _countryNames.isNotEmpty
        ? _countryNames
        : _fallbackCountries;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _themeStageGradient,
        ),
      ),
      child: Stack(
        children: [
          _themedParticleBackground(),
          Container(
            color: Colors.black.withValues(alpha: _themeHomeOverlayOpacity),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _staggeredReveal(
                    order: 0,
                    child: _glassPanel(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0D2A50), Color(0xFF0A1E3A)],
                              ),
                              border: Border.all(
                                color: const Color(
                                  0xFF4AB8FF,
                                ).withValues(alpha: 0.5),
                              ),
                            ),
                            child: const Icon(
                              Icons.change_history_rounded,
                              color: Color(0xFF7DD6FF),
                              size: 34,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.anetGlobal,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 24,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  context.l10n.globalSubtitle,
                                  style: const TextStyle(
                                    color: Color(0xFF8EA9C6),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _showAccountSheet,
                            icon: const Icon(
                              Icons.account_circle_rounded,
                              color: Color(0xFF7CD7FF),
                              size: 34,
                            ),
                            tooltip: context.l10n.profileSupport,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ── AUTO-SLIDING ANNOUNCEMENTS (2s) ──
                  _staggeredReveal(
                    order: 1,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 190,
                            child: PageView(
                              controller: _announcementPageController,
                              onPageChanged: (idx) {
                                if (!mounted) return;
                                setState(() {
                                  _announcementPage = idx;
                                });
                              },
                              children: [
                                _announcementCard(
                                  icon: Icons.bolt_rounded,
                                  iconColor: const Color(0xFFF2A30F),
                                  borderColor: const Color(0xFFF2A30F),
                                  title: _wt('ann_halving_title'),
                                  body: _wt('ann_halving_body'),
                                  note: _wt('ann_halving_note'),
                                  actionText: _wt('ann_halving_safe'),
                                ),
                                _announcementCard(
                                  icon: Icons.public_rounded,
                                  iconColor: const Color(0xFF8FD6FF),
                                  borderColor: const Color(0xFF8FD6FF),
                                  title: _wt('ann_x_title'),
                                  body: _wt('ann_x_body'),
                                  note: _wt('ann_x_note'),
                                  actionText: _wt('ann_x_cta'),
                                  onActionTap: () => openLinkInsideApp(
                                    context,
                                    _xAnnouncementUrl,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(2, (idx) {
                              final active = _announcementPage == idx;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                width: active ? 18 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: active
                                      ? const Color(0xFF68D2FF)
                                      : const Color(0x4468D2FF),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _staggeredReveal(
                    order: 2,
                    child: _glassPanel(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F2A49),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF4AB8FF,
                                    ).withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.circle,
                                      size: 10,
                                      color: Color(0xFF2CF29C),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      context.l10n.liveStatus,
                                      style: const TextStyle(
                                        color: Color(0xFFD5E9FF),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.shield_rounded,
                                color: Color(0xFF5BD0FF),
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                context.l10n.networkStatus,
                                style: TextStyle(
                                  color: Color(0xFF8EA9C6),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          compact
                              ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _heroVideoPanel(),
                                    const SizedBox(height: 10),
                                    _homeMiningPromptCard(
                                      isMining: isMining,
                                      isStartingMining: isStartingMining,
                                      remainingSeconds: remainingSeconds,
                                      onTap: () {
                                        if (isMining || isStartingMining) {
                                          _goToPage(1);
                                          return;
                                        }
                                        startMining();
                                      },
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(child: _heroVideoPanel()),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 260,
                                      child: _homeMiningPromptCard(
                                        isMining: isMining,
                                        isStartingMining: isStartingMining,
                                        remainingSeconds: remainingSeconds,
                                        onTap: () {
                                          if (isMining || isStartingMining) {
                                            _goToPage(1);
                                            return;
                                          }
                                          startMining();
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _staggeredReveal(
                    order: 2,
                    child: _glassPanel(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _statMiniCard(
                                  dotColor: const Color(0xFF2CF29C),
                                  borderColor: const Color(0xFF2CF29C),
                                  icon: Icons.groups_2_rounded,
                                  iconSize: 14,
                                  label: context.l10n.totalAntsDialog,
                                  value: totalRegisteredText,
                                  valueColor: Colors.white,
                                  subtitle: _wt('registered'),
                                  subtitleColor: const Color(0xFF2CF29C),
                                  infoTitle: _wt('total_ants'),
                                  infoBody: _wt('total_ants_info_body'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _statMiniCard(
                                  dotColor: const Color(0xFF4AB8FF),
                                  borderColor: const Color(0xFF4AB8FF),
                                  icon: Icons.bolt_rounded,
                                  iconSize: 14,
                                  label: context.l10n.activeWorkersDialog,
                                  value: totalRealMinersText,
                                  valueColor: const Color(0xFF4AB8FF),
                                  subtitle: _wt('completed_work'),
                                  subtitleColor: const Color(0xFF6AABCF),
                                  infoTitle: _wt('active_workers'),
                                  infoBody: _wt('active_workers_info_body'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _staggeredReveal(
                    order: 3,
                    child: _glassPanel(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_wt('active_territories')} (${_formatIntegerWithCommas(activeTerritories.length)}+)',
                            style: TextStyle(
                              color: Color(0xFF88A2BF),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 40,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: activeTerritories.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 6),
                              itemBuilder: (_, index) {
                                final country = activeTerritories[index];
                                return InkWell(
                                  onTap: () => _showCountryUsersDialog(country),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0B1A30),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF4AB8FF,
                                        ).withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      '${_flagForCountry(country)} $country',
                                      style: const TextStyle(
                                        color: Color(0xFFD6ECFF),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _staggeredReveal(
                    order: 4,
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: statCardWidth,
                          child: _miniStatCard(
                            icon: Icons.work_history_rounded,
                            title: _wt('verified_sessions'),
                            value: totalSessionsText,
                            subtitle: _wt('network_throughput'),
                            subtitleColor: const Color(0xFF3FE892),
                            infoText:
                                'The total number of verified work sessions completed across the entire colony. Every 6-hour shift finished by any ant is counted here — a testament to the collective effort of all worker ants.',
                          ),
                        ),
                        SizedBox(
                          width: statCardWidth,
                          child: _miniStatCard(
                            icon: Icons.bolt_rounded,
                            title: _wt('live_output'),
                            value: rewardPerSessionNum.toStringAsFixed(6),
                            subtitle: 'ANET / session',
                            subtitleColor: const Color(0xFFF2B948),
                            infoText:
                                'The current session output for completing a full 6-hour work shift. This rate adjusts as the colony grows through halving milestones.',
                          ),
                        ),
                        SizedBox(
                          width: statCardWidth,
                          child: _miniStatCard(
                            icon: Icons.public_rounded,
                            title: _wt('markets'),
                            value:
                                '${_formatIntegerWithCommas(countriesCount)}+',
                            subtitle: _wt('active_territories'),
                            subtitleColor: const Color(0xFF38E0B9),
                            infoText:
                                'The number of territories across the globe where ant colonies have been established. Our network spans multiple continents with ants working together worldwide.',
                          ),
                        ),
                        SizedBox(
                          width: statCardWidth,
                          child: _miniStatCard(
                            icon: Icons.groups_rounded,
                            title: _wt('active_workers'),
                            value: totalRealMinersText,
                            subtitle: _wt('completed_at_least_one_session'),
                            subtitleColor: const Color(0xFF6ACFFF),
                            infoText:
                                'This shows how many accounts have already completed at least one verified session and represent the current working base of the network.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _staggeredReveal(
                    order: 3,
                    child: _glassPanel(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(
                                    0xFF3DAEFF,
                                  ).withValues(alpha: 0.16),
                                ),
                                child: Icon(
                                  isMining
                                      ? Icons.bolt_rounded
                                      : Icons.pause_circle_outline_rounded,
                                  color: isMining
                                      ? Colors.greenAccent
                                      : const Color(0xFF7AD7FF),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.l10n.liveAntWork,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      miningStatusLabel,
                                      style: TextStyle(
                                        color: isMining
                                            ? Colors.greenAccent
                                            : const Color(0xFFAFCAE4),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => _goToPage(1),
                                icon: const Icon(
                                  Icons.open_in_new_rounded,
                                  size: 16,
                                ),
                                label: Text(_wt('open')),
                              ),
                              _infoIconButton(
                                title: _wt('live_ant_work'),
                                body: _wt('live_ant_work_info_body'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _signalPill(
                                miningStatusDetail,
                                color: const Color(0xFF6ACFFF),
                              ),
                              _signalPill(
                                rewardPerSessionAntsText,
                                color: const Color(0xFFF2B948),
                              ),
                              _signalPill(
                                '${balance.toStringAsFixed(4)} ANET ${_wt('tracked')}',
                                color: const Color(0xFF7FE2BA),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              SizedBox(
                                width: statCardWidth,
                                child: _miniStatCard(
                                  icon: Icons.speed_rounded,
                                  title: _wt('session_output'),
                                  value: rewardPerSessionNum.toStringAsFixed(6),
                                  subtitle: _wt('anet_per_6h_cycle'),
                                  subtitleColor: const Color(0xFFF2B948),
                                ),
                              ),
                              SizedBox(
                                width: statCardWidth,
                                child: _miniStatCard(
                                  icon: Icons.account_balance_wallet_rounded,
                                  title: _wt('portfolio'),
                                  value: '${balance.toStringAsFixed(4)} ANET',
                                  subtitle:
                                      '$walletTrackedAnts ANTS ${_wt('accumulated')}',
                                  subtitleColor: const Color(0xFF6ACFFF),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              buildActionButton(
                                isMining
                                    ? _wt('open_ant_work')
                                    : _wt('start_ant_work'),
                                () {
                                  if (isMining || isStartingMining) {
                                    _goToPage(1);
                                    return;
                                  }
                                  startMining();
                                },
                                compact: true,
                                icon: isMining
                                    ? Icons.visibility_rounded
                                    : Icons.play_arrow_rounded,
                                emphasized: true,
                                pulse: !isMining && !isStartingMining,
                              ),
                              buildActionButton(
                                _wt('refresh_activity'),
                                loadAll,
                                compact: true,
                                icon: Icons.refresh_rounded,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _staggeredReveal(
                    order: 4,
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: actionCardWidth,
                          child: _actionFeatureCard(
                            title: _wt('start_ant_work'),
                            subtitle: isMining
                                ? _wt('ant_work_in_progress')
                                : _wt('begin_your_journey'),
                            icon: Icons.rocket_launch_rounded,
                            colorA: const Color(0xFF0A294E),
                            colorB: const Color(0xFF123A6A),
                            infoText:
                                'Start a verified 6-hour Ant Work session. Activity is tracked in ANTS first, then becomes claimable in ANET after the required completed-session threshold is reached.',
                            onTap: () {
                              if (isMining || isStartingMining) {
                                _goToPage(1);
                                return;
                              }
                              startMining();
                              _goToPage(1);
                            },
                          ),
                        ),
                        SizedBox(
                          width: actionCardWidth,
                          child: _actionFeatureCard(
                            title: _wt('anet_wallet'),
                            subtitle: _wt('wallet_tools_chain_visibility'),
                            icon: Icons.account_balance_wallet_rounded,
                            colorA: const Color(0xFF101F45),
                            colorB: const Color(0xFF18356F),
                            infoText:
                                'Open wallet tools, current balance mapping, and public ecosystem visibility without digging through extra panels.',
                            onTap: () => _goToPage(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassPanel({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(12),
      decoration: _panelDecoration(),
      child: child,
    );
  }

  Widget _staggeredReveal({required int order, required Widget child}) {
    final durationMs = 420 + (order * 110);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: durationMs),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, animatedChild) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 18),
            child: animatedChild,
          ),
        );
      },
    );
  }

  Widget _heroVideoPanel() {
    return Container(
      height: 210,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF3DAEFF).withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3DAEFF).withValues(alpha: 0.15),
            blurRadius: 20,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: _mainVideoController.value.isInitialized
            ? FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _mainVideoController.value.size.width,
                  height: _mainVideoController.value.size.height,
                  child: VideoPlayer(_mainVideoController),
                ),
              )
            : Container(
                color: const Color(0xFF071122),
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFF65CBFF)),
                ),
              ),
      ),
    );
  }

  void _showInfoDialog(String title, String body) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1F38),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: const Color(0xFF4AB8FF).withValues(alpha: 0.3),
          ),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFF4AB8FF),
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          body,
          style: const TextStyle(
            color: Color(0xFFB8D4EE),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.l10n.gotItButton,
              style: TextStyle(
                color: Color(0xFF4AB8FF),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusSummaryPanel(
    String usersCount, {
    String? totalRegisteredCount,
    String? totalWorkingAntsCount,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _wt('network_status'),
          style: TextStyle(color: Color(0xFF88A2BF), fontSize: 16),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              _wt('online'),
              style: TextStyle(
                color: Color(0xFF2CF29C),
                fontWeight: FontWeight.w800,
                fontSize: 34,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.circle, color: Color(0xFF2CF29C), size: 12),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statMiniCard(
                dotColor: const Color(0xFF2CF29C),
                borderColor: const Color(0xFF2CF29C),
                icon: Icons.groups_2_rounded,
                iconSize: 14,
                label: context.l10n.totalAntsDialog,
                value: totalRegisteredCount ?? usersCount,
                valueColor: Colors.white,
                subtitle: _wt('registered'),
                subtitleColor: const Color(0xFF2CF29C),
                infoTitle: _wt('total_ants'),
                infoBody: _wt('total_ants_info_body'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statMiniCard(
                dotColor: const Color(0xFF4AB8FF),
                borderColor: const Color(0xFF4AB8FF),
                icon: Icons.bolt_rounded,
                iconSize: 14,
                label: _wt('total_working_ants'),
                value: totalWorkingAntsCount ?? '--',
                valueColor: const Color(0xFF4AB8FF),
                subtitle: _wt('completed_work'),
                subtitleColor: const Color(0xFF6AABCF),
                infoTitle: _wt('total_working_ants'),
                infoBody: _wt('active_workers_info_body'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1F3A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF4AB8FF).withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            _wt('together_future'),
            style: TextStyle(
              color: Color(0xFFCFE9FF),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _homeMiningPromptCard({
    required bool isMining,
    required bool isStartingMining,
    required int remainingSeconds,
    required VoidCallback onTap,
  }) {
    final isBusy = isMining || isStartingMining;
    final ctaLabel = isBusy ? _wt('open_ant_work') : _wt('start_ant_work');
    final statusLabel = isStartingMining
        ? _wt('starting_session')
        : (isMining ? _wt('session_active_now') : _wt('ready_new_session'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.antWorkSectionLabel,
          style: const TextStyle(color: Color(0xFF88A2BF), fontSize: 16),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              isBusy ? _wt('live') : _wt('ready'),
              style: TextStyle(
                color: isBusy
                    ? const Color(0xFF2CF29C)
                    : const Color(0xFF6ACFFF),
                fontWeight: FontWeight.w800,
                fontSize: 34,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.circle,
              color: isBusy ? const Color(0xFF2CF29C) : const Color(0xFF6ACFFF),
              size: 12,
            ),
            const SizedBox(width: 10),
            if (isMining) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF2CF29C).withValues(alpha: 0.6),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  formatTime(remainingSeconds),
                  style: const TextStyle(
                    color: Color(0xFF2CF29C),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF2CF29C).withValues(alpha: 0.6),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.flash_on_rounded,
                      color: Color(0xFF2CF29C),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'ANT mining',
                      style: TextStyle(
                        color: Color(0xFF2CF29C),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF88A2BF).withValues(alpha: 0.5),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.flash_off_rounded,
                      color: const Color(0xFF88A2BF).withValues(alpha: 0.8),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Not Mining',
                      style: TextStyle(
                        color: const Color(0xFF88A2BF).withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _wt('quick_action'),
          style: TextStyle(color: Color(0xFF88A2BF), fontSize: 15),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0B1F3A),
              foregroundColor: const Color(0xFFD6ECFF),
              elevation: 0,
              side: BorderSide(
                color: const Color(0xFF4AB8FF).withValues(alpha: 0.35),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: Icon(
              isBusy ? Icons.visibility_rounded : Icons.play_arrow_rounded,
              size: 18,
            ),
            label: Text(
              ctaLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1F3A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF4AB8FF).withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            statusLabel,
            style: const TextStyle(
              color: Color(0xFFCFE9FF),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _statMiniCard({
    required Color dotColor,
    required Color borderColor,
    required IconData icon,
    required double iconSize,
    required String label,
    required String value,
    required Color valueColor,
    required String subtitle,
    required Color subtitleColor,
    required String infoTitle,
    required String infoBody,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1A30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: dotColor, size: iconSize),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF88A2BF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () => _showInfoDialog(infoTitle, infoBody),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: const Color(0xFF88A2BF).withValues(alpha: 0.6),
                  size: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: subtitleColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _flagForCountry(String country) {
    const flags = {
      'USA': '🇺🇸',
      'Canada': '🇨🇦',
      'Brazil': '🇧🇷',
      'UK': '🇬🇧',
      'Germany': '🇩🇪',
      'France': '🇫🇷',
      'Spain': '🇪🇸',
      'Italy': '🇮🇹',
      'Nigeria': '🇳🇬',
      'South Africa': '🇿🇦',
      'Egypt': '🇪🇬',
      'Kenya': '🇰🇪',
      'India': '🇮🇳',
      'Pakistan': '🇵🇰',
      'Bangladesh': '🇧🇩',
      'China': '🇨🇳',
      'Japan': '🇯🇵',
      'South Korea': '🇰🇷',
      'Indonesia': '🇮🇩',
      'Philippines': '🇵🇭',
      'Australia': '🇦🇺',
      'New Zealand': '🇳🇿',
      'UAE': '🇦🇪',
      'Saudi Arabia': '🇸🇦',
      'Turkey': '🇹🇷',
      'Mexico': '🇲🇽',
      'Argentina': '🇦🇷',
      'Colombia': '🇨🇴',
      'Vietnam': '🇻🇳',
      'Thailand': '🇹🇭',
    };
    return flags[country] ?? '🌐';
  }

  Future<void> _showCountryUsersDialog(String country) async {
    final totalUsers =
        int.tryParse((network?['totalUsers'] ?? '0').toString()) ?? 0;
    final totalSessions =
        int.tryParse((network?['totalSessions'] ?? '0').toString()) ?? 0;
    final activeMiners =
        int.tryParse((network?['totalActiveMiners'] ?? '0').toString()) ?? 0;

    final exactUsers = await _loadExactCountryUsers(country);
    final users = exactUsers ?? _estimatedUsersForCountry(country, totalUsers);
    final percentage = totalUsers <= 0 ? 0.0 : (users / totalUsers) * 100;

    final countrySessions = totalSessions > 0
        ? ((totalSessions * (users / (totalUsers > 0 ? totalUsers : 1)))
              .round())
        : 0;
    final countryActive = activeMiners > 0
        ? ((activeMiners * (users / (totalUsers > 0 ? totalUsers : 1))).round())
        : 0;

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1224),
        title: Text(
          '${_flagForCountry(country)} $country',
          style: const TextStyle(
            color: Colors.cyanAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.territoryOverview,
                style: TextStyle(
                  color: Color(0xFF6ACFFF),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1F3A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.l10n.totalAntsDialog,
                          style: TextStyle(
                            color: Color(0xFF88A2BF),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _formatIntegerWithCommas(users),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.l10n.networkShare,
                          style: TextStyle(
                            color: Color(0xFF88A2BF),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${percentage.toStringAsFixed(2)}%',
                          style: const TextStyle(
                            color: Color(0xFF6ACFFF),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.l10n.activeWorkersDialog,
                          style: TextStyle(
                            color: Color(0xFF88A2BF),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _formatIntegerWithCommas(countryActive),
                          style: const TextStyle(
                            color: Color(0xFF7FE2BA),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.l10n.sessionsInTerritory,
                          style: TextStyle(
                            color: Color(0xFF88A2BF),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _formatIntegerWithCommas(countrySessions),
                          style: const TextStyle(
                            color: Color(0xFFF2B948),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                exactUsers != null
                    ? 'Source: live backend country stats.'
                    : 'Source: fallback estimate. Country stats endpoint unavailable.',
                style: const TextStyle(
                  color: Color(0xFF96B2CF),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.l10n.closeButton,
              style: TextStyle(color: Colors.cyanAccent),
            ),
          ),
        ],
      ),
    );
  }

  Future<int?> _loadExactCountryUsers(String country) async {
    try {
      if (_countryUsersMap.isEmpty) {
        await _refreshCountryStats();
      }

      return _countryUsersMap[country];
    } catch (_) {
      return null;
    }
  }

  String _formattedCountFromNetwork(dynamic formatted, int? fallback) {
    final formattedText = formatted?.toString().trim() ?? '';
    if (formattedText.isNotEmpty) {
      return formattedText;
    }

    if (fallback == null) {
      return '--';
    }

    return _formatIntegerWithCommas(fallback);
  }

  String _formatIntegerWithCommas(int value) {
    final negative = value < 0;
    final digits = value.abs().toString();
    final buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      final reverseIndex = digits.length - i;
      buffer.write(digits[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write(',');
      }
    }

    return negative ? '-${buffer.toString()}' : buffer.toString();
  }

  int _estimatedUsersForCountry(String country, int totalUsers) {
    if (totalUsers <= 0) return 0;

    final hash = country.codeUnits.fold<int>(
      0,
      (acc, v) => (acc * 31 + v) % 100000,
    );
    final baseline = 0.008 + ((hash % 900) / 100000); // 0.8% to 1.7%
    var estimate = (totalUsers * baseline).round();

    if (estimate < 1) estimate = 1;
    if (estimate > totalUsers) estimate = totalUsers;
    return estimate;
  }

  Widget _miniStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color subtitleColor,
    String? infoText,
  }) {
    return _glassPanel(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _themeAccent, size: 20),
              const Spacer(),
              if (infoText != null)
                GestureDetector(
                  onTap: () => _showInfoDialog(title, infoText),
                  child: Icon(
                    Icons.info_outline_rounded,
                    color: _themeMutedText.withValues(alpha: 0.65),
                    size: 16,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              color: _themeMutedText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: subtitleColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionFeatureCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color colorA,
    required Color colorB,
    required VoidCallback onTap,
    String? infoText,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF4AB8FF).withValues(alpha: 0.20),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colorA, colorB],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: const Color(0xFF7AD7FF), size: 26),
                const Spacer(),
                if (infoText != null)
                  _infoIconButton(
                    title: title,
                    body: infoText,
                    color: const Color(0xFFBEEBFF),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFFAFCAE4),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.14),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _onPageChanged(int page) {
    setState(() {
      _pageIndex = page;
    });
    // Footer banner ad loading removed (AdMob ban). Axon ads TBD.
  }

  void _loadFooterBannerOnce() {
    // Stubbed — Google AdMob removed.
  }

  int _tabFromPageIndex(int page) {
    if (page == 0) return 0;
    if (page == 1) return 1;
    if (page == 2) return 2;
    if (page == 5) return 3;
    return 4;
  }

  int _pageFromTabIndex(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return 0;
      case 1:
        return 1;
      case 2:
        return 2;
      case 3:
        return 5;
      default:
        return 6;
    }
  }

  Future<String?> _promptMigrationAddress({String initialValue = ''}) async {
    final ctrl = TextEditingController(text: initialValue);
    String? result;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1224),
        title: Text(
          context.l10n.web4MigrationWalletTitle,
          style: TextStyle(color: Colors.cyanAccent),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.migrationWalletOptional,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: context.l10n.migrationWalletExample,
                hintStyle: TextStyle(color: Colors.white54),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.l10n.cancelButton,
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              result = ctrl.text.trim();
              Navigator.pop(ctx);
            },
            child: Text(
              context.l10n.saveButton,
              style: TextStyle(color: Colors.cyanAccent),
            ),
          ),
        ],
      ),
    );

    ctrl.dispose();
    return result;
  }

  Future<void> _setMigrationAddress() async {
    // Try to derive the user's EVM address from their seed so the dialog
    // is pre-filled and they only need to confirm rather than type.
    String derivedEvmAddress = '';
    try {
      String? seed = await loadWalletSeedSecure();
      if ((seed == null || seed.trim().isEmpty) &&
          _hasUsableLocalSeedPhrase(createdSeedPhrase)) {
        seed = createdSeedPhrase;
      }
      if (seed != null && seed.trim().isNotEmpty) {
        final privBytes = _deriveEvmPrivateKeyFromMnemonic(seed.trim());
        derivedEvmAddress = EthPrivateKey(privBytes).address.hexEip55;
      }
    } catch (_) {}

    final initial = migrationWalletAddress == 'Not set'
        ? derivedEvmAddress
        : migrationWalletAddress;
    final input = await _promptMigrationAddress(initialValue: initial);
    if (input == null) return;

    if (input.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.migrationWalletNotChanged)),
      );
      return;
    }

    try {
      final data = await updateMigrationWalletAPI(input);
      final wallet = data['wallet'] as Map<String, dynamic>?;
      final migration = wallet?['migrationAddress']?.toString() ?? input;
      final appBalance =
          double.tryParse((wallet?['appBalance'] ?? balance).toString()) ??
          balance;

      if (!mounted) return;
      setState(() {
        migrationWalletAddress = migration;
        walletAnetBalance = '${appBalance.toStringAsFixed(4)} ANET';
        walletOnchainBalance = '${appBalance.toStringAsFixed(4)} ANET';
        autoStatus = 'Migration wallet saved';
      });
      await _saveWallet(
        createdWalletAddress,
        migration: migration,
        pinEnabled: walletPinEnabled,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.migrationWalletSaved)),
      );
    } catch (e) {
      final errText = e.toString().replaceFirst('Exception: ', '');
      if (errText.toLowerCase().contains('already exists')) {
        await _syncWalletFromServer();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errText)));
    }
  }

  Future<void> getBalance() async {
    if (!hasCreatedWallet) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.createWalletFirst)));
      setState(() {
        autoStatus = 'Create wallet first';
      });
      return;
    }

    final walletMined = balance;

    setState(() {
      walletAnetBalance = '${walletMined.toStringAsFixed(4)} ANET';
      walletOnchainBalance = '${walletMined.toStringAsFixed(4)} ANET';
      globalAnetMined = network == null
          ? '-- ANET'
          : '${(double.tryParse(network!['totalMined'].toString()) ?? 0).toStringAsFixed(8)} ANET';
      autoStatus = 'Wallet balance synced from mined ANET';
    });
  }

  Future<void> fetchPrice() async {
    setState(() {
      tokenPrice = 'Future market reference';
      autoStatus =
          'Web3 market value is intentionally separated from Web2 mining accounting';
    });
  }

  void startAuto() {
    setState(() {
      autoStatus = 'Auto mode started';
    });
  }

  void stopAuto() {
    setState(() {
      autoStatus = 'Auto mode stopped';
    });
  }

  Future<void> searchWeb() async {
    await _openInAppBrowser(webSearchController.text);
    if (!mounted) return;
    setState(() {
      autoStatus = 'Opened in-app browser';
    });
  }

  Future<void> createWallet() async {
    if (hasCreatedWallet) {
      await _setMigrationAddress();
      return;
    }

    try {
      final result = await createWalletAPI();
      final wallet = result['wallet'] as Map<String, dynamic>?;
      final address =
          wallet?['customAddress']?.toString() ??
          wallet?['displayAddress']?.toString() ??
          wallet?['address']?.toString() ??
          'Not created';
      final seed =
          result['oneTimeSeedPhrase']?.toString() ?? 'Hidden for security';
      String? migrationAddress = wallet?['migrationAddress']?.toString().trim();
      final security = result['security'] as Map<String, dynamic>?;
      final appBalance =
          double.tryParse((wallet?['appBalance'] ?? balance).toString()) ??
          balance;
      final appBalanceAnts =
          int.tryParse((wallet?['appBalanceAnts'] ?? 0).toString()) ?? 0;

      // Auto-derive EVM address from the fresh seed and set it as the
      // migration wallet if the server didn't return one already.
      if ((migrationAddress == null || migrationAddress.isEmpty) &&
          _hasUsableLocalSeedPhrase(seed)) {
        try {
          final privBytes = _deriveEvmPrivateKeyFromMnemonic(seed);
          final derived = EthPrivateKey(privBytes).address.hexEip55;
          final migData = await updateMigrationWalletAPI(derived);
          final savedMigration =
              (migData['wallet'] as Map<String, dynamic>?)?['migrationAddress']
                  ?.toString()
                  .trim();
          migrationAddress =
              (savedMigration != null && savedMigration.isNotEmpty)
              ? savedMigration
              : derived;
        } catch (_) {
          // Non-fatal: wallet is still created; migration can be set manually.
        }
      }

      if (!mounted) return;
      setState(() {
        hasCreatedWallet = true;
        createdWalletAddress = address;
        createdSeedPhrase = seed;
        walletAddress = address;
        walletProvider = 'ANET Web2 Wallet';
        walletPinEnabled = security?['pinEnabled'] == true;
        walletSeedOtpRequired = security?['seedOtpRequired'] != false;
        migrationWalletAddress =
            (migrationAddress != null && migrationAddress.isNotEmpty)
            ? migrationAddress
            : 'Not set';
        walletAnetBalance = '${appBalance.toStringAsFixed(4)} ANET';
        walletOnchainBalance = '${appBalance.toStringAsFixed(4)} ANET';
        walletTrackedAnts = appBalanceAnts;
        autoStatus = 'Wallet created and linked to your mined ANET';
      });

      await _saveWallet(
        address,
        migration: (migrationAddress != null && migrationAddress.isNotEmpty)
            ? migrationAddress
            : '',
        pinEnabled: walletPinEnabled,
        seed: _hasUsableLocalSeedPhrase(seed) ? seed : null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ANET wallet created successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  /// Guides the user through importing a MetaMask / EVM BIP39 wallet.
  /// Stores the derived private key as 'evmkey:HEX' in secure storage so
  /// all signing functions use the correct key without SHA-256 wrapping.
  Future<void> _importEvmWalletFlow() async {
    if (hasCreatedWallet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A wallet is already set up on this device.'),
        ),
      );
      return;
    }

    final mnemonicCtrl = TextEditingController();
    bool busy = false;
    String? errorMsg;

    // Step 1 – collect and validate mnemonic.
    final mnemonic = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setS) => AlertDialog(
          backgroundColor: const Color(0xFF12162A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: const [
              Icon(
                Icons.account_balance_wallet_rounded,
                color: Color(0xFF1677FF),
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                'Import EVM / MetaMask Wallet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your 12 or 24-word MetaMask recovery phrase.',
                style: TextStyle(color: Color(0xFF8899BB), fontSize: 13),
              ),
              const SizedBox(height: 4),
              const Text(
                '⚠ Your phrase is processed on-device only and never sent to any server.',
                style: TextStyle(color: Color(0xFFFFB800), fontSize: 11),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mnemonicCtrl,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'word1 word2 word3 …',
                  hintStyle: const TextStyle(color: Color(0xFF8899BB)),
                  filled: true,
                  fillColor: const Color(0xFF0A0C1B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              if (errorMsg != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorMsg!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF8899BB)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1677FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: busy
                  ? null
                  : () {
                      final normalized = mnemonicCtrl.text
                          .trim()
                          .toLowerCase()
                          .replaceAll(RegExp(r'\s+'), ' ');
                      if (!bip39.validateMnemonic(normalized)) {
                        setS(
                          () => errorMsg =
                              'Invalid recovery phrase. Check all words and try again.',
                        );
                        return;
                      }
                      Navigator.pop(ctx, normalized);
                    },
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );

    mnemonicCtrl.dispose();
    if (mnemonic == null || !mounted) return;

    // Step 2 – derive key and show confirmation.
    late Uint8List privKey;
    late String anetAddress;
    late String evmAddress;

    try {
      privKey = _deriveEvmPrivateKeyFromMnemonic(mnemonic);
      anetAddress = _deriveAnetAddressFromPrivateKeyBytes(privKey);
      final ethCreds = EthPrivateKey(privKey);
      final ethAddr = await ethCreds.extractAddress();
      evmAddress = ethAddr.hexEip55;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Derivation failed: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF12162A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Confirm Import',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ANET address (for this app):',
                  style: TextStyle(color: Color(0xFF8899BB), fontSize: 12),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0C1B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    anetAddress,
                    style: const TextStyle(
                      color: Color(0xFF25C474),
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'EVM / MetaMask address:',
                  style: TextStyle(color: Color(0xFF8899BB), fontSize: 12),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0C1B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    evmAddress,
                    style: const TextStyle(
                      color: Color(0xFF6FA3EF),
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Both addresses are derived from the same key. '
                  'Import this wallet to use the ANET DEX?',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color(0xFF8899BB)),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25C474),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Import Wallet'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    // Persist the imported key.
    final privKeyHex = bytesToHex(privKey, include0x: false).toLowerCase();
    final storedKey = 'evmkey:$privKeyHex';
    await saveWalletSeedSecure(storedKey);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasCreatedWallet', true);
    await prefs.setString('createdWalletAddress', anetAddress);
    await prefs.setString('walletProvider', 'EVM Import');

    if (!mounted) return;
    setState(() {
      hasCreatedWallet = true;
      createdWalletAddress = anetAddress;
      walletAddress = anetAddress;
      createdSeedPhrase = storedKey;
      walletProvider = 'EVM Import (MetaMask compatible)';
      walletPinEnabled = false;
      walletSeedOtpRequired = false;
      migrationWalletAddress = evmAddress;
      walletAnetBalance = '-- ANET';
      walletOnchainBalance = '-- ANET';
      _walletUnlockedForSession = true;
      autoStatus = 'EVM wallet imported';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('EVM wallet imported successfully')),
    );
  }

  Future<void> openLegalPage(Uri uri, String label) async {
    try {
      await openLinkInsideApp(context, uri.toString());
      if (!mounted) return;
      setState(() {
        autoStatus = '$label opened';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        autoStatus = '$label unavailable';
      });
    }
  }

  Future<void> _showChangeEmailDialog() async {
    final newEmailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1224),
        title: Text(
          context.l10n.changeEmail,
          style: TextStyle(color: Colors.cyanAccent),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: newEmailCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'New email',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Current password',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.l10n.cancelButton,
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                final res = await changeEmailAPI(
                  newEmailCtrl.text.trim(),
                  passwordCtrl.text,
                );
                if (!mounted) return;
                setState(() {
                  currentEmail =
                      res['user']?['email']?.toString() ?? currentEmail;
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.emailChangedSuccessfully),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceFirst('Exception: ', '')),
                  ),
                );
              }
            },
            child: Text(
              context.l10n.saveButton,
              style: TextStyle(color: Colors.cyanAccent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1224),
        title: Text(
          context.l10n.changePassword,
          style: TextStyle(color: Colors.cyanAccent),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPassCtrl,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Current password',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: newPassCtrl,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'New password (min 8 chars)',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.l10n.cancelButton,
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                await changePasswordAPI(oldPassCtrl.text, newPassCtrl.text);
                if (!mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.passwordChangedSuccessfully),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceFirst('Exception: ', '')),
                  ),
                );
              }
            },
            child: Text(
              context.l10n.saveButton,
              style: TextStyle(color: Colors.cyanAccent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSecurityOwnershipDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1224),
        title: Text(
          context.l10n.securityOwnershipTitle,
          style: TextStyle(color: Colors.cyanAccent),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.emailVerificationNote,
                style: TextStyle(color: Colors.white70, height: 1.35),
              ),
              SizedBox(height: 10),
              Text(
                context.l10n.otpVerificationOneTime,
                style: TextStyle(color: Colors.white70, height: 1.35),
              ),
              SizedBox(height: 10),
              Text(
                context.l10n.emailLossWarning,
                style: TextStyle(
                  color: Colors.orangeAccent,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 10),
              Text(
                context.l10n.ownershipModel,
                style: TextStyle(
                  color: Colors.cyanAccent,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 10),
              Text(
                context.l10n.web4MigrationKeepSafe,
                style: TextStyle(color: Colors.white70, height: 1.35),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.l10n.closeButton,
              style: TextStyle(color: Colors.cyanAccent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showNotificationsDialog() async {
    await NotificationService.initialize();
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1224),
        title: Text(
          context.l10n.notificationsTitle,
          style: TextStyle(color: Colors.cyanAccent),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMining
                  ? 'Ant Work alerts are active for the current 6-hour session.'
                  : 'Start Ant Work to schedule the next completion alert.',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.notificationsInfo,
              style: TextStyle(color: Colors.white70, height: 1.35),
            ),
            const SizedBox(height: 10),
            Text(
              isMining
                  ? 'Current status: session running, completion reminder pending.'
                  : 'Current status: no active session, so no completion reminder is scheduled yet.',
              style: const TextStyle(
                color: Colors.cyanAccent,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.l10n.closeButton,
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              loadAll();
            },
            child: Text(
              context.l10n.refreshButton,
              style: TextStyle(color: Colors.cyanAccent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLanguageDialog() async {
    final current = _appLanguageNotifier.value;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1224),
        title: Text(
          _wt('language'),
          style: const TextStyle(color: Colors.cyanAccent),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _wt('language_help'),
              style: const TextStyle(color: Colors.white70, height: 1.35),
            ),
            const SizedBox(height: 12),
            ...AppLanguage.values.map((language) {
              return RadioListTile<AppLanguage>(
                dense: true,
                activeColor: Colors.cyanAccent,
                value: language,
                groupValue: current,
                title: Text(
                  appLanguageLabel(language),
                  style: const TextStyle(color: Colors.white),
                ),
                onChanged: (value) async {
                  if (value == null) return;
                  await setAppLanguagePreference(value);
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${_wt('language_set_to')} ${appLanguageLabel(value)}',
                      ),
                    ),
                  );
                },
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              _wt('close'),
              style: const TextStyle(color: Colors.cyanAccent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAboutDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1224),
        title: Text(
          context.l10n.aboutTitle,
          style: TextStyle(color: Colors.cyanAccent),
        ),
        content: const Text(
          'A-Network is operated by A Network LLC, California Entity No. 20260170159.\n\nThe production model uses ANTS-first accounting, where 1 ANET = 100,000,000 ANTS. Ant Work runs in validated 6-hour sessions, ANET becomes claimable after the eligibility session threshold is reached, and halving is driven by total verified sessions across the network.\n\nAnt Codes link colony access only. Referrals grow your colony network but do not grant any coin bonuses, session credits, or percentage commissions. Colony Points (CP) are view-only performance metrics. A Network does not guarantee financial returns.',
          style: TextStyle(color: Colors.white70, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.l10n.closeButton,
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _goToPage(3);
            },
            child: Text(
              context.l10n.openWeb4Button,
              style: TextStyle(color: Colors.cyanAccent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showThemeDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _themePanel,
        title: Text(
          context.l10n.displayThemeTitle,
          style: TextStyle(color: _themeAccent),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<_DisplayTheme>(
              value: _DisplayTheme.classic,
              groupValue: _displayTheme,
              activeColor: _themeAccent,
              title: Text(
                context.l10n.classicTheme,
                style: TextStyle(color: _themeTabSelectedLabel),
              ),
              subtitle: Text(
                context.l10n.classicThemeDesc,
                style: TextStyle(color: _themeMutedText),
              ),
              onChanged: (value) async {
                if (value == null) return;
                Navigator.pop(ctx);
                await _setDisplayTheme(value);
              },
            ),
            RadioListTile<_DisplayTheme>(
              value: _DisplayTheme.ants,
              groupValue: _displayTheme,
              activeColor: _themeAccent,
              title: Text(
                context.l10n.antsTheme,
                style: TextStyle(color: _themeTabSelectedLabel),
              ),
              subtitle: Text(
                context.l10n.antsThemeDesc,
                style: TextStyle(color: _themeMutedText),
              ),
              onChanged: (value) async {
                if (value == null) return;
                Navigator.pop(ctx);
                await _setDisplayTheme(value);
              },
            ),
            RadioListTile<_DisplayTheme>(
              value: _DisplayTheme.studio,
              groupValue: _displayTheme,
              activeColor: _themeAccent,
              title: Text(
                context.l10n.studioTheme,
                style: TextStyle(color: _themeTabSelectedLabel),
              ),
              subtitle: Text(
                context.l10n.studioThemeDesc,
                style: TextStyle(color: _themeMutedText),
              ),
              onChanged: (value) async {
                if (value == null) return;
                Navigator.pop(ctx);
                await _setDisplayTheme(value);
              },
            ),
            RadioListTile<_DisplayTheme>(
              value: _DisplayTheme.executive,
              groupValue: _displayTheme,
              activeColor: _themeAccent,
              title: Text(
                context.l10n.executiveTheme,
                style: TextStyle(color: _themeTabSelectedLabel),
              ),
              subtitle: Text(
                context.l10n.executiveThemeDesc,
                style: TextStyle(color: _themeMutedText),
              ),
              onChanged: (value) async {
                if (value == null) return;
                Navigator.pop(ctx);
                await _setDisplayTheme(value);
              },
            ),
            RadioListTile<_DisplayTheme>(
              value: _DisplayTheme.paper,
              groupValue: _displayTheme,
              activeColor: _themeAccent,
              title: Text(
                context.l10n.paperTheme,
                style: TextStyle(color: _themeTabSelectedLabel),
              ),
              subtitle: Text(
                context.l10n.paperThemeDesc,
                style: TextStyle(color: _themeMutedText),
              ),
              onChanged: (value) async {
                if (value == null) return;
                Navigator.pop(ctx);
                await _setDisplayTheme(value);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.l10n.closeButton,
              style: TextStyle(color: _themeAccent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAccountSheet() async {
    await _loadReferralStats();
    if (!mounted) return;

    final stats = _myReferralStats ?? const {};
    final dashboardCompletedSessions =
        int.tryParse((_dashboardData?['completed_sessions'] ?? 0).toString()) ??
        0;
    final referralSessions =
        int.tryParse((stats['mySuccessfulSessions'] ?? 0).toString()) ?? 0;
    final mySessions = dashboardCompletedSessions > 0
        ? dashboardCompletedSessions
        : referralSessions;
    final levelTarget =
        int.tryParse((stats['levelTargetSessions'] ?? 1000).toString()) ?? 1000;
    final sessionRemaining = max(0, levelTarget - mySessions);
    final trackedAntsText = '$walletTrackedAnts ANTS';
    final estimatedAnetText = (walletTrackedAnts / 100000000).toStringAsFixed(
      8,
    );

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF070C1B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.profileSupport,
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Email: ${currentEmail ?? 'Not available'}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 6),
              Text(
                'User ID: ${(currentUserId ?? '--')}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 6),
              Text(
                'Wallet: ${hasCreatedWallet ? createdWalletAddress : 'Not created yet'}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 6),
              Text(
                'Rank: ${(myRank?['rank'] ?? '--')}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 6),
              Text(
                'Global User Mined: ${(network?['totalMined'] ?? '--')} ANET',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 6),
              Text(
                'ANTS Tracked: $trackedAntsText',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 6),
              Text(
                'Estimated ANET: $estimatedAnetText',
                style: const TextStyle(color: Colors.cyanAccent),
              ),
              const SizedBox(height: 6),
              Text(
                'Sessions: $mySessions / $levelTarget (${sessionRemaining == 0 ? 'Eligible' : '$sessionRemaining left'})',
                style: TextStyle(
                  color: sessionRemaining == 0
                      ? Colors.greenAccent
                      : Colors.orangeAccent,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(
                  Icons.badge_outlined,
                  color: Colors.cyanAccent,
                ),
                title: Text(
                  context.l10n.viewProfileDetails,
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showProfileDetailsDialog();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.alternate_email,
                  color: Colors.cyanAccent,
                ),
                title: Text(
                  context.l10n.changeEmail,
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showChangeEmailDialog();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.lock_outline,
                  color: Colors.cyanAccent,
                ),
                title: Text(
                  context.l10n.changePassword,
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showChangePasswordDialog();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.support_agent,
                  color: Colors.cyanAccent,
                ),
                title: Text(
                  context.l10n.helpSupport,
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _openSupportAI();
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: Text(
                  context.l10n.logoutButton,
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  await logout();
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthPage()),
                    (_) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;

      if (_miningEndsAt != null) {
        final diff = _miningEndsAt!.difference(DateTime.now()).inSeconds;
        if (diff > 0) {
          setState(() {
            remainingSeconds = diff;
          });
        } else {
          // Mining time is up - complete it
          t.cancel();
          setState(() {
            remainingSeconds = 0;
          });

          // Show notification only ONCE
          if (!_miningCompletionNotificationShown && mounted) {
            _miningCompletionNotificationShown = true;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.sixHourAntWorkComplete),
                duration: const Duration(seconds: 2),
              ),
            );
          }
          completeMining();
        }
        return;
      }

      if (remainingSeconds > 0) {
        setState(() {
          remainingSeconds--;
        });
      } else {
        t.cancel();
        // Mining time is up - complete it
        if (!_miningCompletionNotificationShown && mounted) {
          _miningCompletionNotificationShown = true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.sixHourAntWorkComplete),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        completeMining();
      }
    });
  }

  int _readRemainingSeconds(Map<String, dynamic> status) {
    final raw = status['remainingSeconds'];
    if (raw is num) {
      return max(0, raw.toInt());
    }
    final parsed = int.tryParse((raw ?? '').toString().trim());
    return max(0, parsed ?? 0);
  }

  void startMining() async {
    if (isStartingMining || isMining) return;

    setState(() {
      isStartingMining = true;
      _miningCompletionNotificationShown = false;
    });

    try {
      if (!AdsService.adsEnabled) {
        await AdsService.enableRuntime();
      }

      // Best-effort ad gate: if ad inventory is unavailable, allow mining start
      // so Web2 mining continuity is not blocked by ad network availability.
      final adShownAndDismissed = await AdsService.showInterstitialAndWait()
          .timeout(const Duration(seconds: 20), onTimeout: () => false);
      if (!adShownAndDismissed) {
        unawaited(AdsService.loadInterstitialAd());
        if (_requireAdBeforeAntWorkStart) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Ad not ready yet. Please tap Ant Work again in a moment.',
                ),
              ),
            );
          }
          return;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Ad temporarily unavailable. Ant Work started without ad.',
              ),
            ),
          );
        }
      }

      await startMiningAPI();

      setState(() {
        isMining = true;
        remainingSeconds = 21600;
        _miningEndsAt = DateTime.now().add(const Duration(hours: 6));
        autoStatus = 'Ant Work started';
      });

      await _syncMiningReminder(endsAt: _miningEndsAt);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.antWorkStartedSuccessfully)),
        );
      }

      startTimer();
      Future.delayed(const Duration(seconds: 2), () async {
        try {
          final status = await getMiningStatus();
          if (await _applyAutoCompletedMiningStatus(status)) {
            return;
          }
          if (status["isMining"] == true &&
              status["remainingSeconds"] != null) {
            final latestRemainingSeconds = _readRemainingSeconds(status);
            if (latestRemainingSeconds <= 0) {
              await completeMining();
              return;
            }
            setState(() {
              remainingSeconds = latestRemainingSeconds;
              _miningEndsAt = DateTime.now().add(
                Duration(seconds: remainingSeconds),
              );
            });
            await _syncMiningReminder(endsAt: _miningEndsAt);
          } else {
            setState(() {
              isMining = false;
              _miningEndsAt = null;
              autoStatus = 'Ant Work status not confirmed';
            });
            await _syncMiningReminder(clear: true);
          }
        } catch (e) {
          debugPrint("Sync error: $e");
        }
      });
    } catch (e) {
      final message = e.toString();

      if (message.contains('Already mining')) {
        try {
          final status = await getMiningStatus();
          if (await _applyAutoCompletedMiningStatus(status)) {
            return;
          }
          if (status["isMining"] == true) {
            final latestRemainingSeconds = _readRemainingSeconds(status);
            if (latestRemainingSeconds <= 0) {
              await completeMining();
              return;
            }
            if (mounted) {
              setState(() {
                isMining = true;
                remainingSeconds = latestRemainingSeconds;
                _miningEndsAt = DateTime.now().add(
                  Duration(seconds: remainingSeconds),
                );
                autoStatus = 'Ant Work resumed';
              });
              if (remainingSeconds > 0) {
                startTimer();
                await _syncMiningReminder(endsAt: _miningEndsAt);
              }
            }
            return;
          }
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Start Ant Work failed: $message')),
        );
      }

      setState(() {
        autoStatus = 'Start Ant Work failed';
      });

      debugPrint("Start mining error: $e");
    } finally {
      if (mounted) {
        setState(() {
          isStartingMining = false;
        });
      }
    }
  }

  Future<void> completeMining() async {
    if (_isCompletingMining) return;
    _isCompletingMining = true;

    try {
      final res = await completeMiningAPI();
      final reward = double.tryParse((res["reward"] ?? 0).toString()) ?? 0;
      final updatedBalance =
          double.tryParse(
            (res["userBalance"] ?? (balance + reward)).toString(),
          ) ??
          (balance + reward);
      final updatedGlobalMined =
          double.tryParse((res["totalMined"] ?? 0).toString()) ?? 0;

      // Cancel timer to prevent further ticks
      timer?.cancel();
      timer = null;

      setState(() {
        balance = updatedBalance;
        walletAnetBalance = '${updatedBalance.toStringAsFixed(4)} ANET';
        if (res.containsKey('totalMined')) {
          globalAnetMined = '${updatedGlobalMined.toStringAsFixed(8)} ANET';
        }
        isMining = false;
        remainingSeconds = 0;
        _miningEndsAt = null;
        _miningCompletionNotificationShown = false;
      });

      await _syncMiningReminder(clear: true);

      /// Show ad and notify mining is complete
      if (!AdsService.adsEnabled) {
        await AdsService.enableRuntime();
      }
      await AdsService.showInterstitialBestEffort();
      await NotificationService.showMiningRewardNotification(reward);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.antWorkCompletedAccumulated(
                reward.toStringAsFixed(4),
              ),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.completeAntWorkFailed('$e'))),
        );
      }
      debugPrint("Complete error: $e");

      // Keep mining state authoritative from server so users cannot spam starts.
      try {
        final status = await getMiningStatus();
        if (await _applyAutoCompletedMiningStatus(status)) {
          return;
        }

        final stillMining = status['isMining'] == true;
        final latestRemainingSeconds = _readRemainingSeconds(status);
        if (mounted) {
          setState(() {
            isMining = stillMining;
            _miningCompletionNotificationShown = false;
            if (stillMining) {
              remainingSeconds = latestRemainingSeconds;
              _miningEndsAt = DateTime.now().add(
                Duration(seconds: latestRemainingSeconds),
              );
            }
          });
        }

        if (stillMining && latestRemainingSeconds > 0) {
          startTimer();
          await _syncMiningReminder(endsAt: _miningEndsAt);
        } else {
          await _syncMiningReminder(clear: true);
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _miningCompletionNotificationShown = false;
          });
        }
      }
    } finally {
      _isCompletingMining = false;
    }
  }

  Future<bool> _applyAutoCompletedMiningStatus(
    Map<String, dynamic> status,
  ) async {
    if (status['autoCompleted'] != true || status['completion'] is! Map) {
      return false;
    }

    final completion = Map<String, dynamic>.from(status['completion'] as Map);
    final reward = double.tryParse((completion['reward'] ?? 0).toString()) ?? 0;
    final updatedBalance =
        double.tryParse((completion['userBalance'] ?? balance).toString()) ??
        balance;
    final updatedGlobalMined =
        double.tryParse((completion['totalMined'] ?? 0).toString()) ?? 0;

    timer?.cancel();
    timer = null;

    if (mounted) {
      setState(() {
        balance = updatedBalance;
        walletAnetBalance = '${updatedBalance.toStringAsFixed(4)} ANET';
        if (completion.containsKey('totalMined')) {
          globalAnetMined = '${updatedGlobalMined.toStringAsFixed(8)} ANET';
        }
        isMining = false;
        remainingSeconds = 0;
        _miningEndsAt = null;
        _miningCompletionNotificationShown = false;
        autoStatus = reward > 0 ? 'Ant Work auto-completed' : 'Ant Work ended';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reward > 0
                ? context.l10n.antWorkAutoCompleted(reward.toStringAsFixed(4))
                : (completion['message'] ??
                          'Ant Work session closed automatically')
                      .toString(),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }

    await _syncMiningReminder(clear: true);
    return true;
  }

  String formatTime(int s) {
    if (s <= 0) return "00:00:00";
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}";
  }

  Widget buildActionButton(
    String label,
    VoidCallback onPressed, {
    IconData? icon,
    bool compact = false,
    bool pulse = false,
    bool emphasized = false,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 420;
    final buttonWidth = compact
        ? (isNarrow ? 134.0 : 148.0)
        : (isNarrow ? 150.0 : 165.0);
    final buttonHeight = compact ? 42.0 : 48.0;

    Widget button = SizedBox(
      width: buttonWidth,
      height: buttonHeight,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: (emphasized ? _themeAccent : _themeAccentAlt).withValues(
                alpha: emphasized ? 0.20 : 0.10,
              ),
              blurRadius: emphasized ? 18 : 10,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: emphasized
                ? _themeAccent
                : (_isLightStageTheme
                      ? _themeAccentAlt
                      : (_isAntsTheme ? _themeAccentAlt : _themeAccent)),
            foregroundColor: emphasized
                ? _themeOnAccent
                : (_isLightStageTheme || _isAntsTheme
                      ? Colors.white
                      : Colors.black),
            elevation: 0,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 14,
              vertical: compact ? 8 : 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            side: BorderSide(
              color: _themeAccent.withValues(
                alpha: emphasized ? 0.48 : (_isAntsTheme ? 0.35 : 0.16),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: compact ? 16 : 18),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 12.5 : 13.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (pulse) {
      button = AnimatedBuilder(
        animation: _antWorkPulseController,
        builder: (context, child) {
          return Transform.scale(
            scale: _antWorkPulseScale.value,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: _themeAccent.withValues(
                      alpha: _antWorkPulseGlow.value,
                    ),
                    blurRadius: 18 + (_antWorkPulseGlow.value * 20),
                    spreadRadius: _antWorkPulseGlow.value * 1.5,
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: button,
      );
    }

    return button;
  }

  Widget metricCard(String title, String value) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = min(196.0, (screenWidth - 56) / 2);

    return Container(
      width: cardWidth,
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(emphasis: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: _themeAccent,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.75,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAnetMarketSheet() async {
    final swapUrl =
        'https://pancakeswap.finance/swap?chain=bsc&outputCurrency=$anetContract';
    final chartUrl = 'https://dexscreener.com/bsc/$anetDexPair';
    final contractUrl = 'https://bscscan.com/token/$anetContract';

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF070C1B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.web3AnetMarket,
                style: TextStyle(
                  color: _themeAccent,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Important: mined ANET in this app is accumulated through Ant Work. The BNB Chain ANET contract below is the separate Web3 visibility layer and does not directly increase a user\'s in-app ANET coin balance.',
                style: TextStyle(color: _themeMutedText, height: 1.45),
              ),
              const SizedBox(height: 14),
              Text(
                context.l10n.bnbChainContract,
                style: TextStyle(
                  color: _themeAccent,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              SelectableText(
                anetContract,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: _panelDecoration(emphasis: true),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.currentSeparation,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.separationPoint1,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.35,
                      ),
                    ),
                    Text(
                      context.l10n.separationPoint2,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.35,
                      ),
                    ),
                    Text(
                      context.l10n.separationPoint3,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.35,
                      ),
                    ),
                    Text(
                      context.l10n.separationPoint4,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _actionButton(
                    'Open Market Pair',
                    () => openLinkInsideApp(context, swapUrl),
                  ),
                  _actionButton(
                    'View Live Chart',
                    () => openLinkInsideApp(context, chartUrl),
                  ),
                  _actionButton(
                    'View Contract',
                    () => openLinkInsideApp(context, contractUrl),
                  ),
                  _actionButton(
                    'Copy Contract',
                    () => _copyText(anetContract, 'ANET market contract'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(String label, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _signalPill(String label, {Color? color}) {
    final tone = color ?? _themeAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: _isLightStageTheme ? 0.14 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tone,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _dataRailCard({
    required String label,
    required String value,
    String? helper,
    IconData? icon,
    Color? accent,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = min(280.0, (screenWidth - 56) / 2);
    final tone = accent ?? _themeAccent;

    return Container(
      width: cardWidth,
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: tone, size: 18),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: tone,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.55,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          if (helper != null) ...[
            const SizedBox(height: 8),
            Text(
              helper,
              style: TextStyle(
                color: _themeMutedText,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _insightCard({
    required String title,
    required String body,
    required IconData icon,
    Color? accent,
    bool warm = false,
  }) {
    final tone = accent ?? (warm ? _themeGold : _themeAccent);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(emphasis: true, warm: warm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: tone, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: tone,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: TextStyle(
              color: _themeMutedText,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _themedStage({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _themeStageGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          _themedParticleBackground(),
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.2,
                colors: [
                  _themeAccent.withValues(
                    alpha: _isStudioTheme ? 0.10 : (_isAntsTheme ? 0.12 : 0.08),
                  ),
                  _themeAccentAlt.withValues(
                    alpha: _isStudioTheme ? 0.06 : (_isAntsTheme ? 0.08 : 0.04),
                  ),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Container(
            color: Colors.black.withValues(alpha: _themeStageOverlayOpacity),
          ),
          child,
        ],
      ),
    );
  }

  Widget web3SlidePage() {
    // ── NOT CREATED ──────────────────────────────────────────────
    if (!hasCreatedWallet) {
      return _themedStage(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _glassPanel(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 56,
                    color: _themeAccent,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    context.l10n.createYourL1Wallet,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.createL1WalletMessage,
                    style: TextStyle(color: _themeMutedText, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  buildActionButton(
                    'Generate Wallet',
                    createWallet,
                    compact: true,
                    icon: Icons.add_card_rounded,
                    emphasized: true,
                  ),
                  const SizedBox(height: 10),
                  buildActionButton(
                    'Import EVM / MetaMask Wallet',
                    _importEvmWalletFlow,
                    compact: true,
                    icon: Icons.download_rounded,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ── LOCKED ───────────────────────────────────────────────────
    if (!_walletUnlockedForSession) {
      return _themedStage(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _glassPanel(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_rounded,
                    size: 56,
                    color: walletPinEnabled ? _themeAccent : _themeGold,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    walletPinEnabled
                        ? _wt('wallet_locked')
                        : _wt('set_pin_continue'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    walletPinEnabled
                        ? _wt('enter_wallet_pin_message')
                        : _wt('set_pin_secure_message'),
                    style: TextStyle(color: _themeMutedText, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  buildActionButton(
                    walletPinEnabled
                        ? _wt('unlock_wallet')
                        : _wt('set_wallet_pin'),
                    _promptWalletUnlock,
                    compact: true,
                    icon: walletPinEnabled
                        ? Icons.lock_open_rounded
                        : Icons.password_rounded,
                    emphasized: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ── UNLOCKED ─────────────────────────────────────────────────
    final appBalanceNum =
        double.tryParse(walletAnetBalance.split(' ').first) ?? balance;
    final completedSessions = _currentDisplayedSessions();
    final sendUnlocked = completedSessions >= 1000 || sessionGateBypassEnabled;
    final shortAddress = _shortWalletAddress(createdWalletAddress);

    // OKX-style palette
    const Color okxBg = Color(0xFF0A0C1B);
    const Color okxCard = Color(0xFF12162A);
    const Color okxBorder = Color(0xFF1E2440);
    const Color okxBlue = Color(0xFF1677FF);
    const Color okxGold = Color(0xFFFFB800);
    const Color okxGreen = Color(0xFF25C474);
    const Color okxRed = Color(0xFFFF4B4B);
    const Color okxMuted = Color(0xFF7B829A);
    const Color okxTextPrimary = Colors.white;
    const Color okxLabel = Color(0xFFB0B8CF);

    final networkColor = _selectedEvmNetwork == 'Ethereum'
        ? const Color(0xFF627EEA)
        : _selectedEvmNetwork == 'Polygon'
        ? const Color(0xFF8247E5)
        : _selectedEvmNetwork == 'Arbitrum One'
        ? const Color(0xFF28A0F0)
        : _selectedEvmNetwork == 'Optimism'
        ? const Color(0xFFFF0420)
        : _selectedEvmNetwork == 'Base'
        ? const Color(0xFF0052FF)
        : _selectedEvmNetwork == 'Avalanche C-Chain'
        ? const Color(0xFFE84142)
        : _selectedEvmNetwork == 'Fantom'
        ? const Color(0xFF1969FF)
        : _selectedEvmNetwork == 'Linea'
        ? const Color(0xFF81FD5D)
        : _selectedEvmNetwork == 'zkSync Era'
        ? const Color(0xFF8C8DFB)
        : _selectedEvmNetwork == 'opBNB'
        ? const Color(0xFFF3BA2F)
        : _selectedEvmNetwork == 'ANET L1 Bridge'
        ? okxGold
        : const Color(0xFFF0B90B);

    return Scaffold(
      backgroundColor: okxBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── TOP BAR ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Account avatar
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF7B83FF)],
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'A',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _wt('mainnet_wallet'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            await Clipboard.setData(
                              ClipboardData(text: createdWalletAddress),
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Address copied'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                shortAddress,
                                style: const TextStyle(
                                  color: okxMuted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.copy_rounded,
                                size: 12,
                                color: okxMuted,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Network badge
                  GestureDetector(
                    onTap: () => _showNetworkPickerSheet(
                      okxBg,
                      okxCard,
                      okxBorder,
                      okxLabel,
                      okxBlue,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: networkColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: networkColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: networkColor,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _networkShortName(_selectedEvmNetwork),
                            style: TextStyle(
                              color: networkColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 14,
                            color: networkColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Settings
                  GestureDetector(
                    onTap: _showAccountSheet,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: okxCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: okxBorder),
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── TABS: Home | Assets | Activity | Sessions ────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _okxTabItem(
                    _wt('home'),
                    0,
                    _walletTabIndex,
                    okxBlue,
                    okxMuted,
                    () => setState(() => _walletTabIndex = 0),
                  ),
                  const SizedBox(width: 4),
                  _okxTabItem(
                    _wt('assets'),
                    1,
                    _walletTabIndex,
                    okxBlue,
                    okxMuted,
                    () => setState(() => _walletTabIndex = 1),
                  ),
                  const SizedBox(width: 4),
                  _okxTabItem(
                    _wt('activity'),
                    2,
                    _walletTabIndex,
                    okxBlue,
                    okxMuted,
                    () => setState(() => _walletTabIndex = 2),
                  ),
                  const SizedBox(width: 4),
                  _okxTabItem(
                    _wt('sessions'),
                    3,
                    _walletTabIndex,
                    okxBlue,
                    okxMuted,
                    () {
                      setState(() => _walletTabIndex = 3);
                      if (_miningSessionHistory.isEmpty &&
                          !_miningSessionHistoryLoading) {
                        _loadMiningSessionHistory();
                      }
                    },
                  ),
                  const Spacer(),
                  // Add token button
                  GestureDetector(
                    onTap: _showAddCustomCoinDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: okxBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: okxBlue.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.add_rounded,
                            size: 14,
                            color: okxBlue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _wt('add_token'),
                            style: const TextStyle(
                              color: okxBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 2),
            Divider(color: okxBorder, height: 1),

            // ── TAB CONTENT ──────────────────────────────────────
            Expanded(
              child: _walletTabIndex == 0
                  ? _okxHomeTab(
                      okxCard: okxCard,
                      okxBorder: okxBorder,
                      okxGold: okxGold,
                      okxGreen: okxGreen,
                      okxBlue: okxBlue,
                      okxMuted: okxMuted,
                      appBalanceNum: appBalanceNum,
                      completedSessions: completedSessions,
                      sendUnlocked: sendUnlocked,
                    )
                  : _walletTabIndex == 1
                  ? _okxAssetsTab(
                      okxCard: okxCard,
                      okxBorder: okxBorder,
                      okxGold: okxGold,
                      okxGreen: okxGreen,
                      okxBlue: okxBlue,
                      okxMuted: okxMuted,
                      okxLabel: okxLabel,
                      okxTextPrimary: okxTextPrimary,
                      sendUnlocked: sendUnlocked,
                      completedSessions: completedSessions,
                    )
                  : _walletTabIndex == 2
                  ? _okxActivityTab(
                      okxCard: okxCard,
                      okxBorder: okxBorder,
                      okxGreen: okxGreen,
                      okxRed: okxRed,
                      okxMuted: okxMuted,
                      okxLabel: okxLabel,
                    )
                  : _okxSessionsTab(
                      okxCard: okxCard,
                      okxBorder: okxBorder,
                      okxGreen: okxGreen,
                      okxBlue: okxBlue,
                      okxMuted: okxMuted,
                      okxLabel: okxLabel,
                      okxTextPrimary: okxTextPrimary,
                      appBalanceNum: appBalanceNum,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// OKX-style circular action button
  Widget _okxActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _walletLangCode() {
    final selected = _appLanguageNotifier.value;
    if (selected == AppLanguage.hindi) return 'hi';
    if (selected == AppLanguage.urdu) return 'ur';
    if (selected == AppLanguage.chinese) return 'zh';
    if (selected == AppLanguage.english) return 'en';
    if (selected == AppLanguage.spanish) return 'es';
    if (selected == AppLanguage.vietnamese) return 'vi';

    final systemLang = WidgetsBinding
        .instance
        .platformDispatcher
        .locale
        .languageCode
        .toLowerCase();
    if (systemLang.startsWith('hi')) return 'hi';
    if (systemLang.startsWith('ur')) return 'ur';
    if (systemLang.startsWith('zh')) return 'zh';
    if (systemLang.startsWith('es')) return 'es';
    if (systemLang.startsWith('vi')) return 'vi';
    return 'en';
  }

  String _wt(String key) {
    const en = <String, String>{
      'mainnet_wallet': 'Mainnet Wallet',
      'home': 'Home',
      'assets': 'Assets',
      'activity': 'Activity',
      'sessions': 'Sessions',
      'add_token': 'Add Token',
      'total_balance': 'Total Balance',
      'send': 'Send',
      'receive': 'Receive',
      'explorer': 'Explorer',
      'bridge': 'Bridge',
      'mining_profile': 'Mining Profile',
      'joined': 'Joined',
      'completed_sessions': 'Completed Sessions',
      'anet_balance': 'ANET Balance',
      'current_rate': 'Current Rate',
      'colony_joined': 'Colony Joined',
      'not_in_colony': 'Not in a colony',
      'session_history': 'Session History',
      'credited': 'Credited',
      'in_progress': 'In Progress',
      'language': 'Language',
      'language_help':
          'Choose your app language. Auto mode maps region defaults: India -> Hindi, Pakistan -> Urdu, China -> Chinese, Spain/Latin America -> Espanol, Vietnam -> Vietnamese, and English fallback for other regions.',
      'language_set_to': 'Language set to',
      'close': 'Close',
      'start': 'Start',
      'end': 'End',
      'halving_level': 'Halving Level',
      'load_older_sessions': 'Load older sessions',
      'loading_older_sessions': 'Loading older sessions...',
      'ann_halving_title': 'HALVING HAS STARTED',
      'ann_halving_body':
          'The network has reached the 500,000-session milestone. The first halving is now in effect.',
      'ann_halving_note':
          'There is a 6-hour validation delay before the updated rate is applied. The system validates all pending sessions first. Once the 500k milestone is confirmed, your Live Output will update to the new halving rate automatically.',
      'ann_halving_safe':
          'No action required - sessions in progress are safe and will credit at the correct rate.',
      'ann_x_title': 'LATEST X UPDATE',
      'ann_x_body':
          'Follow Mr_A_Awakening for the latest official A-Network posts.',
      'ann_x_note':
          'This slide rotates automatically every 60 seconds with the halving update card.',
      'ann_x_cta': 'Open latest X updates',
      'page_subtitle_ecosystem':
          'Live network view, ecosystem actions, and colony growth tools.',
      'page_subtitle_antwork':
          'Run 6-hour Ant Work sessions and track verified activity milestones.',
      'page_subtitle_wallet':
          'Check balances, wallet tools, and live Layer 1 visibility from one place.',
      'page_subtitle_web4':
          'Live Layer 1 private/enclosed mainnet, migration targets, and long-term ANTS settlement design.',
      'page_subtitle_whitepaper':
          'Read the current operating model, distribution rules, and system design.',
      'page_subtitle_colony':
          'Manage your own colony room and any linked upline room clearly.',
      'page_subtitle_more':
          'Support, legal pages, language, notifications, and account controls.',
      'page_info_ecosystem':
          'Ant Ecosystem is the operational home screen. It combines live stats, quick actions, and access to the main colony tools so users can understand the network before starting a session.',
      'page_info_antwork':
          'Ant Work runs in 6-hour validated sessions. Activity is tracked in ANTS first, ANET becomes claimable only after the required completed-session threshold is met, and halving follows total verified session milestones across the network.',
      'page_info_wallet':
          'ANET Wallet groups your internal ANET balance, wallet setup, and chain-facing visibility tools. It is where Web2 session activity, Web3 market references, and the live ANET Layer 1 explorer meet.',
      'page_info_web4':
          'Web4 explains how the live ANET Layer 1 private/enclosed mainnet works with Web2 Ant Work today, while migration, claim flow, and broader production settlement are still being staged.',
      'page_info_whitepaper':
          'The Whitepaper page summarizes the current production rules: ANTS-first accounting, a 21 million ANET cap, 6-hour sessions, session-based halving, and a referral model for colony growth only - no coin or session bonuses.',
      'page_info_colony':
          'Colony (Web5) is where Ant Codes and community rooms connect. Users can keep their own colony room, join an upline colony when linked, and switch scopes when both rooms are available.',
      'page_info_more':
          'More centralizes operational settings and legal context. Use it for ownership security, alerts, language status, privacy, terms, support, and project information before launch or migration actions.',
      'total_ants': 'Total Ants',
      'total_ants_info_body':
          'The total number of ants who have registered their identity in the A-Network colony - every ant that has ever entered the colony gates.',
      'active_workers': 'Active Workers',
      'active_workers_info_body':
          'The total number of dedicated worker ants who have successfully completed at least one full work session in the colony. These ants have proven their commitment by finishing a verified 6-hour shift.',
      'completed_work': 'completed work',
      'active_territories': 'Active Territories',
      'verified_sessions': 'VERIFIED SESSIONS',
      'network_throughput': 'Network throughput',
      'live_output': 'LIVE OUTPUT',
      'markets': 'MARKETS',
      'completed_at_least_one_session': 'Completed at least one session',
      'open': 'Open',
      'live_ant_work': 'Live Ant Work',
      'live_ant_work_info_body':
          'This card is the executive snapshot of the active mining session. It shows your current state, session output, remaining time, and accumulated balance without exposing the full command-center detail until needed.',
      'tracked': 'tracked',
      'session_output': 'SESSION OUTPUT',
      'anet_per_6h_cycle': 'ANET per 6-hour cycle',
      'portfolio': 'PORTFOLIO',
      'accumulated': 'accumulated',
      'open_ant_work': 'Open Ant Work',
      'start_ant_work': 'Start Ant Work',
      'refresh_activity': 'Refresh Activity',
      'ant_work_in_progress': 'Ant work in progress',
      'begin_your_journey': 'Begin your journey',
      'anet_wallet': 'ANET Wallet',
      'wallet_tools_chain_visibility':
          'Balance, wallet tools, chain visibility',
      'network_status': 'Network status',
      'online': 'ONLINE',
      'total_working_ants': 'Total Working Ants',
      'together_future': 'Together, we build the future.',
      'starting_session': 'Starting session...',
      'session_active_now': 'Session is active now',
      'ready_new_session': 'Ready for a new 6-hour session',
      'live': 'LIVE',
      'ready': 'READY',
      'quick_action': 'Quick action',
      'wallet_locked': 'Wallet Locked',
      'set_pin_continue': 'Set PIN to Continue',
      'enter_wallet_pin_message':
          'Enter your wallet PIN to access your Web3 wallet.',
      'set_pin_secure_message':
          'Set a PIN to secure your wallet before accessing it.',
      'unlock_wallet': 'Unlock Wallet',
      'set_wallet_pin': 'Set Wallet PIN',
      'ant_work_running': 'Ant Work...',
      'starting': 'Starting...',
      'six_hour_session_active': '6-hour session active',
      'no_active_session': 'No active session',
      'next_stage_unlocked': 'Next stage unlocked',
      'sessions_to_next_stage': 'sessions to next stage',
      'standby': 'STANDBY',
      'halving_stage': 'Halving stage',
      'rank': 'Rank',
      'supply_progress': 'Supply progress',
      'refresh': 'Refresh',
      'balance': 'Balance',
      'tracked_balance': 'TRACKED BALANCE',
      'network_scale': 'NETWORK SCALE',
      'next_stage': 'NEXT STAGE',
      'target': 'Target',
      'session_rules': 'Session Rules',
      'validated_cycle_6h': '6-hour validated cycle',
      'sessions_to_claim_anet': 'sessions to claim ANET',
      'rewards_tracked_ants_first':
          'Rewards are tracked in ANTS first. Session credit posts only after the server validates completion.',
      'network_rules': 'Network Rules',
      'next_output': 'Next output',
      'referrals_grow_colony_only':
          'Referrals grow the colony only. Registration count, colony size, and wallet balance do not change halving or create coin bonuses.',
      'supply_ledger': 'Supply Ledger',
      'global_mined': 'Global mined',
      'total_max_supply': 'Total max supply',
      'wp_title': 'A-Network Whitepaper',
      'wp_open_privacy': 'Open Privacy Policy',
      'wp_open_terms': 'Open Terms',
      'col_title': 'Colony Chat | Web5 ANET Core',
      'col_subtitle':
          'Colony-selected ant groups, contribution tracks, mentorship, and long-term ecosystem building.',
      'col_worker_transfer': 'Worker Transfer',
      'col_copy_address': 'Copy Address',
      'col_view_seed': 'View Seed',
      'col_set_pin': 'Set PIN',
      'col_change_pin': 'Change PIN',
      'col_quick_access_title': 'Web5 Quick Access',
      'col_colony_access_title': 'Colony Access',
      'col_migration_title': 'Migration To Web3 (Planned)',
      'col_anet_core_title': 'ANET Core Program',
      'col_open_all_title': 'Open To All Backgrounds',
      'col_tracks_title': 'Contribution Tracks (Planned)',
      'col_roadmap_note':
          'Roadmap note: the enforced model is Web2 mining, Web3 visibility, and Web5 community coordination. ANET-Chain remains the public blockchain transparency layer, while future ANET Core access rules and partner onboarding criteria will be announced separately.',
      'wp_version':
          'Version 1.0.5 | Protocol Summary, Ant Work Rules, Layer 1 Private/Enclosed Mainnet, Privacy, and Policy',
      'wp_risk_notice':
          'Risk Notice: A-Network is a long-term technology initiative. It is not financial advice and does not guarantee returns. Eligible miners may receive fee-based ecosystem rewards tied to verified network activity under protocol rules.',
      'wp_1_title': '1. Mission',
      'wp_1_body':
          'Build a participation ledger in which work is measured, issuance is bounded, and Web2 activity can settle into a live Layer 1 system without obscuring the rules of supply.',
      'wp_2_title': '2. Version 1.0.5 Summary',
      'wp_2_body':
          'A-Network v1.0.5 is an ANTS-first Ant Work system. Users complete validated 6-hour sessions, accrue ANTS in the ledger, and reach Layer 1 claim eligibility only after 1,000 successful sessions. The ANET Layer 1 private/enclosed mainnet is live and records event-driven settlement activity.',
      'wp_3_title': '3. Three-Layer Economy',
      'wp_3_body':
          'Web2 Off-Chain Economy: session tracking, account state, fraud control, and ANTS ledger accounting.\n\nWeb3 Visibility Economy: BNB Chain token visibility, contract transparency, and wallet reference.\n\nWeb4 Settlement Economy: live Layer 1 private/enclosed mainnet, event-driven settlement blocks, ANTS-denominated fee logic, and future migration into broader on-chain participation.',
      'wp_4_title': '4. Unit Model',
      'wp_4_body':
          '1 ANET = 100,000,000 ANTS. ANTS is the smallest accounting unit. Session output is computed in ANET-equivalent terms but stored in ANTS to preserve precision and support Layer 1 settlement.',
      'wp_5_title': '5. Session Rules',
      'wp_5_body':
          'Each Ant Work session lasts 6 hours. A user may complete at most 4 sessions per day. Instant completion is rejected. Session start and completion are timestamped for audit and abuse control.',
      'wp_6_title': '6. Distribution Engine',
      'wp_6_body':
          'The first 500,000 total network sessions use the launch output of 0.04882812 ANET per completed session. After that tranche, the long-life schedule begins at 0.00262144 ANET per completed session, credited as 262,144 ANTS, and then halves according to total network sessions. Issuance is driven by verified work, not referrals or user count.',
      'wp_7_title': '7. Halving Logic',
      'wp_7_body':
          'Halving is based only on total completed sessions. The first 500,000 sessions form the launch tranche. After that, session output halves every additional 3,800,000,000 sessions through Stage 9.',
      'wp_8_title': '8. Eligibility and Claim',
      'wp_8_body':
          'A miner becomes eligible to convert ANTS into ANET after 1,000 successful sessions. Before that threshold, ANTS remains recorded in the ledger but is not claimable as ANET.',
      'wp_9_title': '9. Supply Protection',
      'wp_9_body':
          'The backend enforces the 21,000,000 cap at conversion time. If a claim would cross the cap, it is reduced to the exact remaining supply and cannot create negative output.',
      'wp_10_title': '10. Global State',
      'wp_10_body':
          'The production API exposes global state for analytics and client display: total users, total sessions, active miners, eligible users, converted users, total ANTS accumulated, total ANET claimed, current distribution stage, and halving progress.',
      'wp_11_title': '11. Wallet and Migration',
      'wp_11_body':
          'Each account can create an ANET wallet identity and optionally set a separate migration wallet. Wallet continuity includes PIN protection, OTP-gated seed reveal, and migration progress tracking.',
      'wp_12_title': '12. Reset Policy',
      'wp_12_body':
          'The reset model can clear Ant Work state while preserving accounts and wallet addresses. User sessions, ANTS balances, claimed ANET, eligibility flags, and global counters return to zero without deleting identity records.',
      'wp_13_title': '13. Security and Anti-Abuse',
      'wp_13_body':
          'Protections include OTP email verification, trusted-device checks, session-bound JWTs, device limits, one active session at a time, daily session caps, heartbeat validation, risk scoring, gated claims for flagged accounts, and security audit logs.',
      'wp_14_title': '14. Privacy & Responsible Use',
      'wp_14_body':
          'The system collects the credentials, contact data, device signals, wallet links, and activity records required to operate the service, prevent fraud, and support compliance. Botting, abuse, and exploit behavior are prohibited.',
      'wp_15_title': '15. Compliance and Risk Notice',
      'wp_15_body':
          'A-Network is a technology project, not financial advice, and does not guarantee returns. Ant Work output, ANTS balances, ANET conversion, notifications, wallet recovery, controlled distributions, and fee-based miner rewards remain subject to current backend rules and future governance or security review.',
      'wp_16_title': '16. Long-Term Direction',
      'wp_16_body':
          'The roadmap remains Web2 participation -> Web3 visibility -> live Web4 private/enclosed mainnet settlement -> ANET Core. The immediate priority is ledger stability, mainnet reliability, and audited migration and claim paths for broader release.',
      'col_quick_access_body':
          'Use Worker Transfer to open only the live Layer 1 transfer form with your wallet prefilled inside the dApp browser. Copy Address, View Seed, and Change PIN are duplicated here so you do not need to slide back to Web4 for common wallet-security actions.',
      'col_colony_access_body':
          'Each account owner has a designated colony room. The owner can pick the colony name from preset options, while direct colony ants are routed into that same named room by the server. Ads remain inside the chat panel.',
      'col_migration_body':
          'Web3 remains a separate operating layer for public contract visibility, partner participation, and later buyer-based onboarding. It does not redefine Web2 mining accounting or colony scoring in the current build.',
      'col_anet_core_body':
          'ANET Core is the future Web5 direction. Group colonies can become part of that layer later, with community identity, public blockchain visibility through ANET-Chain, and broader coordination roles evolving together over time.',
      'col_open_all_body':
          'Coding experience is welcome but not required. A-Network can support contributors through mentoring, practical tasks, and structured learning tracks.',
      'col_tracks_body':
          'Potential tracks include education support, community ops, testing, documentation, research, design, product feedback, and engineering collaboration.',
    };
    const hi = <String, String>{
      'mainnet_wallet': 'मेननेट वॉलेट',
      'home': 'होम',
      'assets': 'एसेट्स',
      'activity': 'गतिविधि',
      'sessions': 'सेशन्स',
      'add_token': 'टोकन जोड़ें',
      'total_balance': 'कुल बैलेंस',
      'send': 'भेजें',
      'receive': 'प्राप्त करें',
      'explorer': 'एक्सप्लोरर',
      'bridge': 'ब्रिज',
      'mining_profile': 'माइनिंग प्रोफाइल',
      'joined': 'जुड़े',
      'completed_sessions': 'पूर्ण सेशन्स',
      'anet_balance': 'ANET बैलेंस',
      'current_rate': 'वर्तमान रेट',
      'colony_joined': 'कॉलोनी जुड़ने की तिथि',
      'not_in_colony': 'किसी कॉलोनी में नहीं',
      'session_history': 'सेशन हिस्ट्री',
      'credited': 'क्रेडिटेड',
      'in_progress': 'प्रगति में',
      'language': 'भाषा',
      'language_help':
          'अपनी ऐप भाषा चुनें। ऑटो मोड क्षेत्र के अनुसार डिफ़ॉल्ट सेट करता है: भारत -> हिंदी, पाकिस्तान -> उर्दू, चीन -> चीनी, स्पेन/लैटिन अमेरिका -> स्पैनिश, वियतनाम -> वियतनामी, अन्य क्षेत्रों के लिए अंग्रेजी।',
      'language_set_to': 'भाषा सेट की गई',
      'close': 'बंद करें',
      'start': 'शुरू',
      'end': 'समाप्त',
      'halving_level': 'हाल्विंग स्तर',
      'load_older_sessions': 'पुराने सेशन्स लोड करें',
      'loading_older_sessions': 'पुराने सेशन्स लोड हो रहे हैं...',
      'ann_halving_title': 'HALVING शुरू हो गया है',
      'ann_halving_body':
          'नेटवर्क 500,000 सेशन माइलस्टोन पर पहुंच चुका है। पहली halving अब लागू है।',
      'ann_halving_note':
          'नई दर लागू होने से पहले 6 घंटे का validation delay है। सिस्टम पहले सभी pending sessions को validate करता है। 500k माइलस्टोन confirm होने पर Live Output अपने आप नई rate पर अपडेट होगा।',
      'ann_halving_safe':
          'कोई action जरूरी नहीं - प्रगति में sessions सुरक्षित हैं और सही rate पर credit होंगे।',
      'ann_x_title': 'LATEST X UPDATE',
      'ann_x_body':
          'Mr_A_Awakening पर A-Network की नवीनतम आधिकारिक पोस्ट देखें।',
      'ann_x_note':
          'यह स्लाइड halving अपडेट कार्ड के साथ हर 60 सेकंड में स्वतः बदलती है।',
      'ann_x_cta': 'लेटेस्ट X अपडेट खोलें',
      'page_subtitle_ecosystem':
          'लाइव नेटवर्क व्यू, इकोसिस्टम एक्शन और कॉलोनी ग्रोथ टूल्स।',
      'page_subtitle_antwork':
          '6-घंटे के एंट वर्क सेशन चलाएं और सत्यापित एक्टिविटी माइलस्टोन ट्रैक करें।',
      'page_subtitle_wallet':
          'एक ही जगह बैलेंस, वॉलेट टूल्स और लाइव लेयर 1 विजिबिलिटी देखें।',
      'page_subtitle_web4':
          'लाइव लेयर 1 प्राइवेट/एनक्लोज्ड मेननेट, माइग्रेशन टारगेट्स और लंबी अवधि ANTS सेटलमेंट डिज़ाइन।',
      'page_subtitle_whitepaper':
          'मौजूदा ऑपरेटिंग मॉडल, वितरण नियम और सिस्टम डिज़ाइन पढ़ें।',
      'page_subtitle_colony':
          'अपना कॉलोनी रूम और लिंक्ड अपलाइन रूम स्पष्ट रूप से मैनेज करें।',
      'page_subtitle_more':
          'सपोर्ट, लीगल पेज, भाषा, नोटिफिकेशन और अकाउंट कंट्रोल्स।',
      'page_info_ecosystem':
          'एंट इकोसिस्टम ऑपरेशनल होम स्क्रीन है। इसमें लाइव स्टैट्स, क्विक एक्शन और मुख्य कॉलोनी टूल्स की पहुंच मिलती है ताकि सेशन शुरू करने से पहले नेटवर्क समझा जा सके।',
      'page_info_antwork':
          'एंट वर्क 6-घंटे के सत्यापित सेशन पर चलता है। एक्टिविटी पहले ANTS में ट्रैक होती है, ANET केवल आवश्यक पूर्ण-सेशन सीमा के बाद claimable होता है, और halving पूरे नेटवर्क के सत्यापित सेशन माइलस्टोन के अनुसार होती है।',
      'page_info_wallet':
          'ANET वॉलेट आपके इंटरनल ANET बैलेंस, वॉलेट सेटअप और चेन-विजिबिलिटी टूल्स को एक जगह रखता है। यही जगह Web2 सेशन एक्टिविटी, Web3 मार्केट रेफरेंस और लाइव ANET Layer 1 एक्सप्लोरर को जोड़ती है।',
      'page_info_web4':
          'Web4 बताता है कि लाइव ANET Layer 1 private/enclosed mainnet आज के Web2 Ant Work के साथ कैसे काम करता है, जबकि migration, claim flow और broader production settlement अभी चरणों में है।',
      'page_info_whitepaper':
          'व्हाइटपेपर पेज मौजूदा प्रोडक्शन नियमों का सार देता है: ANTS-first accounting, 21 मिलियन ANET कैप, 6-घंटे के सेशन, session-based halving, और केवल कॉलोनी ग्रोथ के लिए referral मॉडल - बिना coin या session bonus।',
      'page_info_colony':
          'Colony (Web5) वह जगह है जहां Ant Codes और community rooms जुड़ते हैं। उपयोगकर्ता अपना कॉलोनी रूम रख सकते हैं, लिंक होने पर upline कॉलोनी जॉइन कर सकते हैं, और दोनों उपलब्ध हों तो scope बदल सकते हैं।',
      'page_info_more':
          'More पेज ऑपरेशनल सेटिंग्स और लीगल संदर्भ को केंद्रीकृत करता है। इसे ownership security, alerts, language status, privacy, terms, support और project information के लिए उपयोग करें।',
      'total_ants': 'कुल Ants',
      'total_ants_info_body':
          'A-Network कॉलोनी में पहचान रजिस्टर करने वाले ants की कुल संख्या - यानी हर ant जिसने कभी कॉलोनी में प्रवेश किया।',
      'active_workers': 'सक्रिय कार्यकर्ता',
      'active_workers_info_body':
          'समर्पित worker ants की कुल संख्या जिन्होंने कम से कम एक पूरा work session सफलतापूर्वक पूरा किया है। इन ants ने सत्यापित 6-घंटे की शिफ्ट पूरी करके अपनी प्रतिबद्धता साबित की है।',
      'completed_work': 'काम पूरा',
      'active_territories': 'सक्रिय क्षेत्र',
      'verified_sessions': 'सत्यापित सेशन',
      'network_throughput': 'नेटवर्क थ्रूपुट',
      'live_output': 'लाइव आउटपुट',
      'markets': 'मार्केट्स',
      'completed_at_least_one_session': 'कम से कम एक सेशन पूरा',
      'open': 'खोलें',
      'live_ant_work': 'लाइव Ant Work',
      'live_ant_work_info_body':
          'यह कार्ड सक्रिय माइनिंग सेशन का त्वरित स्नैपशॉट है। इसमें आपका वर्तमान स्टेट, सेशन आउटपुट, बचा समय और जमा बैलेंस दिखता है।',
      'tracked': 'ट्रैक्ड',
      'session_output': 'सेशन आउटपुट',
      'anet_per_6h_cycle': 'प्रति 6-घंटे चक्र ANET',
      'portfolio': 'पोर्टफोलियो',
      'accumulated': 'संचित',
      'open_ant_work': 'एंट वर्क खोलें',
      'start_ant_work': 'एंट वर्क शुरू करें',
      'refresh_activity': 'एक्टिविटी रिफ्रेश',
      'ant_work_in_progress': 'एंट वर्क चल रहा है',
      'begin_your_journey': 'अपनी यात्रा शुरू करें',
      'anet_wallet': 'ANET वॉलेट',
      'wallet_tools_chain_visibility': 'बैलेंस, वॉलेट टूल्स, चेन विजिबिलिटी',
      'network_status': 'नेटवर्क स्थिति',
      'online': 'ऑनलाइन',
      'total_working_ants': 'कुल कार्यशील Ants',
      'together_future': 'मिलकर हम भविष्य बनाते हैं।',
      'starting_session': 'सेशन शुरू हो रहा है...',
      'session_active_now': 'सेशन अभी सक्रिय है',
      'ready_new_session': 'नए 6-घंटे सेशन के लिए तैयार',
      'live': 'लाइव',
      'ready': 'तैयार',
      'quick_action': 'क्विक एक्शन',
      'wallet_locked': 'वॉलेट लॉक है',
      'set_pin_continue': 'जारी रखने के लिए PIN सेट करें',
      'enter_wallet_pin_message':
          'अपना Web3 वॉलेट खोलने के लिए वॉलेट PIN दर्ज करें।',
      'set_pin_secure_message':
          'एक्सेस से पहले अपने वॉलेट की सुरक्षा के लिए PIN सेट करें।',
      'unlock_wallet': 'वॉलेट अनलॉक करें',
      'set_wallet_pin': 'वॉलेट PIN सेट करें',
      'ant_work_running': 'एंट वर्क...',
      'starting': 'शुरू हो रहा है...',
      'six_hour_session_active': '6-घंटे का सेशन सक्रिय',
      'no_active_session': 'कोई सक्रिय सेशन नहीं',
      'next_stage_unlocked': 'अगला चरण अनलॉक',
      'sessions_to_next_stage': 'सेशन अगले चरण तक',
      'standby': 'स्टैंडबाय',
      'halving_stage': 'हॉल्विंग चरण',
      'rank': 'रैंक',
      'supply_progress': 'सप्लाई प्रोग्रेस',
      'refresh': 'रिफ्रेश',
      'balance': 'बैलेंस',
      'tracked_balance': 'ट्रैक्ड बैलेंस',
      'network_scale': 'नेटवर्क स्केल',
      'next_stage': 'अगला चरण',
      'target': 'लक्ष्य',
      'session_rules': 'सेशन नियम',
      'validated_cycle_6h': '6-घंटे सत्यापित चक्र',
      'sessions_to_claim_anet': 'सेशन ANET claim के लिए',
      'rewards_tracked_ants_first':
          'रिवार्ड पहले ANTS में ट्रैक होते हैं। सेशन क्रेडिट तभी पोस्ट होता है जब सर्वर completion validate करता है।',
      'network_rules': 'नेटवर्क नियम',
      'next_output': 'अगला आउटपुट',
      'referrals_grow_colony_only':
          'रेफरल केवल कॉलोनी बढ़ाते हैं। रजिस्ट्रेशन काउंट, कॉलोनी साइज़ और वॉलेट बैलेंस halving या coin bonus नहीं बदलते।',
      'supply_ledger': 'सप्लाई लेजर',
      'global_mined': 'वैश्विक माइन',
      'total_max_supply': 'कुल अधिकतम सप्लाई',
      'wp_title': 'ए-नेटवर्क श्वेतपत्र',
      'wp_open_privacy': 'गोपनीयता नीति खोलें',
      'wp_open_terms': 'नियम खोलें',
      'col_title': 'कॉलोनी चैट | वेब5 ANET कोर',
      'col_subtitle':
          'कॉलोनी-चयनित ANT समूह, योगदान ट्रैक, मेंटरशिप, और दीर्घकालिक इकोसिस्टम निर्माण।',
      'col_worker_transfer': 'वर्कर ट्रांसफर',
      'col_copy_address': 'पता कॉपी करें',
      'col_view_seed': 'सीड देखें',
      'col_set_pin': 'PIN सेट करें',
      'col_change_pin': 'PIN बदलें',
      'col_quick_access_title': 'वेब5 त्वरित पहुंच',
      'col_colony_access_title': 'कॉलोनी एक्सेस',
      'col_migration_title': 'वेब3 में माइग्रेशन (योजनाबद्ध)',
      'col_anet_core_title': 'ANET कोर प्रोग्राम',
      'col_open_all_title': 'सभी के लिए खुला',
      'col_tracks_title': 'योगदान ट्रैक (योजनाबद्ध)',
      'col_roadmap_note':
          'रोडमैप नोट: लागू मॉडल वेब2 माइनिंग, वेब3 दृश्यता, और वेब5 सामुदायिक समन्वय है।',
      'wp_version':
          'संस्करण 1.0.5 | प्रोटोकॉल सारांश, Ant Work नियम, लेयर 1 मेननेट, गोपनीयता और नीति',
      'wp_risk_notice':
          'जोखिम सूचना: A-Network एक दीर्घकालिक तकनीकी पहल है। यह वित्तीय सलाह नहीं है और रिटर्न की गारंटी नहीं देता। पात्र miners को प्रोटोकॉल नियमों के तहत सत्यापित नेटवर्क गतिविधि से fee-based rewards मिल सकते हैं।',
      'wp_1_title': '1. मिशन',
      'wp_2_title': '2. संस्करण 1.0.5 सारांश',
      'wp_3_title': '3. तीन-परत अर्थव्यवस्था',
      'wp_4_title': '4. यूनिट मॉडल',
      'wp_5_title': '5. सेशन नियम',
      'wp_6_title': '6. वितरण इंजन',
      'wp_7_title': '7. हाल्विंग लॉजिक',
      'wp_8_title': '8. पात्रता और दावा',
      'wp_9_title': '9. आपूर्ति संरक्षण',
      'wp_10_title': '10. वैश्विक स्थिति',
      'wp_11_title': '11. वॉलेट और माइग्रेशन',
      'wp_12_title': '12. रीसेट नीति',
      'wp_13_title': '13. सुरक्षा और एंटी-एब्यूज',
      'wp_14_title': '14. गोपनीयता और जिम्मेदार उपयोग',
      'wp_15_title': '15. अनुपालन और जोखिम सूचना',
      'wp_16_title': '16. दीर्घकालिक दिशा',
      'wp_1_body':
          'एक ऐसा भागीदारी लेजर बनाना जिसमें कार्य मापा जाए, जारीकरण सीमित रहे, और Web2 गतिविधि सप्लाई नियमों को अस्पष्ट किए बिना लाइव Layer 1 सिस्टम में सेटल हो सके।',
      'wp_2_body':
          'A-Network v1.0.5 एक ANTS-first Ant Work सिस्टम है। उपयोगकर्ता सत्यापित 6-घंटे के सेशन्स पूरा करते हैं, लेजर में ANTS जमा करते हैं, और केवल 1,000 सफल सेशन्स के बाद Layer 1 claim eligibility प्राप्त करते हैं। ANET Layer 1 private/enclosed mainnet लाइव है और event-driven settlement गतिविधि रिकॉर्ड करता है।',
      'wp_3_body':
          'Web2 Off-Chain Economy: session tracking, account state, fraud control, और ANTS ledger accounting।\n\nWeb3 Visibility Economy: BNB Chain token visibility, contract transparency, और wallet reference।\n\nWeb4 Settlement Economy: live Layer 1 private/enclosed mainnet, event-driven settlement blocks, ANTS-denominated fee logic, और future migration into broader on-chain participation।',
      'wp_4_body':
          '1 ANET = 100,000,000 ANTS। ANTS सबसे छोटी accounting unit है। Session output ANET-equivalent terms में compute होता है, लेकिन precision और Layer 1 settlement support के लिए ANTS में store होता है।',
      'wp_5_body':
          'हर Ant Work session 6 घंटे का होता है। एक उपयोगकर्ता प्रतिदिन अधिकतम 4 sessions पूरा कर सकता है। Instant completion अस्वीकार किया जाता है। Audit और abuse control के लिए session start और completion timestamp किए जाते हैं।',
      'wp_6_body':
          'नेटवर्क के पहले 500,000 कुल sessions में launch output 0.04882812 ANET प्रति completed session लागू होता है। इसके बाद long-life schedule 0.00262144 ANET प्रति completed session (262,144 ANTS) से शुरू होता है, और फिर कुल नेटवर्क sessions के अनुसार halving होती है। Issuance verified work से संचालित है, referrals या user count से नहीं।',
      'wp_7_body':
          'Halving केवल total completed sessions पर आधारित है। पहले 500,000 sessions launch tranche बनाते हैं। उसके बाद Stage 9 तक हर अतिरिक्त 3,800,000,000 sessions पर session output आधा होता है।',
      'wp_8_body':
          'एक miner 1,000 सफल sessions के बाद ANTS को ANET में convert करने के लिए eligible होता है। इस threshold से पहले ANTS लेजर में रिकॉर्ड रहता है, पर ANET के रूप में claimable नहीं होता।',
      'wp_9_body':
          'Backend conversion के समय 21,000,000 cap लागू करता है। यदि कोई claim cap पार करता है, तो उसे exact remaining supply तक घटा दिया जाता है और negative output नहीं बनता।',
      'wp_10_body':
          'Production API analytics और client display के लिए global state देती है: total users, total sessions, active miners, eligible users, converted users, total ANTS accumulated, total ANET claimed, current distribution stage, और halving progress।',
      'wp_11_body':
          'हर account ANET wallet identity बना सकता है और वैकल्पिक रूप से अलग migration wallet सेट कर सकता है। Wallet continuity में PIN protection, OTP-gated seed reveal, और migration progress tracking शामिल है।',
      'wp_12_body':
          'Reset model Ant Work state को clear कर सकता है जबकि accounts और wallet addresses सुरक्षित रखता है। User sessions, ANTS balances, claimed ANET, eligibility flags, और global counters zero पर लौटते हैं, identity records delete नहीं होते।',
      'wp_13_body':
          'सुरक्षा में OTP email verification, trusted-device checks, session-bound JWTs, device limits, एक समय में एक active session, daily session caps, heartbeat validation, risk scoring, flagged accounts के लिए gated claims, और security audit logs शामिल हैं।',
      'wp_14_body':
          'सिस्टम सेवा संचालन, fraud prevention और compliance support के लिए आवश्यक credentials, contact data, device signals, wallet links और activity records एकत्र करता है। Botting, abuse, और exploit behavior प्रतिबंधित है।',
      'wp_15_body':
          'A-Network एक technology project है, financial advice नहीं, और returns की गारंटी नहीं देता। Ant Work output, ANTS balances, ANET conversion, notifications, wallet recovery, controlled distributions, और fee-based miner rewards वर्तमान backend rules और future governance/security review के अधीन हैं।',
      'wp_16_body':
          'रोडमैप Web2 participation -> Web3 visibility -> live Web4 private/enclosed mainnet settlement -> ANET Core बना रहता है। तत्काल प्राथमिकता ledger stability, mainnet reliability, और audited migration/claim paths है।',
      'col_quick_access_body':
          'Worker Transfer का उपयोग करके dApp browser में prefilled wallet के साथ केवल live Layer 1 transfer form खोलें। Copy Address, View Seed, और Change PIN यहां भी उपलब्ध हैं ताकि सामान्य wallet-security actions के लिए Web4 पर वापस न जाना पड़े।',
      'col_colony_access_body':
          'हर account owner के लिए एक designated colony room होता है। Owner preset options में से colony name चुनता है, और direct colony ants को server उसी room में route करता है। Ads chat panel के अंदर रहते हैं।',
      'col_migration_body':
          'Web3 public contract visibility, partner participation, और future buyer-based onboarding के लिए अलग operating layer बना रहता है। यह वर्तमान build में Web2 mining accounting या colony scoring को redefine नहीं करता।',
      'col_anet_core_body':
          'ANET Core भविष्य की Web5 दिशा है। Group colonies आगे चलकर इस layer का हिस्सा बन सकती हैं, जहां community identity, ANET-Chain के माध्यम से public blockchain visibility, और broader coordination roles समय के साथ विकसित होंगे।',
      'col_open_all_body':
          'Coding experience स्वागतयोग्य है लेकिन अनिवार्य नहीं। A-Network mentoring, practical tasks, और structured learning tracks के माध्यम से contributors को support कर सकता है।',
      'col_tracks_body':
          'संभावित tracks में education support, community operations, testing, documentation, research, design, product feedback, और engineering collaboration शामिल हैं।',
    };
    const ur = <String, String>{
      'mainnet_wallet': 'مین نیٹ والیٹ',
      'home': 'ہوم',
      'assets': 'اثاثے',
      'activity': 'سرگرمی',
      'sessions': 'سیشنز',
      'add_token': 'ٹوکن شامل کریں',
      'total_balance': 'کل بیلنس',
      'send': 'بھیجیں',
      'receive': 'وصول کریں',
      'explorer': 'ایکسپلورر',
      'bridge': 'برج',
      'mining_profile': 'مائننگ پروفائل',
      'joined': 'شمولیت',
      'completed_sessions': 'مکمل سیشنز',
      'anet_balance': 'ANET بیلنس',
      'current_rate': 'موجودہ ریٹ',
      'colony_joined': 'کالونی میں شمولیت',
      'not_in_colony': 'کسی کالونی میں نہیں',
      'session_history': 'سیشن ہسٹری',
      'credited': 'کریڈٹڈ',
      'in_progress': 'جاری ہے',
      'language': 'زبان',
      'language_help':
          'اپنی ایپ زبان منتخب کریں۔ آٹو موڈ علاقے کے مطابق ڈیفالٹ سیٹ کرتا ہے: بھارت -> ہندی، پاکستان -> اردو، چین -> چینی، اسپین/لاطینی امریکہ -> ہسپانوی، ویتنام -> ویتنامی، دیگر علاقوں کے لیے انگریزی۔',
      'language_set_to': 'زبان سیٹ ہو گئی',
      'close': 'بند کریں',
      'start': 'شروع',
      'end': 'اختتام',
      'halving_level': 'ہالوِنگ لیول',
      'load_older_sessions': 'پرانے سیشنز لوڈ کریں',
      'loading_older_sessions': 'پرانے سیشنز لوڈ ہو رہے ہیں...',
      'ann_halving_title': 'HALVING شروع ہو چکی ہے',
      'ann_halving_body':
          'نیٹ ورک 500,000 سیشن سنگِ میل تک پہنچ گیا ہے۔ پہلی halving اب نافذ ہے۔',
      'ann_halving_note':
          'نئی ریٹ لاگو ہونے سے پہلے 6 گھنٹے کی validation تاخیر ہے۔ سسٹم پہلے تمام pending sessions کو validate کرتا ہے۔ 500k سنگِ میل confirm ہوتے ہی Live Output خودکار طور پر نئی ریٹ پر اپڈیٹ ہوگا۔',
      'ann_halving_safe':
          'کوئی action درکار نہیں - جاری سیشنز محفوظ ہیں اور درست ریٹ پر credit ہوں گے۔',
      'ann_x_title': 'LATEST X UPDATE',
      'ann_x_body':
          'Mr_A_Awakening پر A-Network کی تازہ ترین آفیشل پوسٹس دیکھیں۔',
      'ann_x_note':
          'یہ سلائیڈ halving اپڈیٹ کارڈ کے ساتھ ہر 60 سیکنڈ میں خودکار طور پر گھومتی ہے۔',
      'ann_x_cta': 'تازہ ترین X اپڈیٹس کھولیں',
      'page_subtitle_ecosystem':
          'لائیو نیٹ ورک ویو، ایکوسسٹم ایکشنز، اور کالونی گروتھ ٹولز۔',
      'page_subtitle_antwork':
          '6 گھنٹے کے Ant Work سیشن چلائیں اور تصدیق شدہ سرگرمی سنگ میل ٹریک کریں۔',
      'page_subtitle_wallet':
          'ایک ہی جگہ بیلنس، والیٹ ٹولز، اور لائیو Layer 1 مرئیت دیکھیں۔',
      'page_subtitle_web4':
          'لائیو Layer 1 private/enclosed mainnet، migration targets، اور طویل مدتی ANTS settlement design۔',
      'page_subtitle_whitepaper':
          'موجودہ آپریٹنگ ماڈل، تقسیم کے قواعد، اور سسٹم ڈیزائن پڑھیں۔',
      'page_subtitle_colony':
          'اپنا colony room اور linked upline room واضح طور پر منیج کریں۔',
      'page_subtitle_more':
          'سپورٹ، قانونی صفحات، زبان، نوٹیفیکیشنز، اور اکاؤنٹ کنٹرولز۔',
      'page_info_ecosystem':
          'Ant Ecosystem آپریشنل ہوم اسکرین ہے۔ یہ لائیو اسٹیٹس، فوری ایکشنز، اور مرکزی کالونی ٹولز کو یکجا کرتا ہے تاکہ سیشن شروع کرنے سے پہلے نیٹ ورک واضح ہو۔',
      'page_info_antwork':
          'Ant Work تصدیق شدہ 6 گھنٹے سیشنز پر چلتا ہے۔ سرگرمی پہلے ANTS میں ٹریک ہوتی ہے، ANET صرف مطلوبہ مکمل سیشنز کے بعد claimable ہوتا ہے، اور halving پورے نیٹ ورک کے verified milestones کے مطابق ہوتی ہے۔',
      'page_info_wallet':
          'ANET Wallet آپ کے اندرونی ANET بیلنس، wallet setup، اور chain-facing visibility tools کو یکجا کرتا ہے۔',
      'page_info_web4':
          'Web4 بتاتا ہے کہ لائیو ANET Layer 1 private/enclosed mainnet آج Web2 Ant Work کے ساتھ کیسے کام کرتا ہے جبکہ migration اور claim flow مرحلہ وار جاری ہیں۔',
      'page_info_whitepaper':
          'Whitepaper موجودہ production rules کا خلاصہ دیتا ہے: ANTS-first accounting، 21 million ANET cap، 6-hour sessions، session-based halving، اور referrals صرف colony growth کے لیے۔',
      'page_info_colony':
          'Colony (Web5) وہ جگہ ہے جہاں Ant Codes اور community rooms جڑتے ہیں۔',
      'page_info_more':
          'More آپریشنل settings اور قانونی context کو ایک جگہ رکھتا ہے۔',
      'total_ants': 'کل Ants',
      'total_ants_info_body':
          'A-Network colony میں شناخت رجسٹر کرنے والے تمام ants کی مجموعی تعداد۔',
      'active_workers': 'فعال کارکن',
      'active_workers_info_body':
          'ان worker ants کی تعداد جنہوں نے کم از کم ایک مکمل تصدیق شدہ 6 گھنٹے سیشن پورا کیا ہو۔',
      'completed_work': 'مکمل کام',
      'active_territories': 'فعال علاقے',
      'verified_sessions': 'تصدیق شدہ سیشنز',
      'network_throughput': 'نیٹ ورک throughput',
      'live_output': 'لائیو آؤٹ پٹ',
      'markets': 'مارکیٹس',
      'completed_at_least_one_session': 'کم از کم ایک سیشن مکمل',
      'open': 'کھولیں',
      'live_ant_work': 'لائیو Ant Work',
      'live_ant_work_info_body':
          'یہ کارڈ فعال mining session کا فوری خلاصہ ہے: state، session output، باقی وقت، اور accumulated balance۔',
      'tracked': 'ٹریک شدہ',
      'session_output': 'سیشن آؤٹ پٹ',
      'anet_per_6h_cycle': 'ہر 6 گھنٹے سائیکل پر ANET',
      'portfolio': 'پورٹ فولیو',
      'accumulated': 'جمع شدہ',
      'open_ant_work': 'Ant Work کھولیں',
      'start_ant_work': 'Ant Work شروع کریں',
      'refresh_activity': 'سرگرمی ریفریش کریں',
      'ant_work_in_progress': 'Ant Work جاری ہے',
      'begin_your_journey': 'اپنا سفر شروع کریں',
      'anet_wallet': 'ANET Wallet',
      'wallet_tools_chain_visibility': 'بیلنس، wallet tools، chain visibility',
      'network_status': 'نیٹ ورک اسٹیٹس',
      'online': 'آن لائن',
      'total_working_ants': 'کل فعال Ants',
      'together_future': 'مل کر ہم مستقبل بناتے ہیں۔',
      'starting_session': 'سیشن شروع ہو رہا ہے...',
      'session_active_now': 'سیشن اب فعال ہے',
      'ready_new_session': 'نئے 6 گھنٹے سیشن کے لیے تیار',
      'live': 'لائیو',
      'ready': 'تیار',
      'quick_action': 'فوری ایکشن',
      'wallet_locked': 'والیٹ لاک ہے',
      'set_pin_continue': 'جاری رکھنے کے لیے PIN سیٹ کریں',
      'enter_wallet_pin_message':
          'اپنے Web3 wallet تک رسائی کے لیے wallet PIN درج کریں۔',
      'set_pin_secure_message':
          'رسائی سے پہلے wallet کو محفوظ کرنے کے لیے PIN سیٹ کریں۔',
      'unlock_wallet': 'والیٹ ان لاک کریں',
      'set_wallet_pin': 'والیٹ PIN سیٹ کریں',
      'ant_work_running': 'Ant Work...',
      'starting': 'شروع ہو رہا ہے...',
      'six_hour_session_active': '6 گھنٹے سیشن فعال',
      'no_active_session': 'کوئی فعال سیشن نہیں',
      'next_stage_unlocked': 'اگلا مرحلہ ان لاک',
      'sessions_to_next_stage': 'اگلے مرحلے تک سیشنز',
      'standby': 'اسٹینڈ بائی',
      'halving_stage': 'halving مرحلہ',
      'rank': 'درجہ',
      'supply_progress': 'سپلائی پیش رفت',
      'refresh': 'ریفریش',
      'balance': 'بیلنس',
      'tracked_balance': 'ٹریک شدہ بیلنس',
      'network_scale': 'نیٹ ورک اسکیل',
      'next_stage': 'اگلا مرحلہ',
      'target': 'ہدف',
      'session_rules': 'سیشن قواعد',
      'validated_cycle_6h': '6 گھنٹے validated cycle',
      'sessions_to_claim_anet': 'ANET claim کے لیے سیشنز',
      'rewards_tracked_ants_first':
          'انعامات پہلے ANTS میں ٹریک ہوتے ہیں۔ session credit سرور validation کے بعد پوسٹ ہوتا ہے۔',
      'network_rules': 'نیٹ ورک قواعد',
      'next_output': 'اگلا آؤٹ پٹ',
      'referrals_grow_colony_only':
          'referrals صرف colony بڑھاتے ہیں۔ registration count، colony size، اور wallet balance halving یا coin bonus نہیں بناتے۔',
      'supply_ledger': 'سپلائی لیجر',
      'global_mined': 'عالمی mined',
      'total_max_supply': 'کل زیادہ سے زیادہ سپلائی',
      'wp_title': 'اے-نیٹ ورک وائٹ پیپر',
      'wp_open_privacy': 'پرائیویسی پالیسی کھولیں',
      'wp_open_terms': 'شرائط کھولیں',
      'col_title': 'کالونی چیٹ | ویب5 ANET کور',
      'col_subtitle':
          'کالونی-منتخب ANT گروپس، شراکت ٹریکس، رہنمائی، اور طویل مدتی ایکوسسٹم تعمیر۔',
      'col_worker_transfer': 'ورکر ٹرانسفر',
      'col_copy_address': 'ایڈریس کاپی کریں',
      'col_view_seed': 'سیڈ دیکھیں',
      'col_set_pin': 'PIN سیٹ کریں',
      'col_change_pin': 'PIN تبدیل کریں',
      'col_quick_access_title': 'ویب5 فوری رسائی',
      'col_colony_access_title': 'کالونی رسائی',
      'col_migration_title': 'ویب3 میں منتقلی (منصوبہ)',
      'col_anet_core_title': 'ANET کور پروگرام',
      'col_open_all_title': 'سب کے لیے کھلا',
      'col_tracks_title': 'شراکت ٹریکس (منصوبہ)',
      'col_roadmap_note':
          'روڈ میپ نوٹ: نافذ ماڈل ویب2 مائننگ، ویب3 مرئیت، اور ویب5 کمیونٹی کوآرڈینیشن ہے۔',
      'wp_version':
          'ورژن 1.0.5 | پروٹوکول خلاصہ، Ant Work قوانین، لیئر 1 مین نیٹ، رازداری اور پالیسی',
      'wp_risk_notice':
          'خطرے کا نوٹس: A-Network ایک طویل مدتی تکنیکی اقدام ہے۔ یہ مالی مشورہ نہیں اور منافع کی ضمانت نہیں دیتا۔ اہل miners کو پروٹوکول قواعد کے تحت تصدیق شدہ نیٹ ورک سرگرمی سے fee-based rewards مل سکتے ہیں۔',
      'wp_1_title': '1. مشن',
      'wp_2_title': '2. ورژن 1.0.5 خلاصہ',
      'wp_3_title': '3. تین پرتی معیشت',
      'wp_4_title': '4. یونٹ ماڈل',
      'wp_5_title': '5. سیشن قوانین',
      'wp_6_title': '6. تقسیم انجن',
      'wp_7_title': '7. ہالوِنگ منطق',
      'wp_8_title': '8. اہلیت اور دعوی',
      'wp_9_title': '9. سپلائی تحفظ',
      'wp_10_title': '10. عالمی حالت',
      'wp_11_title': '11. والیٹ اور منتقلی',
      'wp_12_title': '12. ری سیٹ پالیسی',
      'wp_13_title': '13. سیکیورٹی اور اینٹی-ابیوز',
      'wp_14_title': '14. رازداری اور ذمہ دارانہ استعمال',
      'wp_15_title': '15. تعمیل اور خطرے کا نوٹس',
      'wp_16_title': '16. طویل مدتی سمت',
      'wp_1_body':
          'ایک ایسا شرکتی لیجر بنانا جس میں کام ناپا جائے، اجرا محدود ہو، اور Web2 سرگرمی سپلائی قواعد کو چھپائے بغیر live Layer 1 نظام میں سیٹل ہو سکے۔',
      'wp_2_body':
          'A-Network v1.0.5 ایک ANTS-first Ant Work نظام ہے۔ صارفین تصدیق شدہ 6 گھنٹے کے سیشن مکمل کرتے ہیں، لیجر میں ANTS جمع کرتے ہیں، اور صرف 1,000 کامیاب سیشنز کے بعد Layer 1 claim eligibility حاصل کرتے ہیں۔ ANET Layer 1 private/enclosed mainnet live ہے اور event-driven settlement سرگرمی ریکارڈ کرتا ہے۔',
      'wp_3_body':
          'Web2 Off-Chain Economy: session tracking، account state، fraud control، اور ANTS ledger accounting۔\n\nWeb3 Visibility Economy: BNB Chain token visibility، contract transparency، اور wallet reference۔\n\nWeb4 Settlement Economy: live Layer 1 private/enclosed mainnet، event-driven settlement blocks، ANTS-denominated fee logic، اور future migration into broader on-chain participation۔',
      'wp_4_body':
          '1 ANET = 100,000,000 ANTS۔ ANTS سب سے چھوٹی accounting unit ہے۔ Session output ANET-equivalent terms میں compute ہوتا ہے، لیکن precision اور Layer 1 settlement support کے لیے ANTS میں store کیا جاتا ہے۔',
      'wp_5_body':
          'ہر Ant Work session 6 گھنٹے کا ہوتا ہے۔ ایک صارف روزانہ زیادہ سے زیادہ 4 sessions مکمل کر سکتا ہے۔ Instant completion مسترد کر دی جاتی ہے۔ Audit اور abuse control کے لیے session start اور completion پر timestamp لگایا جاتا ہے۔',
      'wp_6_body':
          'نیٹ ورک کے پہلے 500,000 total sessions میں launch output 0.04882812 ANET فی completed session ہے۔ اس کے بعد long-life schedule 0.00262144 ANET فی completed session (262,144 ANTS) سے شروع ہوتا ہے اور پھر total network sessions کے مطابق halving ہوتی ہے۔ Issuance verified work سے چلتی ہے، referrals یا user count سے نہیں۔',
      'wp_7_body':
          'Halving صرف total completed sessions پر مبنی ہے۔ پہلے 500,000 sessions launch tranche بناتے ہیں۔ اس کے بعد Stage 9 تک ہر اضافی 3,800,000,000 sessions پر session output آدھا ہو جاتا ہے۔',
      'wp_8_body':
          'ایک miner 1,000 کامیاب sessions کے بعد ANTS کو ANET میں convert کرنے کے لیے eligible ہوتا ہے۔ اس حد سے پہلے ANTS لیجر میں ریکارڈ رہتا ہے لیکن ANET کے طور پر claimable نہیں ہوتا۔',
      'wp_9_body':
          'Backend conversion کے وقت 21,000,000 cap نافذ کرتا ہے۔ اگر کوئی claim cap سے اوپر جائے تو اسے بالکل باقی supply تک کم کر دیا جاتا ہے اور negative output پیدا نہیں ہوتا۔',
      'wp_10_body':
          'Production API analytics اور client display کے لیے global state دیتی ہے: total users، total sessions، active miners، eligible users، converted users، total ANTS accumulated، total ANET claimed، current distribution stage، اور halving progress۔',
      'wp_11_body':
          'ہر account ANET wallet identity بنا سکتا ہے اور optional طور پر الگ migration wallet set کر سکتا ہے۔ Wallet continuity میں PIN protection، OTP-gated seed reveal، اور migration progress tracking شامل ہے۔',
      'wp_12_body':
          'Reset model Ant Work state کو clear کر سکتا ہے جبکہ accounts اور wallet addresses محفوظ رہتے ہیں۔ User sessions، ANTS balances، claimed ANET، eligibility flags، اور global counters zero پر واپس آتے ہیں، identity records delete نہیں ہوتے۔',
      'wp_13_body':
          'تحفظ میں OTP email verification، trusted-device checks، session-bound JWTs، device limits، ایک وقت میں ایک active session، daily session caps، heartbeat validation، risk scoring، flagged accounts کے لیے gated claims، اور security audit logs شامل ہیں۔',
      'wp_14_body':
          'نظام سروس چلانے، fraud روکنے، اور compliance سپورٹ کے لیے ضروری credentials، contact data، device signals، wallet links، اور activity records جمع کرتا ہے۔ Botting، abuse، اور exploit behavior ممنوع ہیں۔',
      'wp_15_body':
          'A-Network ایک technology project ہے، مالی مشورہ نہیں، اور returns کی ضمانت نہیں دیتا۔ Ant Work output، ANTS balances، ANET conversion، notifications، wallet recovery، controlled distributions، اور fee-based miner rewards موجودہ backend rules اور مستقبل کی governance/security review کے تابع ہیں۔',
      'wp_16_body':
          'روڈمیپ Web2 participation -> Web3 visibility -> live Web4 private/enclosed mainnet settlement -> ANET Core رہتا ہے۔ فوری ترجیح ledger stability، mainnet reliability، اور audited migration/claim paths ہے۔',
      'col_quick_access_body':
          'Worker Transfer استعمال کر کے dApp browser میں prefilled wallet کے ساتھ صرف live Layer 1 transfer form کھولیں۔ Copy Address، View Seed، اور Change PIN یہاں بھی دستیاب ہیں تاکہ عام wallet-security actions کے لیے Web4 پر واپس نہ جانا پڑے۔',
      'col_colony_access_body':
          'ہر account owner کے لیے ایک designated colony room ہوتا ہے۔ Owner preset options میں سے colony name منتخب کرتا ہے، اور direct colony ants کو server اسی room میں route کرتا ہے۔ Ads chat panel کے اندر رہتے ہیں۔',
      'col_migration_body':
          'Web3 public contract visibility، partner participation، اور future buyer-based onboarding کے لیے الگ operating layer رہتا ہے۔ یہ موجودہ build میں Web2 mining accounting یا colony scoring کو redefine نہیں کرتا۔',
      'col_anet_core_body':
          'ANET Core مستقبل کی Web5 سمت ہے۔ Group colonies بعد میں اس layer کا حصہ بن سکتی ہیں، جہاں community identity، ANET-Chain کے ذریعے public blockchain visibility، اور broader coordination roles وقت کے ساتھ تیار ہوں گے۔',
      'col_open_all_body':
          'Coding experience خوش آئند ہے مگر لازمی نہیں۔ A-Network mentoring، practical tasks، اور structured learning tracks کے ذریعے contributors کو support کر سکتا ہے۔',
      'col_tracks_body':
          'ممکنہ tracks میں education support، community operations، testing، documentation، research، design، product feedback، اور engineering collaboration شامل ہیں۔',
    };
    const zh = <String, String>{
      'mainnet_wallet': '主网钱包',
      'home': '首页',
      'assets': '资产',
      'activity': '活动',
      'sessions': '会话',
      'add_token': '添加代币',
      'total_balance': '总余额',
      'send': '发送',
      'receive': '接收',
      'explorer': '浏览器',
      'bridge': '跨链',
      'mining_profile': '挖矿资料',
      'joined': '加入时间',
      'completed_sessions': '完成会话',
      'anet_balance': 'ANET 余额',
      'current_rate': '当前速率',
      'colony_joined': '加入社群',
      'not_in_colony': '未加入社群',
      'session_history': '会话记录',
      'credited': '已入账',
      'in_progress': '进行中',
      'language': '语言',
      'language_help':
          '选择应用语言。自动模式按地区默认映射: 印度 -> 印地语, 巴基斯坦 -> 乌尔都语, 中国 -> 中文, 西班牙/拉美 -> 西班牙语, 越南 -> 越南语, 其他地区回退英语。',
      'language_set_to': '语言已设置为',
      'close': '关闭',
      'start': '开始',
      'end': '结束',
      'halving_level': '减半等级',
      'load_older_sessions': '加载更早会话',
      'loading_older_sessions': '正在加载更早会话...',
      'ann_halving_title': 'HALVING 已开始',
      'ann_halving_body': '网络已达到 500,000 会话里程碑。第一次减半现已生效。',
      'ann_halving_note':
          '新费率生效前有 6 小时验证延迟。系统会先验证所有待处理会话。500k 里程碑确认后，你的 Live Output 将自动更新为新的减半费率。',
      'ann_halving_safe': '无需操作 - 进行中的会话是安全的，并将按正确费率入账。',
      'ann_x_title': 'LATEST X UPDATE',
      'ann_x_body': '在 Mr_A_Awakening 查看 A-Network 最新官方动态。',
      'ann_x_note': '该轮播每 60 秒与减半更新卡片自动切换一次。',
      'ann_x_cta': '打开最新 X 动态',
      'page_subtitle_ecosystem': '实时网络视图、生态操作与社群增长工具。',
      'page_subtitle_antwork': '运行 6 小时 Ant Work 会话并跟踪已验证活动里程碑。',
      'page_subtitle_wallet': '在一处查看余额、钱包工具和实时 Layer 1 可见性。',
      'page_subtitle_web4': '实时 Layer 1 私有/封闭主网、迁移目标与长期 ANTS 结算设计。',
      'page_subtitle_whitepaper': '阅读当前运行模型、分发规则和系统设计。',
      'page_subtitle_colony': '清晰管理你的社群房间及关联上级房间。',
      'page_subtitle_more': '支持、法律页面、语言、通知与账户控制。',
      'page_info_ecosystem':
          'Ant Ecosystem 是运营主页，整合实时统计、快捷操作和主要社群工具，帮助你在开始会话前了解网络状态。',
      'page_info_antwork':
          'Ant Work 以 6 小时验证会话运行。活动先记录为 ANTS，ANET 仅在达到要求会话数后可申领，减半按全网验证会话里程碑执行。',
      'page_info_wallet': 'ANET Wallet 汇集内部 ANET 余额、钱包设置和链上可见性工具。',
      'page_info_web4':
          'Web4 说明实时 ANET Layer 1 私有/封闭主网如何与当前 Web2 Ant Work 协同，迁移与申领流程仍在分阶段推进。',
      'page_info_whitepaper':
          '白皮书页面概述当前规则：ANTS-first 记账、2100 万 ANET 上限、6 小时会话、按会话减半，以及仅用于社群增长的推荐模型。',
      'page_info_colony': 'Colony（Web5）连接 Ant Codes 与社群房间。',
      'page_info_more': 'More 集中展示运营设置与法律信息。',
      'total_ants': '总蚂蚁数',
      'total_ants_info_body': '在 A-Network 社群中登记身份的蚂蚁总数。',
      'active_workers': '活跃工蚁',
      'active_workers_info_body': '至少完成一次完整且验证通过的 6 小时会话的工蚁总数。',
      'completed_work': '已完成工作',
      'active_territories': '活跃区域',
      'verified_sessions': '已验证会话',
      'network_throughput': '网络吞吐',
      'live_output': '实时产出',
      'markets': '市场',
      'completed_at_least_one_session': '至少完成一轮会话',
      'open': '打开',
      'live_ant_work': '实时 Ant Work',
      'live_ant_work_info_body': '此卡片显示当前挖矿会话快照：状态、会话产出、剩余时间和累计余额。',
      'tracked': '已跟踪',
      'session_output': '会话产出',
      'anet_per_6h_cycle': '每 6 小时周期 ANET',
      'portfolio': '资产组合',
      'accumulated': '累计',
      'open_ant_work': '打开 Ant Work',
      'start_ant_work': '开始 Ant Work',
      'refresh_activity': '刷新活动',
      'ant_work_in_progress': 'Ant Work 进行中',
      'begin_your_journey': '开始你的旅程',
      'anet_wallet': 'ANET 钱包',
      'wallet_tools_chain_visibility': '余额、钱包工具、链上可见性',
      'network_status': '网络状态',
      'online': '在线',
      'total_working_ants': '工作中蚂蚁总数',
      'together_future': '携手共建未来。',
      'starting_session': '正在开始会话...',
      'session_active_now': '会话当前活跃',
      'ready_new_session': '已准备好新的 6 小时会话',
      'live': '实时',
      'ready': '就绪',
      'quick_action': '快捷操作',
      'wallet_locked': '钱包已锁定',
      'set_pin_continue': '设置 PIN 以继续',
      'enter_wallet_pin_message': '输入你的钱包 PIN 以访问 Web3 钱包。',
      'set_pin_secure_message': '访问前请先设置 PIN 保护你的钱包。',
      'unlock_wallet': '解锁钱包',
      'set_wallet_pin': '设置钱包 PIN',
      'ant_work_running': 'Ant Work 运行中...',
      'starting': '正在启动...',
      'six_hour_session_active': '6 小时会话已激活',
      'no_active_session': '当前无活跃会话',
      'next_stage_unlocked': '下一阶段已解锁',
      'sessions_to_next_stage': '距下一阶段的会话数',
      'standby': '待机',
      'halving_stage': '减半阶段',
      'rank': '排名',
      'supply_progress': '供应进度',
      'refresh': '刷新',
      'balance': '余额',
      'tracked_balance': '跟踪余额',
      'network_scale': '网络规模',
      'next_stage': '下一阶段',
      'target': '目标',
      'session_rules': '会话规则',
      'validated_cycle_6h': '6 小时验证周期',
      'sessions_to_claim_anet': '可申领 ANET 所需会话',
      'rewards_tracked_ants_first': '奖励先记录为 ANTS。会话奖励会在服务器验证完成后入账。',
      'network_rules': '网络规则',
      'next_output': '下一产出',
      'referrals_grow_colony_only': '推荐仅用于社群增长。注册数、社群规模和钱包余额不会影响减半或产生币奖励。',
      'supply_ledger': '供应账本',
      'global_mined': '全网已挖',
      'total_max_supply': '最大总供应',
      'wp_title': 'A-网络白皮书',
      'wp_open_privacy': '打开隐私政策',
      'wp_open_terms': '打开条款',
      'col_title': '社群聊天 | Web5 ANET核心',
      'col_subtitle': '社群选定的蚂蚁小组、贡献轨道、导师制度和长期生态建设。',
      'col_worker_transfer': '工人转账',
      'col_copy_address': '复制地址',
      'col_view_seed': '查看助记词',
      'col_set_pin': '设置PIN',
      'col_change_pin': '更改PIN',
      'col_quick_access_title': 'Web5快速入口',
      'col_colony_access_title': '社群访问',
      'col_migration_title': '迁移至Web3（计划中）',
      'col_anet_core_title': 'ANET核心计划',
      'col_open_all_title': '对所有人开放',
      'col_tracks_title': '贡献轨道（计划中）',
      'col_roadmap_note': '路线图说明：强制执行的模型是Web2挖矿、Web3可见性和Web5社群协调。',
      'wp_version': '版本 1.0.5 | 协议摘要、Ant Work规则、第1层私有/封闭主网、隐私和政策',
      'wp_risk_notice':
          '风险提示：A-Network 是长期技术项目，不构成财务建议，也不保证回报。符合条件的矿工可在协议规则下，根据已验证网络活动获得基于手续费的生态奖励。',
      'wp_1_title': '1. 使命',
      'wp_2_title': '2. 版本1.0.5摘要',
      'wp_3_title': '3. 三层经济',
      'wp_4_title': '4. 单位模型',
      'wp_5_title': '5. 会话规则',
      'wp_6_title': '6. 分配引擎',
      'wp_7_title': '7. 减半逻辑',
      'wp_8_title': '8. 资格与申领',
      'wp_9_title': '9. 供应保护',
      'wp_10_title': '10. 全局状态',
      'wp_11_title': '11. 钱包与迁移',
      'wp_12_title': '12. 重置政策',
      'wp_13_title': '13. 安全与反滥用',
      'wp_14_title': '14. 隐私与负责任使用',
      'wp_15_title': '15. 合规与风险提示',
      'wp_16_title': '16. 长期方向',
      'wp_1_body':
          '构建一个参与账本，使工作可计量、发行有边界，并让 Web2 活动在不模糊供应规则的前提下结算到实时 Layer 1 系统中。',
      'wp_2_body':
          'A-Network v1.0.5 是一个 ANTS-first 的 Ant Work 系统。用户完成经过验证的 6 小时会话，在账本中累积 ANTS，并且仅在达到 1,000 次成功会话后获得 Layer 1 申领资格。ANET Layer 1 私有/封闭主网已上线并记录事件驱动的结算活动。',
      'wp_3_body':
          'Web2 链下经济：会话跟踪、账户状态、反欺诈控制和 ANTS 账本记账。\n\nWeb3 可见性经济：BNB Chain 代币可见性、合约透明度和钱包引用。\n\nWeb4 结算经济：实时 Layer 1 私有/封闭主网、事件驱动结算区块、以 ANTS 计价的费用逻辑，以及未来迁移到更广泛链上参与。',
      'wp_4_body':
          '1 ANET = 100,000,000 ANTS。ANTS 是最小记账单位。会话产出以 ANET 等价计算，但以 ANTS 存储，以保持精度并支持 Layer 1 结算。',
      'wp_5_body':
          '每个 Ant Work 会话持续 6 小时。每位用户每天最多完成 4 个会话。即时完成会被拒绝。会话开始与完成都会打时间戳用于审计和反滥用控制。',
      'wp_6_body':
          '全网前 500,000 次会话采用启动产出：每个完成会话 0.04882812 ANET。该阶段后，长期计划从每个完成会话 0.00262144 ANET（记账为 262,144 ANTS）开始，并按全网总会话数减半。发行由已验证工作驱动，而非邀请或用户数量。',
      'wp_7_body':
          '减半仅基于已完成会话总数。前 500,000 次会话构成启动阶段。之后直到第 9 阶段，每增加 3,800,000,000 次会话，会话产出减半。',
      'wp_8_body':
          '矿工在完成 1,000 次成功会话后，才有资格将 ANTS 转换为 ANET。在此阈值之前，ANTS 仅记录在账本中，不能作为 ANET 申领。',
      'wp_9_body':
          '后端在转换时强制执行 21,000,000 上限。若某次申领会超过上限，则会被下调到精确剩余供应量，且不会产生负产出。',
      'wp_10_body':
          '生产 API 为分析和客户端展示提供全局状态：总用户数、总会话数、活跃矿工、可申领用户、已转换用户、累计 ANTS、已申领 ANET、当前分发阶段和减半进度。',
      'wp_11_body':
          '每个账户都可创建 ANET 钱包身份，并可选设置独立迁移钱包。钱包连续性包括 PIN 保护、OTP 门控助记词查看和迁移进度跟踪。',
      'wp_12_body':
          '重置模型可清除 Ant Work 状态，同时保留账户和钱包地址。用户会话、ANTS 余额、已申领 ANET、资格标记和全局计数器都会归零，但不会删除身份记录。',
      'wp_13_body':
          '安全措施包括：OTP 邮箱验证、可信设备检查、会话绑定 JWT、设备数量限制、同一时间仅一个活跃会话、每日会话上限、心跳校验、风险评分、对高风险账户的门控申领和安全审计日志。',
      'wp_14_body':
          '系统会收集运行服务、反欺诈和合规所需的凭据、联系方式、设备信号、钱包关联和活动记录。禁止机器人行为、滥用和利用漏洞。',
      'wp_15_body':
          'A-Network 是技术项目，不构成财务建议，也不保证收益。Ant Work 产出、ANTS 余额、ANET 转换、通知、钱包恢复、受控分发以及基于手续费的矿工奖励，均受当前后端规则及未来治理/安全审查约束。',
      'wp_16_body':
          '路线图保持为：Web2 参与 -> Web3 可见性 -> Web4 私有/封闭主网实时结算 -> ANET Core。当前优先级是账本稳定性、主网可靠性，以及面向更广泛发布的可审计迁移与申领路径。',
      'col_quick_access_body':
          '使用 Worker Transfer 可在 dApp 浏览器中直接打开已预填钱包的实时 Layer 1 转账表单。这里还提供复制地址、查看助记词和修改 PIN，无需为常见钱包安全操作返回 Web4 页面。',
      'col_colony_access_body':
          '每个账户拥有者都有一个指定社群房间。拥有者可从预设选项中选择社群名称，直接社群成员会由服务器路由到同名房间。广告保持在聊天面板内显示。',
      'col_migration_body':
          'Web3 仍是独立运行层，用于公开合约可见性、合作伙伴参与和后续买家导向接入。它不会在当前版本中重定义 Web2 挖矿记账或社群评分。',
      'col_anet_core_body':
          'ANET Core 是未来 Web5 方向。群组社群未来可纳入该层，社区身份、通过 ANET-Chain 的公开链可见性和更广泛协同角色将共同演进。',
      'col_open_all_body':
          '欢迎具备编程经验者参与，但并非必须。A-Network 可通过导师机制、实践任务和结构化学习路径支持贡献者。',
      'col_tracks_body': '潜在贡献方向包括教育支持、社区运营、测试、文档、研究、设计、产品反馈和工程协作。',
    };
    const vi = <String, String>{
      'mainnet_wallet': 'Vi Mainnet',
      'home': 'Trang chu',
      'assets': 'Tai san',
      'activity': 'Hoat dong',
      'sessions': 'Phien',
      'add_token': 'Them Token',
      'total_balance': 'Tong so du',
      'send': 'Gui',
      'receive': 'Nhan',
      'explorer': 'Trinh duyet',
      'bridge': 'Cau noi',
      'mining_profile': 'Ho so dao',
      'joined': 'Tham gia',
      'completed_sessions': 'Phien hoan thanh',
      'anet_balance': 'So du ANET',
      'current_rate': 'Ty le hien tai',
      'colony_joined': 'Da vao colony',
      'not_in_colony': 'Chua tham gia colony',
      'session_history': 'Lich su phien',
      'credited': 'Da ghi co',
      'in_progress': 'Dang xu ly',
      'language': 'Ngon ngu',
      'language_help':
          'Chon ngon ngu ung dung. Che do tu dong map theo khu vuc: An Do -> Hindi, Pakistan -> Urdu, Trung Quoc -> Chinese, Tay Ban Nha/Latinh -> Espanol, Viet Nam -> Vietnamese, cac khu vuc khac mac dinh English.',
      'language_set_to': 'Da dat ngon ngu',
      'close': 'Dong',
      'start': 'Bat dau',
      'end': 'Ket thuc',
      'halving_level': 'Muc halving',
      'load_older_sessions': 'Tai phien cu hon',
      'loading_older_sessions': 'Dang tai phien cu hon...',
      'ann_halving_title': 'HALVING DA BAT DAU',
      'ann_halving_body':
          'Mang da dat moc 500,000 phien. Dot halving dau tien da co hieu luc.',
      'ann_halving_note':
          'Co do tre xac thuc 6 gio truoc khi ap dung ty le moi. He thong se xac thuc cac phien dang cho truoc. Khi moc 500k duoc xac nhan, Live Output cua ban se tu dong cap nhat theo ty le halving moi.',
      'ann_halving_safe':
          'Khong can thao tac - cac phien dang chay an toan va se duoc ghi co dung ty le.',
      'ann_x_title': 'CAP NHAT X MOI NHAT',
      'ann_x_body':
          'Theo doi Mr_A_Awakening de xem cac bai dang chinh thuc moi nhat cua A-Network.',
      'ann_x_note':
          'Slide nay tu dong chuyen moi 60 giay cung voi card cap nhat halving.',
      'ann_x_cta': 'Mo cap nhat X moi nhat',
      'page_subtitle_ecosystem':
          'Goc nhin mang truc tiep, thao tac he sinh thai va cong cu phat trien colony.',
      'page_subtitle_antwork':
          'Chay phien Ant Work 6 gio va theo doi cot moc hoat dong da xac thuc.',
      'page_subtitle_wallet':
          'Xem so du, cong cu vi va kha nang hien thi Layer 1 trong mot noi.',
      'page_subtitle_web4':
          'Mainnet Layer 1 private/enclosed dang chay, muc tieu migration va thiet ke settlement ANTS dai han.',
      'page_subtitle_whitepaper':
          'Doc mo hinh van hanh hien tai, quy tac phan phoi va thiet ke he thong.',
      'page_subtitle_colony':
          'Quan ly ro rang phong colony cua ban va phong upline duoc lien ket.',
      'page_subtitle_more':
          'Ho tro, trang phap ly, ngon ngu, thong bao va dieu khien tai khoan.',
      'page_info_ecosystem':
          'Ant Ecosystem la man hinh home van hanh, ket hop thong so live, thao tac nhanh va truy cap cong cu colony de hieu mang truoc khi bat dau phien.',
      'page_info_antwork':
          'Ant Work chay theo phien 6 gio da xac thuc. Hoat dong duoc ghi bang ANTS truoc, ANET chi claim duoc sau khi dat nguong phien hoan thanh, va halving theo cot moc phien da xac thuc toan mang.',
      'page_info_wallet':
          'ANET Wallet gom so du ANET noi bo, thiet lap vi va cong cu hien thi chain.',
      'page_info_web4':
          'Web4 giai thich cach ANET Layer 1 private/enclosed mainnet dang live ket hop voi Ant Work Web2 hien tai, trong khi migration va claim flow van duoc trien khai theo giai doan.',
      'page_info_whitepaper':
          'Trang Whitepaper tom tat quy tac hien tai: ANTS-first accounting, tran 21 trieu ANET, phien 6 gio, halving theo phien va referral chi de tang truong colony.',
      'page_info_colony':
          'Colony (Web5) la noi Ant Codes ket noi voi cac phong cong dong.',
      'page_info_more': 'More tap trung cai dat van hanh va boi canh phap ly.',
      'total_ants': 'Tong so Ants',
      'total_ants_info_body':
          'Tong so ants da dang ky dinh danh trong colony A-Network.',
      'active_workers': 'Worker dang hoat dong',
      'active_workers_info_body':
          'Tong so worker ants da hoan thanh it nhat mot phien 6 gio duoc xac thuc.',
      'completed_work': 'cong viec da hoan thanh',
      'active_territories': 'Lanh tho dang hoat dong',
      'verified_sessions': 'PHIEN DA XAC THUC',
      'network_throughput': 'Thong luong mang',
      'live_output': 'SAN LUONG LIVE',
      'markets': 'THI TRUONG',
      'completed_at_least_one_session': 'Da hoan thanh it nhat mot phien',
      'open': 'Mo',
      'live_ant_work': 'Ant Work Live',
      'live_ant_work_info_body':
          'The nay la tong quan phien mining dang chay: trang thai, san luong phien, thoi gian con lai va so du da tich luy.',
      'tracked': 'da theo doi',
      'session_output': 'SAN LUONG PHIEN',
      'anet_per_6h_cycle': 'ANET moi chu ky 6 gio',
      'portfolio': 'DANH MUC',
      'accumulated': 'da tich luy',
      'open_ant_work': 'Mo Ant Work',
      'start_ant_work': 'Bat dau Ant Work',
      'refresh_activity': 'Lam moi hoat dong',
      'ant_work_in_progress': 'Ant Work dang chay',
      'begin_your_journey': 'Bat dau hanh trinh cua ban',
      'anet_wallet': 'Vi ANET',
      'wallet_tools_chain_visibility': 'So du, cong cu vi, hien thi chain',
      'network_status': 'Trang thai mang',
      'online': 'TRUC TUYEN',
      'total_working_ants': 'Tong so Ants dang lam viec',
      'together_future': 'Cung nhau, chung ta xay dung tuong lai.',
      'starting_session': 'Dang bat dau phien...',
      'session_active_now': 'Phien dang hoat dong',
      'ready_new_session': 'San sang cho phien 6 gio moi',
      'live': 'LIVE',
      'ready': 'SAN SANG',
      'quick_action': 'Thao tac nhanh',
      'wallet_locked': 'Vi da khoa',
      'set_pin_continue': 'Dat PIN de tiep tuc',
      'enter_wallet_pin_message': 'Nhap PIN vi de truy cap vi Web3 cua ban.',
      'set_pin_secure_message': 'Dat PIN de bao mat vi truoc khi truy cap.',
      'unlock_wallet': 'Mo khoa vi',
      'set_wallet_pin': 'Dat PIN vi',
      'ant_work_running': 'Ant Work...',
      'starting': 'Dang bat dau...',
      'six_hour_session_active': 'Phien 6 gio dang hoat dong',
      'no_active_session': 'Khong co phien dang hoat dong',
      'next_stage_unlocked': 'Da mo khoa giai doan tiep theo',
      'sessions_to_next_stage': 'phien den giai doan tiep theo',
      'standby': 'CHO SAN',
      'halving_stage': 'Giai doan halving',
      'rank': 'Xep hang',
      'supply_progress': 'Tien do nguon cung',
      'refresh': 'Lam moi',
      'balance': 'So du',
      'tracked_balance': 'SO DU THEO DOI',
      'network_scale': 'QUY MO MANG',
      'next_stage': 'GIAI DOAN TIEP THEO',
      'target': 'Muc tieu',
      'session_rules': 'Quy tac phien',
      'validated_cycle_6h': 'Chu ky xac thuc 6 gio',
      'sessions_to_claim_anet': 'phien de claim ANET',
      'rewards_tracked_ants_first':
          'Phan thuong duoc theo doi bang ANTS truoc. Ghi co phien chi duoc dang sau khi server xac thuc hoan thanh.',
      'network_rules': 'Quy tac mang',
      'next_output': 'San luong tiep theo',
      'referrals_grow_colony_only':
          'Referral chi giup colony phat trien. So dang ky, quy mo colony va so du vi khong thay doi halving hoac tao coin bonus.',
      'supply_ledger': 'So cai nguon cung',
      'global_mined': 'Da dao toan cau',
      'total_max_supply': 'Tong nguon cung toi da',
      'wp_title': 'Sach trang A-Network',
      'wp_open_privacy': 'Mo chinh sach quyen rieng tu',
      'wp_open_terms': 'Mo dieu khoan',
      'col_title': 'Colony Chat | Web5 ANET Core',
      'col_subtitle':
          'Nhom ant theo colony, huong dong gop, co van, va xay dung he sinh thai dai han.',
      'col_worker_transfer': 'Chuyen Worker',
      'col_copy_address': 'Sao chep dia chi',
      'col_view_seed': 'Xem seed',
      'col_set_pin': 'Dat PIN',
      'col_change_pin': 'Doi PIN',
      'col_quick_access_title': 'Truy cap nhanh Web5',
      'col_colony_access_title': 'Truy cap colony',
      'col_migration_title': 'Chuyen sang Web3 (Du kien)',
      'col_anet_core_title': 'Chuong trinh ANET Core',
      'col_open_all_title': 'Mo cho moi nen tang',
      'col_tracks_title': 'Huong dong gop (Du kien)',
      'col_roadmap_note':
          'Ghi chu lo trinh: mo hinh ap dung la khai thac Web2, hien thi Web3, va dieu phoi cong dong Web5.',
      'wp_version':
          'Phien ban 1.0.5 | Tom tat giao thuc, quy tac Ant Work, mainnet Layer 1 private/enclosed, quyen rieng tu va chinh sach',
      'wp_risk_notice':
          'Canh bao rui ro: A-Network la sang kien cong nghe dai han. Day khong phai loi khuyen tai chinh va khong dam bao loi nhuan. Miner du dieu kien co the nhan thuong he sinh thai dua tren phi, gan voi hoat dong mang da xac thuc theo quy tac giao thuc.',
      'wp_1_title': '1. Su menh',
      'wp_1_body':
          'Xay dung so cai tham gia, noi cong viec duoc do luong, phat hanh co gioi han, va hoat dong Web2 co the quyet toan vao Layer 1 dang hoat dong ma khong lam mo quy tac cung.',
      'wp_2_title': '2. Tom tat phien ban 1.0.5',
      'wp_2_body':
          'A-Network v1.0.5 la he thong Ant Work uu tien ANTS. Nguoi dung hoan thanh phien 6 gio da xac thuc, tich luy ANTS trong so cai, va chi du dieu kien claim Layer 1 sau 1,000 phien thanh cong.',
      'wp_3_title': '3. Nen kinh te 3 lop',
      'wp_3_body':
          'Web2 Off-Chain Economy: theo doi phien, trang thai tai khoan, chong gian lan va ke toan so cai ANTS.\n\nWeb3 Visibility Economy: hien thi token BNB Chain, minh bach hop dong va tham chieu vi.\n\nWeb4 Settlement Economy: mainnet Layer 1 private/enclosed dang chay, block settlement theo su kien, phi theo ANTS, va lo trinh mo rong len on-chain.',
      'wp_4_title': '4. Mo hinh don vi',
      'wp_4_body':
          '1 ANET = 100,000,000 ANTS. ANTS la don vi ke toan nho nhat. San luong phien tinh theo ANET tuong duong nhung luu bang ANTS de giu do chinh xac va ho tro settlement Layer 1.',
      'wp_5_title': '5. Quy tac phien',
      'wp_5_body':
          'Moi phien Ant Work keo dai 6 gio. Moi nguoi dung toi da 4 phien moi ngay. Hoan thanh tuc thi bi tu choi. Bat dau va ket thuc phien duoc dong dau thoi gian de kiem toan va chong lam dung.',
      'wp_6_title': '6. Dong co phan phoi',
      'wp_6_body':
          '500,000 phien dau cua mang dung muc khoi dong 0.04882812 ANET moi phien hoan thanh. Sau do, lich trinh dai han bat dau 0.00262144 ANET moi phien (262,144 ANTS) va giam nua theo tong so phien toan mang.',
      'wp_7_title': '7. Co che giam nua',
      'wp_7_body':
          'Giam nua chi dua tren tong so phien hoan thanh. 500,000 phien dau la launch tranche. Sau do, san luong moi phien giam nua sau moi 3,800,000,000 phien bo sung den Stage 9.',
      'wp_8_title': '8. Dieu kien va claim',
      'wp_8_body':
          'Miner du dieu kien doi ANTS sang ANET sau 1,000 phien thanh cong. Truoc nguong nay, ANTS chi duoc ghi trong so cai va chua claim duoc thanh ANET.',
      'wp_9_title': '9. Bao ve nguon cung',
      'wp_9_body':
          'Backend thuc thi tran 21,000,000 khi chuyen doi. Neu mot claim vuot tran, no se duoc giam ve dung muc cung con lai va khong tao output am.',
      'wp_10_title': '10. Trang thai toan cuc',
      'wp_10_body':
          'Production API cung cap trang thai toan cuc cho phan tich va client: tong nguoi dung, tong phien, miner dang hoat dong, nguoi dung du dieu kien, nguoi dung da chuyen doi, tong ANTS tich luy, tong ANET da claim, giai doan phan phoi hien tai va tien do giam nua.',
      'wp_11_title': '11. Vi va di chuyen',
      'wp_11_body':
          'Moi tai khoan co the tao danh tinh vi ANET va tuy chon dat vi migration rieng. Tinh lien tuc cua vi gom bao ve PIN, xem seed qua OTP va theo doi tien do migration.',
      'wp_12_title': '12. Chinh sach reset',
      'wp_12_body':
          'Mo hinh reset co the xoa trang thai Ant Work nhung van giu tai khoan va dia chi vi. Phien nguoi dung, so du ANTS, ANET da claim, co hieu du dieu kien va bo dem toan cuc ve 0 ma khong xoa danh tinh.',
      'wp_13_title': '13. Bao mat va chong lam dung',
      'wp_13_body':
          'Bao ve gom xac minh OTP email, kiem tra thiet bi tin cay, JWT gan theo phien, gioi han thiet bi, moi luc chi 1 phien active, gioi han phien moi ngay, xac thuc heartbeat, cham diem rui ro, claim co dieu kien cho tai khoan bi co, va nhat ky kiem toan bao mat.',
      'wp_14_title': '14. Quyen rieng tu va su dung co trach nhiem',
      'wp_14_body':
          'He thong thu thap thong tin can thiet de van hanh dich vu, ngan gian lan va ho tro tuan thu: thong tin dang nhap, lien he, tin hieu thiet bi, lien ket vi va lich su hoat dong. Cam bot, lam dung va hanh vi khai thac lo hong.',
      'wp_15_title': '15. Tuan thu va canh bao rui ro',
      'wp_15_body':
          'A-Network la du an cong nghe, khong phai tu van tai chinh, va khong dam bao loi nhuan. San luong Ant Work, so du ANTS, chuyen doi ANET, thong bao, khoi phuc vi, phan phoi kiem soat va thuong miner dua tren phi deu phu thuoc quy tac backend hien tai va cac dot xem xet governance/bao mat trong tuong lai.',
      'wp_16_title': '16. Dinh huong dai han',
      'wp_16_body':
          'Lo trinh van la Web2 participation -> Web3 visibility -> live Web4 private/enclosed mainnet settlement -> ANET Core. Uu tien truoc mat la on dinh so cai, do tin cay mainnet, va cac luong migration/claim da duoc kiem toan cho phat hanh rong hon.',
      'col_quick_access_body':
          'Dung Worker Transfer de mo nhanh form chuyen Layer 1 dang live voi vi da dien san trong trinh duyet dApp. Copy Address, View Seed va Change PIN duoc dat ngay tai day de khong can quay lai Web4 cho thao tac bao mat thong dung.',
      'col_colony_access_body':
          'Moi chu tai khoan co mot phong colony chi dinh. Chu tai khoan chon ten colony tu danh sach co san, con direct colony ants duoc server dua vao cung phong do. Quang cao van nam trong khung chat.',
      'col_migration_body':
          'Web3 van la lop van hanh rieng cho hien thi hop dong cong khai, su tham gia doi tac va onboarding theo huong buyer sau nay. No khong thay doi logic ke toan mining Web2 hay cham diem colony trong ban hien tai.',
      'col_anet_core_body':
          'ANET Core la huong Web5 tuong lai. Cac group colony co the tro thanh mot phan cua lop nay sau, voi danh tinh cong dong, do hien thi blockchain cong khai thong qua ANET-Chain, va vai tro dieu phoi rong hon cung phat trien theo thoi gian.',
      'col_open_all_body':
          'Co kinh nghiem lap trinh la tot nhung khong bat buoc. A-Network co the ho tro cong tac vien thong qua mentoring, bai tap thuc te va cac lo trinh hoc tap co cau truc.',
      'col_tracks_body':
          'Cac huong dong gop co the gom ho tro giao duc, van hanh cong dong, testing, tai lieu, nghien cuu, thiet ke, phan hoi san pham va hop tac ky thuat.',
    };
    const es = <String, String>{
      'mainnet_wallet': 'Billetera Principal',
      'home': 'Inicio',
      'assets': 'Activos',
      'activity': 'Actividad',
      'sessions': 'Sesiones',
      'add_token': 'Añadir Token',
      'total_balance': 'Saldo Total',
      'send': 'Enviar',
      'receive': 'Recibir',
      'explorer': 'Explorador',
      'bridge': 'Puente',
      'mining_profile': 'Perfil de Minería',
      'joined': 'Registrado',
      'completed_sessions': 'Sesiones Completadas',
      'anet_balance': 'Saldo ANET',
      'current_rate': 'Tasa Actual',
      'colony_joined': 'Colonia Unida',
      'not_in_colony': 'Sin colonia',
      'session_history': 'Historial de Sesiones',
      'credited': 'Acreditado',
      'in_progress': 'En Progreso',
      'language': 'Idioma',
      'language_help':
          'Elige el idioma de la app. El modo automatico usa region: India -> Hindi, Pakistan -> Urdu, China -> Chino, Espana/Latinoamerica -> Espanol, Vietnam -> Vietnamita, y respaldo en Ingles para otras regiones.',
      'language_set_to': 'Idioma cambiado a',
      'close': 'Cerrar',
      'start': 'Inicio',
      'end': 'Fin',
      'halving_level': 'Nivel de Halving',
      'load_older_sessions': 'Cargar sesiones anteriores',
      'loading_older_sessions': 'Cargando sesiones anteriores...',
      'ann_halving_title': 'HALVING YA INICIADO',
      'ann_halving_body':
          'La red alcanzo el hito de 500,000 sesiones. El primer halving ya esta activo.',
      'ann_halving_note':
          'Hay un retraso de validacion de 6 horas antes de aplicar la nueva tasa. El sistema valida primero las sesiones pendientes. Cuando se confirme el hito 500k, tu Live Output se actualizara automaticamente.',
      'ann_halving_safe':
          'No se requiere accion - las sesiones en progreso estan seguras y se acreditaran con la tasa correcta.',
      'ann_x_title': 'ULTIMA ACTUALIZACION EN X',
      'ann_x_body':
          'Sigue a Mr_A_Awakening para ver las publicaciones oficiales mas recientes de A-Network.',
      'ann_x_note':
          'Esta diapositiva rota automaticamente cada 60 segundos junto con la tarjeta de halving.',
      'ann_x_cta': 'Abrir ultimas actualizaciones en X',
      'page_subtitle_ecosystem':
          'Vista de red en vivo, acciones del ecosistema y herramientas de crecimiento de colonia.',
      'page_subtitle_antwork':
          'Ejecuta sesiones Ant Work de 6 horas y sigue hitos de actividad verificados.',
      'page_subtitle_wallet':
          'Consulta saldos, herramientas de billetera y visibilidad Layer 1 en un solo lugar.',
      'page_subtitle_web4':
          'Mainnet Layer 1 privada/cerrada en vivo, objetivos de migracion y diseno de liquidacion ANTS a largo plazo.',
      'page_subtitle_whitepaper':
          'Lee el modelo operativo actual, reglas de distribucion y diseno del sistema.',
      'page_subtitle_colony':
          'Gestiona claramente tu sala de colonia y cualquier sala upline vinculada.',
      'page_subtitle_more':
          'Soporte, paginas legales, idioma, notificaciones y controles de cuenta.',
      'page_info_ecosystem':
          'Ant Ecosystem es la pantalla operativa principal. Combina metricas en vivo, acciones rapidas y acceso a herramientas clave de colonia para entender la red antes de iniciar una sesion.',
      'page_info_antwork':
          'Ant Work funciona con sesiones validadas de 6 horas. La actividad se registra primero en ANTS, ANET es reclamable solo tras el umbral requerido de sesiones completadas, y el halving sigue hitos verificados de sesiones de toda la red.',
      'page_info_wallet':
          'ANET Wallet agrupa saldo interno ANET, configuracion de billetera y herramientas de visibilidad de cadena.',
      'page_info_web4':
          'Web4 explica como el mainnet Layer 1 privado/cerrado en vivo opera con Ant Work Web2 actual, mientras migracion y flujo de reclamo siguen por etapas.',
      'page_info_whitepaper':
          'La pagina Whitepaper resume reglas actuales: contabilidad ANTS-first, limite de 21 millones ANET, sesiones de 6 horas, halving por sesiones y referidos solo para crecimiento de colonia.',
      'page_info_colony':
          'Colony (Web5) conecta Ant Codes con salas de comunidad.',
      'page_info_more':
          'More centraliza configuracion operativa y contexto legal.',
      'total_ants': 'Total de Ants',
      'total_ants_info_body':
          'Numero total de ants que registraron su identidad en la colonia A-Network.',
      'active_workers': 'Workers activos',
      'active_workers_info_body':
          'Numero total de worker ants que completaron al menos una sesion completa validada de 6 horas.',
      'completed_work': 'trabajo completado',
      'active_territories': 'Territorios activos',
      'verified_sessions': 'SESIONES VERIFICADAS',
      'network_throughput': 'Rendimiento de red',
      'live_output': 'SALIDA EN VIVO',
      'markets': 'MERCADOS',
      'completed_at_least_one_session': 'Completo al menos una sesion',
      'open': 'Abrir',
      'live_ant_work': 'Ant Work en vivo',
      'live_ant_work_info_body':
          'Esta tarjeta muestra un resumen ejecutivo de la sesion de mineria activa: estado actual, salida de sesion, tiempo restante y saldo acumulado.',
      'tracked': 'rastreado',
      'session_output': 'SALIDA DE SESION',
      'anet_per_6h_cycle': 'ANET por ciclo de 6 horas',
      'portfolio': 'PORTAFOLIO',
      'accumulated': 'acumulado',
      'open_ant_work': 'Abrir Ant Work',
      'start_ant_work': 'Iniciar Ant Work',
      'refresh_activity': 'Actualizar actividad',
      'ant_work_in_progress': 'Ant Work en progreso',
      'begin_your_journey': 'Comienza tu camino',
      'anet_wallet': 'Billetera ANET',
      'wallet_tools_chain_visibility':
          'Saldo, herramientas de billetera, visibilidad de cadena',
      'network_status': 'Estado de red',
      'online': 'EN LINEA',
      'total_working_ants': 'Total de Ants trabajando',
      'together_future': 'Juntos construimos el futuro.',
      'starting_session': 'Iniciando sesion...',
      'session_active_now': 'La sesion esta activa ahora',
      'ready_new_session': 'Listo para una nueva sesion de 6 horas',
      'live': 'EN VIVO',
      'ready': 'LISTO',
      'quick_action': 'Accion rapida',
      'wallet_locked': 'Billetera bloqueada',
      'set_pin_continue': 'Configura PIN para continuar',
      'enter_wallet_pin_message':
          'Ingresa tu PIN de billetera para acceder a tu billetera Web3.',
      'set_pin_secure_message':
          'Configura un PIN para asegurar tu billetera antes de acceder.',
      'unlock_wallet': 'Desbloquear billetera',
      'set_wallet_pin': 'Configurar PIN de billetera',
      'ant_work_running': 'Ant Work...',
      'starting': 'Iniciando...',
      'six_hour_session_active': 'Sesion de 6 horas activa',
      'no_active_session': 'Sin sesion activa',
      'next_stage_unlocked': 'Siguiente etapa desbloqueada',
      'sessions_to_next_stage': 'sesiones para la siguiente etapa',
      'standby': 'EN ESPERA',
      'halving_stage': 'Etapa de halving',
      'rank': 'Rango',
      'supply_progress': 'Progreso de suministro',
      'refresh': 'Actualizar',
      'balance': 'Saldo',
      'tracked_balance': 'SALDO RASTREADO',
      'network_scale': 'ESCALA DE RED',
      'next_stage': 'SIGUIENTE ETAPA',
      'target': 'Objetivo',
      'session_rules': 'Reglas de sesion',
      'validated_cycle_6h': 'Ciclo validado de 6 horas',
      'sessions_to_claim_anet': 'sesiones para reclamar ANET',
      'rewards_tracked_ants_first':
          'Las recompensas se rastrean primero en ANTS. El credito de sesion se publica solo despues de que el servidor valida la finalizacion.',
      'network_rules': 'Reglas de red',
      'next_output': 'Siguiente salida',
      'referrals_grow_colony_only':
          'Los referidos solo hacen crecer la colonia. El conteo de registro, tamano de colonia y saldo de billetera no cambian el halving ni crean bonos en moneda.',
      'supply_ledger': 'Libro de suministro',
      'global_mined': 'Minado global',
      'total_max_supply': 'Suministro maximo total',
      'wp_title': 'Libro Blanco A-Network',
      'wp_open_privacy': 'Abrir Política de Privacidad',
      'wp_open_terms': 'Abrir Términos',
      'col_title': 'Chat de Colonia | Web5 ANET Core',
      'col_subtitle':
          'Grupos ANT de colonia, pistas de contribución, mentoría y construcción del ecosistema.',
      'col_worker_transfer': 'Transferencia de Trabajador',
      'col_copy_address': 'Copiar Dirección',
      'col_view_seed': 'Ver Semilla',
      'col_set_pin': 'Establecer PIN',
      'col_change_pin': 'Cambiar PIN',
      'col_quick_access_title': 'Acceso Rápido Web5',
      'col_colony_access_title': 'Acceso a Colonia',
      'col_migration_title': 'Migración a Web3 (Planeado)',
      'col_anet_core_title': 'Programa ANET Core',
      'col_open_all_title': 'Abierto a Todos',
      'col_tracks_title': 'Pistas de Contribución (Planeado)',
      'col_roadmap_note':
          'Nota de hoja de ruta: el modelo aplicado es minería Web2, visibilidad Web3 y coordinación comunitaria Web5.',
      'wp_version':
          'Versión 1.0.5 | Resumen del Protocolo, Reglas de Ant Work, Red Principal Privada/Cerrada Capa 1, Privacidad y Política',
      'wp_risk_notice':
          'Aviso de Riesgo: A-Network es una iniciativa tecnologica a largo plazo. No es asesoramiento financiero y no garantiza rendimientos. Los miners elegibles pueden recibir recompensas del ecosistema basadas en comisiones, vinculadas a la actividad verificada de la red segun las reglas del protocolo.',
      'wp_1_title': '1. Misión',
      'wp_1_body':
          'Construir un registro de participación en el que el trabajo se mide, la emisión está acotada y la actividad Web2 puede liquidarse en un sistema activo de Capa 1 sin obscurecer las reglas de suministro.',
      'wp_2_title': '2. Resumen de la Versión 1.0.5',
      'wp_2_body':
          'A-Network v1.0.5 es un sistema Ant Work con prioridad ANTS. Los usuarios completan sesiones validadas de 6 horas, acumulan ANTS en el registro y alcanzan la elegibilidad de reclamación en Capa 1 solo después de 1,000 sesiones exitosas. La red principal privada/cerrada ANET Capa 1 está activa y registra la actividad de liquidación.',
      'wp_3_title': '3. Economía de Tres Capas',
      'wp_3_body':
          'Economía Web2 fuera de cadena: seguimiento de sesiones, estado de cuenta, control de fraude y contabilidad del registro ANTS.\n\nEconomía de Visibilidad Web3: visibilidad del token en BNB Chain, transparencia de contratos y referencia de billetera.\n\nEconomía de Liquidación Web4: red principal activa de Capa 1, bloques de liquidación impulsados por eventos, lógica de tarifas en ANTS y futura migración a participación en cadena más amplia.',
      'wp_4_title': '4. Modelo de Unidad',
      'wp_4_body':
          '1 ANET = 100,000,000 ANTS. ANTS es la unidad contable mínima. La producción de sesión se calcula en términos equivalentes a ANET pero se almacena en ANTS para preservar la precisión y apoyar la liquidación en Capa 1.',
      'wp_5_title': '5. Reglas de Sesión',
      'wp_5_body':
          'Cada sesión de Ant Work dura 6 horas. Un usuario puede completar como máximo 4 sesiones por día. La finalización instantánea es rechazada. El inicio y la finalización de la sesión llevan marca de tiempo para auditoría y control de abusos.',
      'wp_6_title': '6. Motor de Distribución',
      'wp_6_body':
          'Las primeras 500,000 sesiones de la red usan la producción de lanzamiento de 0.04882812 ANET por sesión completada. Después de ese tramo, el programa de larga vida comienza con 0.00262144 ANET por sesión y luego se reduce a la mitad según las sesiones totales de la red. La emisión está impulsada por trabajo verificado, no por referidos.',
      'wp_7_title': '7. Lógica de Reducción a la Mitad',
      'wp_7_body':
          'La reducción a la mitad se basa únicamente en las sesiones totales completadas. Las primeras 500,000 sesiones forman el tramo de lanzamiento. Después, la producción de sesión se reduce a la mitad cada 3,800,000,000 sesiones adicionales hasta la Etapa 9.',
      'wp_8_title': '8. Elegibilidad y Reclamación',
      'wp_8_body':
          'Un minero se vuelve elegible para convertir ANTS en ANET después de 1,000 sesiones exitosas. Antes de ese umbral, ANTS permanece registrado en el registro pero no es reclamable como ANET.',
      'wp_9_title': '9. Protección del Suministro',
      'wp_9_body':
          'El backend aplica el límite de 21,000,000 en el momento de la conversión. Si una reclamación cruzaría el límite, se reduce a la oferta restante exacta y no puede crear producción negativa.',
      'wp_10_title': '10. Estado Global',
      'wp_10_body':
          'La API de producción expone el estado global para análisis: total de usuarios, sesiones totales, mineros activos, usuarios elegibles, ANTS total acumulado, ANET total reclamado, etapa de distribución actual y progreso de reducción a la mitad.',
      'wp_11_title': '11. Billetera y Migración',
      'wp_11_body':
          'Cada cuenta puede crear una identidad de billetera ANET y opcionalmente establecer una billetera de migración separada. La continuidad incluye protección PIN, revelación de semilla con OTP y seguimiento del progreso de migración.',
      'wp_12_title': '12. Política de Restablecimiento',
      'wp_12_body':
          'El modelo de restablecimiento puede borrar el estado de Ant Work preservando cuentas y direcciones de billetera. Las sesiones, saldos ANTS, ANET reclamado, indicadores de elegibilidad y contadores globales vuelven a cero sin eliminar registros de identidad.',
      'wp_13_title': '13. Seguridad y Antiabuso',
      'wp_13_body':
          'Las protecciones incluyen verificación OTP por correo, comprobaciones de dispositivo confiable, JWTs vinculados a sesiones, límites de dispositivos, una sesión activa a la vez, límites diarios, validación de latido, puntuación de riesgo y registros de auditoría de seguridad.',
      'wp_14_title': '14. Privacidad y Uso Responsable',
      'wp_14_body':
          'El sistema recopila credenciales, datos de contacto, señales de dispositivos, enlaces de billetera y registros de actividad necesarios para operar el servicio, prevenir fraudes y apoyar el cumplimiento. El uso de bots y comportamientos de explotación están prohibidos.',
      'wp_15_title': '15. Cumplimiento y Aviso de Riesgo',
      'wp_15_body':
          'A-Network es un proyecto tecnologico, no asesoramiento financiero, y no garantiza rendimientos. La produccion de Ant Work, los saldos ANTS, la conversion a ANET, las distribuciones controladas y las recompensas de miners basadas en comisiones siguen sujetas a las reglas actuales del backend y a futuras revisiones de gobernanza y seguridad.',
      'wp_16_title': '16. Dirección a Largo Plazo',
      'wp_16_body':
          'La hoja de ruta sigue siendo: participación Web2 → visibilidad Web3 → liquidación Web4 activa → ANET Core. La prioridad inmediata es la estabilidad del registro, la fiabilidad de la red principal y rutas de migración auditadas para una publicación más amplia.',
      'col_quick_access_body':
          'Usa Transferencia de Trabajador para abrir el formulario de transferencia en vivo de Capa 1 con tu billetera precargada dentro del navegador dApp. Copiar Dirección, Ver Semilla y Cambiar PIN están duplicados aquí para que no necesites volver a Web4 para acciones comunes de seguridad.',
      'col_colony_access_body':
          'Cada propietario de cuenta tiene una sala de colonia designada. El propietario puede elegir el nombre de la colonia entre opciones preestablecidas, mientras que las hormigas directas son dirigidas a esa misma sala por el servidor. Los anuncios permanecen dentro del panel de chat.',
      'col_migration_body':
          'Web3 sigue siendo una capa operativa separada para la visibilidad de contratos públicos, la participación de socios y la incorporación posterior. No redefine la contabilidad de minería Web2 ni la puntuación de colonias en la versión actual.',
      'col_anet_core_body':
          'ANET Core es la dirección futura de Web5. Las colonias de grupo pueden convertirse en parte de esa capa más adelante, con identidad comunitaria, visibilidad pública en blockchain a través de ANET-Chain, y roles de coordinación más amplios evolucionando juntos con el tiempo.',
      'col_open_all_body':
          'La experiencia en programación es bienvenida pero no requerida. A-Network puede apoyar a los colaboradores mediante tutoría, tareas prácticas y vías de aprendizaje estructuradas.',
      'col_tracks_body':
          'Las pistas potenciales incluyen apoyo educativo, operaciones comunitarias, pruebas, documentación, investigación, diseño, retroalimentación de productos y colaboración técnica.',
    };

    final lang = _walletLangCode();
    final map = lang == 'hi'
        ? hi
        : lang == 'ur'
        ? ur
        : lang == 'zh'
        ? zh
        : lang == 'es'
        ? es
        : lang == 'vi'
        ? vi
        : en;
    return map[key] ?? en[key] ?? key;
  }

  /// OKX tab item button
  Widget _okxTabItem(
    String label,
    int index,
    int current,
    Color activeColor,
    Color mutedColor,
    VoidCallback onTap,
  ) {
    final isActive = current == index;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? activeColor : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : mutedColor,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _okxHomeTab({
    required Color okxCard,
    required Color okxBorder,
    required Color okxGold,
    required Color okxGreen,
    required Color okxBlue,
    required Color okxMuted,
    required double appBalanceNum,
    required int completedSessions,
    required bool sendUnlocked,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF151A36), Color(0xFF0E1226)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: okxBorder),
          ),
          child: Column(
            children: [
              Text(
                _wt('total_balance'),
                style: TextStyle(color: okxMuted, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                '${appBalanceNum.toStringAsFixed(4)} ANET',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: okxGold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'ANET L1 · Native Chain',
                      style: TextStyle(
                        color: okxGold,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: okxGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'BIP-44 EVM ✓',
                      style: TextStyle(
                        color: okxGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  _okxActionBtn(
                    icon: Icons.north_rounded,
                    label: 'Withdraw',
                    color: okxBlue,
                    bg: okxCard,
                    onTap: () {
                      if (!sendUnlocked) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'ANET withdrawal unlocks after 1,000 sessions. Progress: $completedSessions/1000',
                            ),
                          ),
                        );
                        return;
                      }
                      _showSendCoinDialog();
                    },
                  ),
                  _okxActionBtn(
                    icon: Icons.south_rounded,
                    label: _wt('receive'),
                    color: okxGreen,
                    bg: okxCard,
                    onTap: () async {
                      await Clipboard.setData(
                        ClipboardData(text: createdWalletAddress),
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Receive address copied'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  _okxActionBtn(
                    icon: Icons.monetization_on_rounded,
                    label: 'Claim',
                    color: okxGold,
                    bg: okxCard,
                    onTap: () =>
                        _claimAnetNow(completedSessions: completedSessions),
                  ),
                  _okxActionBtn(
                    icon: Icons.auto_awesome_rounded,
                    label: 'NFT',
                    color: const Color(0xFFFF85A1),
                    bg: okxCard,
                    onTap: () =>
                        _openNftStudio(completedSessions: completedSessions),
                  ),
                  _okxActionBtn(
                    icon: Icons.travel_explore_rounded,
                    label: _wt('explorer'),
                    color: const Color(0xFF7AC3FF),
                    bg: okxCard,
                    onTap: () => openLinkInsideApp(
                      context,
                      '$_anetExplorerUrl/explorer',
                    ),
                  ),
                  _okxActionBtn(
                    icon: Icons.swap_horizontal_circle_rounded,
                    label: _wt('bridge'),
                    color: const Color(0xFFC7B2FF),
                    bg: okxCard,
                    onTap: () => _openWalletDapp(view: 'bridge'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: okxCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: okxBlue.withValues(alpha: 0.32)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.menu_book_rounded, color: okxBlue, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'How to Cash Out (DEX, not CEX)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '1) Complete 1,000 verified sessions.\n'
                '2) Open DEX in ANTS Browser and authorize wallet.\n'
                '3) Swap ANET to USDT/USDC in DEX cashout flow.\n'
                '4) Settlement lands in your ANET L1 wallet first.\n'
                '5) Bridge to EVM wallet in Step 3 when bridge transfer is live.',
                style: TextStyle(
                  color: okxMuted,
                  fontSize: 12.5,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'This flow is DEX-based and wallet-authorized instead of centralized exchange cashout.',
                style: TextStyle(
                  color: okxGold,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _okxMiniBtn(
                    'Open DEX',
                    Icons.currency_exchange_rounded,
                    okxBlue,
                    () {
                      _openDexWithPinGate(context);
                    },
                  ),
                  _okxMiniBtn(
                    'Bridge to BSC',
                    Icons.swap_horiz_rounded,
                    okxBlue,
                    () {
                      _openBridgeBurnWithPinGate(context);
                    },
                  ),
                  _okxMiniBtn(
                    'Copy Address',
                    Icons.copy_rounded,
                    okxGreen,
                    () async {
                      await Clipboard.setData(
                        ClipboardData(text: createdWalletAddress),
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Wallet address copied'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Network short name for badge
  String _networkShortName(String n) {
    if (n == 'BNB Smart Chain') return 'BSC';
    if (n == 'Ethereum') return 'ETH';
    if (n == 'Polygon') return 'POL';
    if (n == 'Arbitrum One') return 'ARB';
    if (n == 'Optimism') return 'OP';
    if (n == 'Base') return 'BASE';
    if (n == 'Avalanche C-Chain') return 'AVAX';
    if (n == 'Fantom') return 'FTM';
    if (n == 'Linea') return 'LINEA';
    if (n == 'zkSync Era') return 'ZKS';
    if (n == 'opBNB') return 'opBNB';
    if (_isAnetNativeNetwork(n)) return 'ANET';
    return n;
  }

  String? _txExplorerUrlForNetwork(String network, String txHash) {
    final hash = txHash.trim();
    if (hash.isEmpty) return null;
    final base = _evmTxExplorerByNetwork[network];
    if (base == null) return null;
    return '$base$hash';
  }

  /// Network picker bottom sheet
  Future<void> _showNetworkPickerSheet(
    Color bg,
    Color card,
    Color border,
    Color label,
    Color accent,
  ) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Select Network',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ..._supportedEvmNetworks.map((n) {
              final isSelected = n == _selectedEvmNetwork;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.circle,
                  size: 10,
                  color: isSelected ? accent : Colors.white30,
                ),
                title: Text(
                  n,
                  style: TextStyle(
                    color: isSelected ? Colors.white : label,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_rounded, color: accent)
                    : null,
                onTap: () async {
                  if (!mounted) return;
                  setState(() => _selectedEvmNetwork = n);
                  await _persistEvmWalletPrefs();
                  await _refreshCustomCoinBalances();
                  await _refreshCustomTokenActivity();
                  if (mounted) Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  /// OKX-style Assets tab
  Widget _okxAssetsTab({
    required Color okxCard,
    required Color okxBorder,
    required Color okxGold,
    required Color okxGreen,
    required Color okxBlue,
    required Color okxMuted,
    required Color okxLabel,
    required Color okxTextPrimary,
    required bool sendUnlocked,
    required int completedSessions,
  }) {
    final appBalanceNum =
        double.tryParse(walletAnetBalance.split(' ').first) ?? balance;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // ── ANET PRIMARY ─────────────────────────────────────────
        Container(
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            color: okxCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: okxGold.withValues(alpha: 0.28)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFB800), Color(0xFFFF8800)],
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'A',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'ANET',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: okxGold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'L1 Primary',
                                  style: TextStyle(
                                    color: okxGold,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'A-Network Native Chain',
                            style: TextStyle(color: okxMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${appBalanceNum.toStringAsFixed(4)} ANET',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_formatCompactCount(walletTrackedAnts)} ANTS tracked',
                          style: TextStyle(color: okxMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // ANET action buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _okxMiniBtn('Withdraw', Icons.north_rounded, okxBlue, () {
                      if (!sendUnlocked) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'ANET withdrawal unlocks after 1,000 sessions. Progress: $completedSessions/1000',
                            ),
                          ),
                        );
                        return;
                      }
                      _showSendCoinDialog();
                    }),
                    const SizedBox(width: 8),
                    _okxMiniBtn(
                      'Receive',
                      Icons.south_rounded,
                      okxGreen,
                      () async {
                        await Clipboard.setData(
                          ClipboardData(text: createdWalletAddress),
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Receive address copied'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _okxMiniBtn(
                      'History',
                      Icons.history_rounded,
                      const Color(0xFFC7B2FF),
                      () {
                        setState(() {
                          _walletTabIndex = 2;
                        });
                        _loadWalletCoinHistory();
                        _refreshCustomTokenActivity();
                      },
                    ),
                    const SizedBox(width: 8),
                    _okxMiniBtn(
                      'Explorer',
                      Icons.open_in_new_rounded,
                      const Color(0xFF7AC3FF),
                      () {
                        openLinkInsideApp(
                          context,
                          '$_anetExplorerUrl/explorer',
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── DIVIDER ──────────────────────────────────────────────
        if (_customCoins.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(child: Divider(color: okxBorder, height: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'EVM Tokens · $_selectedEvmNetwork',
                    style: TextStyle(
                      color: okxMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: okxBorder, height: 1)),
              ],
            ),
          ),

          // ── CUSTOM ERC-20 TOKENS ──────────────────────────────
          if (_customCoinBalanceLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF1677FF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Fetching balances on $_selectedEvmNetwork…',
                    style: TextStyle(color: okxMuted, fontSize: 12),
                  ),
                ],
              ),
            ),

          ..._customCoins.map((coin) {
            final name = coin['name'] ?? '';
            final symbol = coin['symbol'] ?? '';
            final contract = coin['contract'] ?? '';
            final decimals = coin['decimals'] ?? '18';
            final bal = _customCoinBalances[contract.toLowerCase()] ?? '--';
            final shortContract = contract.length > 14
                ? '${contract.substring(0, 8)}…${contract.substring(contract.length - 4)}'
                : contract;
            final initials = symbol.length >= 2
                ? symbol.substring(0, 2)
                : symbol;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: okxCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: okxBorder),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                    child: Row(
                      children: [
                        // Token avatar
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: okxBlue.withValues(alpha: 0.14),
                            border: Border.all(
                              color: okxBlue.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: TextStyle(
                                color: okxBlue,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    symbol,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E2440),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      _networkShortName(_selectedEvmNetwork),
                                      style: const TextStyle(
                                        color: Color(0xFF7B829A),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$name · $shortContract · $decimals dec',
                                style: TextStyle(color: okxMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$bal $symbol',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Token action row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _okxMiniBtn(
                          'P2P Send',
                          Icons.send_rounded,
                          okxBlue,
                          () {
                            _showSendEvmTokenDialog(coin);
                          },
                        ),
                        const SizedBox(width: 8),
                        _okxMiniBtn(
                          'Receive',
                          Icons.south_rounded,
                          okxGreen,
                          () async {
                            String addressToCopy = '';
                            if (_isAnetNativeNetwork(_selectedEvmNetwork)) {
                              addressToCopy = createdWalletAddress.trim();
                            } else {
                              addressToCopy =
                                  (await _derivePrimaryEvmAddress())?.trim() ??
                                  '';
                            }

                            if (addressToCopy.isEmpty ||
                                addressToCopy == 'Not created') {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Unable to resolve receive address. Re-open wallet and try again.',
                                  ),
                                ),
                              );
                              return;
                            }

                            await Clipboard.setData(
                              ClipboardData(text: addressToCopy),
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Receive address copied (${_isAnetNativeNetwork(_selectedEvmNetwork) ? 'ANET' : _networkShortName(_selectedEvmNetwork)}).',
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        _okxMiniBtn(
                          'Remove',
                          Icons.delete_outline_rounded,
                          const Color(0xFF7B829A),
                          () async {
                            setState(() {
                              _customCoins = _customCoins
                                  .where((c) => c != coin)
                                  .toList(growable: false);
                            });
                            await _persistEvmWalletPrefs();
                            await _refreshCustomCoinBalances();
                            await _refreshCustomTokenActivity();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],

        // ── EMPTY STATE ──────────────────────────────────────────
        if (_customCoins.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                Icon(
                  Icons.add_circle_outline_rounded,
                  size: 40,
                  color: okxMuted,
                ),
                const SizedBox(height: 10),
                Text(
                  'No EVM tokens added yet',
                  style: TextStyle(
                    color: okxMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Add any ERC-20 token by contract address to track balance and send P2P.',
                  style: TextStyle(
                    color: okxMuted.withValues(alpha: 0.7),
                    fontSize: 12,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: _showAddCustomCoinDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: okxBlue.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: okxBlue.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      '+ Add Token',
                      style: TextStyle(
                        color: Color(0xFF1677FF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),
        // ── WALLET MANAGEMENT ─────────────────────────────────────
        Divider(color: okxBorder, height: 1),
        const SizedBox(height: 14),
        Text(
          'Wallet Management',
          style: TextStyle(
            color: okxMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            buildActionButton(
              'Seed Phrase',
              _showSeedPhraseDialog,
              compact: true,
              icon: Icons.key_rounded,
            ),
            buildActionButton(
              'Change PIN',
              () => _showSetPinDialog(isChange: walletPinEnabled),
              compact: true,
              icon: Icons.password_rounded,
            ),
            buildActionButton(
              'Migration Wallet',
              _setMigrationAddress,
              compact: true,
              icon: Icons.account_tree_rounded,
            ),
            buildActionButton(
              'ANTS Browser',
              () => _openWalletDapp(view: 'dapp'),
              compact: true,
              icon: Icons.language_rounded,
            ),
            // INTERNAL TESTING ONLY — gated by --dart-define=ENABLE_ADS=true.
            // Invisible in production builds. Lets QA verify Unity Ads SDK
            // is initialized and serving an Interstitial without needing to
            // wire to real triggers yet.
            if (UnityAdsService.enabled)
              buildActionButton(
                'Test Ad',
                () async {
                  final shown = await UnityAdsService.instance
                      .maybeShowInterstitial(trigger: 'test_button');
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        shown
                            ? 'Ad request sent — Unity should display now'
                            : 'Ad skipped (frequency cap, not init, or disabled). Check logs.',
                      ),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                },
                compact: true,
                icon: Icons.play_circle_outline_rounded,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: okxBlue.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: okxBlue.withValues(alpha: 0.14)),
          ),
          child: Text(
            '🔐  BIP39 seed phrases import in MetaMask via m/44\'/60\'/0\'/0/0. Older legacy ANET seeds should be imported to MetaMask using Private Key.',
            style: TextStyle(color: okxMuted, fontSize: 11, height: 1.45),
          ),
        ),
      ],
    );
  }

  /// OKX-style Activity tab (L1 transaction history)
  Widget _okxActivityTab({
    required Color okxCard,
    required Color okxBorder,
    required Color okxGreen,
    required Color okxRed,
    required Color okxMuted,
    required Color okxLabel,
  }) {
    if (_walletHistoryLoading || _customTokenActivityLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1677FF)),
      );
    }

    if (_walletCoinHistory.isEmpty && _customTokenActivity.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_rounded, size: 44, color: okxMuted),
            const SizedBox(height: 12),
            Text(
              'No activity yet',
              style: TextStyle(
                color: okxMuted,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your ANET and custom token transactions will appear here.',
              style: TextStyle(
                color: okxMuted.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (_walletCoinHistory.isNotEmpty)
          Text(
            'ANET L1 Activity',
            style: TextStyle(
              color: okxMuted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        if (_walletCoinHistory.isNotEmpty) const SizedBox(height: 6),
        ..._walletCoinHistory.map((tx) {
          final txTypeRaw = (tx['transaction_type'] ?? 'coin_activity')
              .toString()
              .toLowerCase();
          final fromAddress = (tx['from_address'] ?? '')
              .toString()
              .toUpperCase();
          final toAddress = (tx['to_address'] ?? '').toString().toUpperCase();
          final ownAddress = createdWalletAddress.trim().toUpperCase();
          final isOutgoing = ownAddress.isNotEmpty && fromAddress == ownAddress;
          final txType = isOutgoing
              ? 'Sent'
              : txTypeRaw.contains('claim')
              ? 'Claimed'
              : txTypeRaw.contains('swap')
              ? 'Swapped'
              : 'Received';
          final ants = int.tryParse((tx['amount'] ?? '0').toString()) ?? 0;
          final anet = ants / 100000000.0;
          final status = (tx['status'] ?? 'confirmed').toString();
          final createdAt = (tx['created_at'] ?? '').toString();
          final shortDate = createdAt.length >= 16
              ? createdAt.substring(0, 16).replaceFirst('T', ' ')
              : createdAt;
          final counterparty = isOutgoing ? toAddress : fromAddress;
          final shortCP = counterparty.length > 12
              ? '${counterparty.substring(0, 6)}…${counterparty.substring(counterparty.length - 4)}'
              : (counterparty.isEmpty ? 'System' : counterparty);
          final txColor = isOutgoing ? okxRed : okxGreen;
          final txIcon = isOutgoing
              ? Icons.north_east_rounded
              : Icons.south_west_rounded;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: okxBorder)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: txColor.withValues(alpha: 0.12),
                  ),
                  child: Icon(txIcon, color: txColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        txType,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${isOutgoing ? 'To' : 'From'}: $shortCP · $status',
                        style: TextStyle(color: okxMuted, fontSize: 12),
                      ),
                      Text(
                        shortDate,
                        style: TextStyle(color: okxMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${isOutgoing ? '-' : '+'}${anet.toStringAsFixed(4)} ANET',
                  style: TextStyle(
                    color: txColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }),

        if (_customTokenActivity.isNotEmpty) const SizedBox(height: 14),
        if (_customTokenActivity.isNotEmpty)
          Text(
            'Custom Token Activity · ${_networkShortName(_selectedEvmNetwork)}',
            style: TextStyle(
              color: okxMuted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        if (_customTokenActivity.isNotEmpty) const SizedBox(height: 6),
        ..._customTokenActivity.map((tx) {
          final type = (tx['type'] ?? 'Received').toString();
          final symbol = (tx['symbol'] ?? '').toString();
          final amount = (tx['amount'] ?? '0').toString();
          final counterparty = (tx['counterparty'] ?? '').toString();
          final shortCP = counterparty.length > 12
              ? '${counterparty.substring(0, 6)}…${counterparty.substring(counterparty.length - 4)}'
              : counterparty;
          final block = (tx['blockNumber'] ?? 0).toString();
          final txHash = (tx['txHash'] ?? '').toString();
          final shortHash = txHash.length > 14
              ? '${txHash.substring(0, 8)}…${txHash.substring(txHash.length - 4)}'
              : txHash;
          final explorerUrl = _txExplorerUrlForNetwork(
            _selectedEvmNetwork,
            txHash,
          );

          final bool isSwap = type == 'Swapped';
          final bool isSent = type == 'Sent';
          final txColor = isSwap
              ? const Color(0xFFC7B2FF)
              : (isSent ? okxRed : okxGreen);
          final txIcon = isSwap
              ? Icons.swap_horiz_rounded
              : (isSent ? Icons.north_east_rounded : Icons.south_west_rounded);

          return InkWell(
            onTap: explorerUrl == null
                ? null
                : () => openLinkInsideApp(context, explorerUrl),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: okxBorder)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: txColor.withValues(alpha: 0.12),
                    ),
                    child: Icon(txIcon, color: txColor, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$type $symbol',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Counterparty: $shortCP',
                          style: TextStyle(color: okxMuted, fontSize: 12),
                        ),
                        Text(
                          'Block #$block · $shortHash',
                          style: TextStyle(color: okxMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isSent ? '-' : '+'}$amount $symbol',
                        style: TextStyle(
                          color: txColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (explorerUrl != null)
                        Text(
                          'Open tx',
                          style: TextStyle(color: okxMuted, fontSize: 10),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _okxSessionsTab({
    required Color okxCard,
    required Color okxBorder,
    required Color okxGreen,
    required Color okxBlue,
    required Color okxMuted,
    required Color okxLabel,
    required Color okxTextPrimary,
    required double appBalanceNum,
  }) {
    if (_miningSessionHistoryLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1677FF)),
      );
    }

    final profile = _miningProfileData;
    final sessions = _miningSessionHistory;

    // ── Profile header data ───────────────────────────────────
    final userId =
        profile['userId']?.toString() ?? currentUserId?.toString() ?? '—';
    final successfulSessions =
        int.tryParse((profile['successfulSessions'] ?? 0).toString()) ?? 0;
    final unifiedBalance = appBalanceNum;
    final networkSummary = _networkMiningSummary;
    final networkRate = double.tryParse(
      (networkSummary['rewardPerSession'] ??
              networkSummary['currentRate'] ??
              '')
          .toString(),
    );
    final profileRate = double.tryParse(
      (profile['currentRate'] ?? '').toString(),
    );
    final effectiveRate = networkRate ?? profileRate;
    final rateText = effectiveRate != null
        ? '${effectiveRate.toStringAsFixed(effectiveRate < 0.01 ? 6 : 4)} ANET/session'
        : '—';
    final miningStartDate = profile['miningStartDate']?.toString() ?? '';
    final startDateShort = miningStartDate.length >= 10
        ? miningStartDate.substring(0, 10)
        : miningStartDate;
    final hasColony = profile['hasColony'] == true;
    final colonyJoinedAt = profile['colonyJoinedAt']?.toString() ?? '';
    final colonyJoinShort = colonyJoinedAt.length >= 10
        ? colonyJoinedAt.substring(0, 10)
        : '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // ── Validator eligibility card ─────────────────────────────
        Builder(
          builder: (context) {
            final me = _myProfile ?? const <String, dynamic>{};
            final vi =
                (me['validatorInfo'] as Map?)?.cast<String, dynamic>() ??
                const <String, dynamic>{};
            final isCandidate = vi['isCandidate'] == true;
            final emailOk = vi['emailVerified'] == true;
            final walletOk = vi['walletSet'] == true;
            final migrationOk = vi['migrationWalletSet'] == true;
            final sessions =
                (vi['sessionsCompleted'] as num?)?.toInt() ??
                (me['successful_sessions'] as num?)?.toInt() ??
                0;
            final oneSessionOk = sessions >= 1;
            final thousandOk = sessions >= 1000;

            Widget gateRow(String label, bool passed) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(
                    passed
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 15,
                    color: passed ? okxGreen : okxMuted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: passed ? okxTextPrimary : okxMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: okxCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCandidate
                      ? okxGreen.withValues(alpha: 0.4)
                      : okxBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        color: isCandidate ? okxGreen : okxMuted,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Validator eligibility',
                        style: TextStyle(
                          color: okxTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: (isCandidate ? okxGreen : okxMuted).withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isCandidate ? 'VALIDATOR CANDIDATE' : 'MINER',
                          style: TextStyle(
                            color: isCandidate ? okxGreen : okxMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  gateRow('Email verified', emailOk),
                  gateRow('Wallet address set', walletOk),
                  gateRow('Migration wallet set', migrationOk),
                  gateRow('At least 1 session completed', oneSessionOk),
                  gateRow(
                    '1,000+ sessions completed ($sessions / 1,000)',
                    thousandOk,
                  ),
                ],
              ),
            );
          },
        ),

        // ── Profile card ───────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: okxCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: okxBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: okxBlue.withValues(alpha: 0.15),
                    ),
                    child: Icon(Icons.person_rounded, color: okxBlue, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _wt('mining_profile'),
                        style: TextStyle(
                          color: okxTextPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'ID #$userId',
                        style: TextStyle(color: okxMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _sessionProfileRow(
                label: _wt('joined'),
                value: startDateShort.isEmpty ? '—' : startDateShort,
                muted: okxMuted,
                textPrimary: okxTextPrimary,
              ),
              _sessionProfileRow(
                label: _wt('completed_sessions'),
                value: successfulSessions.toString(),
                muted: okxMuted,
                textPrimary: okxTextPrimary,
              ),
              _sessionProfileRow(
                label: _wt('anet_balance'),
                value: '${unifiedBalance.toStringAsFixed(4)} ANET',
                muted: okxMuted,
                textPrimary: okxTextPrimary,
              ),
              _sessionProfileRow(
                label: _wt('current_rate'),
                value: rateText,
                muted: okxMuted,
                textPrimary: okxTextPrimary,
              ),
              _sessionProfileRow(
                label: _wt('colony_joined'),
                value: hasColony
                    ? (colonyJoinShort.isEmpty ? 'Yes' : colonyJoinShort)
                    : _wt('not_in_colony'),
                muted: okxMuted,
                textPrimary: hasColony ? okxGreen : okxMuted,
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        if (sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Icon(Icons.history_rounded, size: 44, color: okxMuted),
                const SizedBox(height: 10),
                Text(
                  'No sessions recorded yet',
                  style: TextStyle(
                    color: okxMuted,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Completed 6-hour Ant Work sessions will appear here.',
                  style: TextStyle(
                    color: okxMuted.withValues(alpha: 0.65),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else ...[
          Text(
            _wt('session_history'),
            style: TextStyle(
              color: okxMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...() {
            // Sort for display: active first, then completed newest->oldest.
            final completed =
                sessions.where((s) => s['is_completed'] == true).toList()
                  ..sort((a, b) {
                    final ta = (a['start_time'] ?? '').toString();
                    final tb = (b['start_time'] ?? '').toString();
                    return tb.compareTo(ta); // DESC: newest first
                  });
            final active =
                sessions.where((s) => s['is_completed'] != true).toList()
                  ..sort((a, b) {
                    final ta = (a['start_time'] ?? '').toString();
                    final tb = (b['start_time'] ?? '').toString();
                    return ta.compareTo(
                      tb,
                    ); // Oldest active first (usually one row)
                  });
            final sorted = [...active, ...completed];
            final completedBase = successfulSessions > 0
                ? successfulSessions
                : completed.length;
            int activeCounter = 0;
            int completedCounter = 0;

            return sorted.map((s) {
              final isCompleted = s['is_completed'] == true;
              final sessionNum = isCompleted
                  ? ((completedBase - completedCounter) > 0
                        ? (completedBase - completedCounter)
                        : (completedCounter + 1))
                  : (successfulSessions + 1 + activeCounter);
              if (isCompleted) {
                completedCounter++;
              } else {
                activeCounter++;
              }
              final reward =
                  double.tryParse((s['reward'] ?? '0').toString()) ?? 0;
              final status = (s['status'] ?? 'active').toString();
              final startTime = (s['start_time'] ?? '').toString();
              final endTime = (s['end_time'] ?? '').toString();
              final halvingLevel = s['halving_level']?.toString() ?? '0';

              final startShort = startTime.length >= 16
                  ? startTime.substring(0, 16).replaceFirst('T', ' ')
                  : startTime;
              final endShort = endTime.length >= 16
                  ? endTime.substring(0, 16).replaceFirst('T', ' ')
                  : (endTime.isEmpty ? '—' : endTime);

              final statusColor = isCompleted
                  ? okxGreen
                  : status == 'active'
                  ? okxBlue
                  : okxMuted;
              final statusLabel = isCompleted
                  ? _wt('credited')
                  : status == 'active'
                  ? _wt('in_progress')
                  : status;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: okxCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: okxBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor.withValues(alpha: 0.12),
                      ),
                      child: Center(
                        child: Text(
                          '#$sessionNum',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isCompleted
                                    ? '+${reward.toStringAsFixed(4)} ANET'
                                    : status == 'active'
                                    ? 'Mining…'
                                    : '0 ANET',
                                style: TextStyle(
                                  color: isCompleted ? okxGreen : okxMuted,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_wt('start')}: $startShort',
                            style: TextStyle(color: okxMuted, fontSize: 11),
                          ),
                          Text(
                            '${_wt('end')}:   $endShort',
                            style: TextStyle(color: okxMuted, fontSize: 11),
                          ),
                          if (isCompleted)
                            Text(
                              '${_wt('halving_level')}: $halvingLevel',
                              style: TextStyle(
                                color: okxMuted.withValues(alpha: 0.7),
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            });
          }(),
          if (_miningSessionOldestOffset > 0) ...[
            const SizedBox(height: 6),
            Center(
              child: TextButton.icon(
                onPressed: _miningSessionHistoryLoadingMore
                    ? null
                    : _loadOlderMiningSessions,
                icon: _miningSessionHistoryLoadingMore
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: okxBlue,
                        ),
                      )
                    : Icon(Icons.history_rounded, size: 16, color: okxBlue),
                label: Text(
                  _miningSessionHistoryLoadingMore
                      ? _wt('loading_older_sessions')
                      : _wt('load_older_sessions'),
                  style: TextStyle(
                    color: okxBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _announcementCard({
    required IconData icon,
    required Color iconColor,
    required Color borderColor,
    required String title,
    required String body,
    required String note,
    required String actionText,
    VoidCallback? onActionTap,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A0A00), Color(0xFF2A1200)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor.withValues(alpha: 0.75),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: borderColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: iconColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  note,
                  style: const TextStyle(
                    color: Color(0xFFCCB98A),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onActionTap,
                  child: Text(
                    actionText,
                    style: TextStyle(
                      color: onActionTap == null
                          ? const Color(0xFF3FE892)
                          : const Color(0xFF68D2FF),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      height: 1.35,
                      decoration: onActionTap == null
                          ? TextDecoration.none
                          : TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionProfileRow({
    required String label,
    required String value,
    required Color muted,
    required Color textPrimary,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: muted, fontSize: 12)),
          Text(
            value,
            style: TextStyle(
              color: textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Small inline action button used in token rows
  Widget _okxMiniBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ERC-20 P2P Send dialog — signs and broadcasts real on-chain transfer
  Future<void> _showSendEvmTokenDialog(Map<String, String> coin) async {
    if (_isAnetNativeNetwork(_selectedEvmNetwork)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ANET Native L1 uses native chain transfer flow. Switch to an EVM network to send ERC-20 tokens.',
          ),
        ),
      );
      return;
    }

    final name = coin['name'] ?? '';
    final symbol = coin['symbol'] ?? '';
    final contract = coin['contract'] ?? '';
    final decimals = int.tryParse(coin['decimals'] ?? '18') ?? 18;
    final toCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    bool submitting = false;
    String localMessage = '';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setLocalState) => AlertDialog(
          backgroundColor: const Color(0xFF0A0C1B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1677FF).withValues(alpha: 0.14),
                  border: Border.all(
                    color: const Color(0xFF1677FF).withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Color(0xFF1677FF),
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Send $symbol',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Token: $name ($symbol) on $_selectedEvmNetwork',
                  style: const TextStyle(
                    color: Color(0xFF7B829A),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: toCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Recipient address (0x…)',
                    labelStyle: TextStyle(color: Color(0xFF7B829A)),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF1E2440)),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF1677FF)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Amount ($symbol)',
                    labelStyle: const TextStyle(color: Color(0xFF7B829A)),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF1E2440)),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF1677FF)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: pinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Wallet PIN',
                    labelStyle: TextStyle(color: Color(0xFF7B829A)),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF1E2440)),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF1677FF)),
                    ),
                    counterText: '',
                  ),
                ),
                if (localMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      localMessage,
                      style: TextStyle(
                        color: localMessage.startsWith('✅')
                            ? const Color(0xFF25C474)
                            : Colors.orangeAccent,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: Text(
                context.l10n.cancelButton,
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final to = toCtrl.text.trim();
                      final amountStr = amountCtrl.text.trim();
                      final pin = pinCtrl.text.trim();

                      // Validate recipient
                      if (!RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(to)) {
                        setLocalState(
                          () => localMessage =
                              'Invalid recipient address (must be 0x…)',
                        );
                        return;
                      }
                      final parsedAmount = double.tryParse(amountStr);
                      if (parsedAmount == null || parsedAmount <= 0) {
                        setLocalState(
                          () => localMessage = 'Enter a valid positive amount',
                        );
                        return;
                      }
                      if (pin.length < 4 || pin.length > 8) {
                        setLocalState(
                          () => localMessage = 'PIN must be 4–8 digits',
                        );
                        return;
                      }

                      setLocalState(() {
                        submitting = true;
                        localMessage = 'Verifying PIN…';
                      });

                      try {
                        // PIN verify
                        await verifyWalletPinAPI(pin);

                        setLocalState(
                          () => localMessage = 'Signing transaction…',
                        );

                        // Derive private key
                        final seed = createdSeedPhrase.trim();
                        if (seed.isEmpty ||
                            seed == 'Hidden for security' ||
                            seed == 'No wallet created yet') {
                          setLocalState(() {
                            submitting = false;
                            localMessage =
                                'Seed phrase unavailable. Re-open wallet.';
                          });
                          return;
                        }
                        final privKeyBytes = _deriveEvmPrivateKeyFromMnemonic(
                          seed,
                        );
                        final credentials = EthPrivateKey(privKeyBytes);

                        // Build amount in base units
                        final amountBase = BigInt.from(
                          parsedAmount *
                              BigInt.from(10).pow(decimals).toDouble(),
                        );

                        // ERC-20 transfer ABI
                        const erc20TransferAbi =
                            '[{"inputs":[{"name":"to","type":"address"},{"name":"amount","type":"uint256"}],"name":"transfer","outputs":[{"name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"}]';
                        final erc20 = DeployedContract(
                          ContractAbi.fromJson(erc20TransferAbi, 'ERC20'),
                          EthereumAddress.fromHex(contract),
                        );
                        final transferFn = erc20.function('transfer');

                        final rpcUrl = _rpcForNetwork(_selectedEvmNetwork);
                        final chainId = _chainIdForNetwork(_selectedEvmNetwork);
                        if (rpcUrl == null || chainId == null) {
                          setLocalState(() {
                            submitting = false;
                            localMessage =
                                'Selected network is native ANET L1. ERC-20 transfer is only available on EVM networks.';
                          });
                          return;
                        }

                        final web3 = Web3Client(rpcUrl, http.Client());
                        try {
                          final tx = Transaction.callContract(
                            contract: erc20,
                            function: transferFn,
                            parameters: [
                              EthereumAddress.fromHex(to),
                              amountBase,
                            ],
                            maxGas: 100000,
                          );
                          final txHash = await web3.sendTransaction(
                            credentials,
                            tx,
                            chainId: chainId,
                          );

                          if (!mounted) return;
                          setLocalState(() {
                            submitting = false;
                            localMessage =
                                '✅ Sent! TX: ${txHash.substring(0, 12)}…${txHash.substring(txHash.length - 6)}\n\nCheck on explorer to confirm.';
                          });
                          await _refreshCustomCoinBalances();
                          await _refreshCustomTokenActivity();
                        } finally {
                          web3.dispose();
                        }
                      } catch (e) {
                        final msg = e.toString();
                        setLocalState(() {
                          submitting = false;
                          localMessage =
                              'Error: ${msg.length > 100 ? msg.substring(0, 100) : msg}';
                        });
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF1677FF),
                      ),
                    )
                  : Text(
                      context.l10n.send,
                      style: TextStyle(
                        color: Color(0xFF1677FF),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );

    toCtrl.dispose();
    amountCtrl.dispose();
    pinCtrl.dispose();
  }

  Future<void> _promptWalletUnlock() async {
    if (!hasCreatedWallet) {
      return;
    }

    if (!walletPinEnabled) {
      await _showSetPinDialog();
      await _syncWalletFromServer();
      return;
    }

    final pinCtrl = TextEditingController();
    final pinFocus = FocusNode();
    String localMessage = '';
    bool localSubmitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setLocalState) => AlertDialog(
          backgroundColor: const Color(0xFF0A1224),
          title: Text(
            context.l10n.unlockWallet,
            style: TextStyle(color: Colors.cyanAccent),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your wallet PIN to open the L1 wallet page.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  FocusScope.of(dialogContext).requestFocus(pinFocus);
                },
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final pinBoxCount = pinCtrl.text.length > 6 ? 8 : 6;
                    const gap = 8.0;
                    final raw =
                        (constraints.maxWidth - ((pinBoxCount - 1) * gap)) /
                        pinBoxCount;
                    final boxSize = raw.clamp(34.0, 52.0).toDouble();

                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: List.generate(pinBoxCount, (index) {
                        final hasValue = index < pinCtrl.text.length;
                        return Container(
                          width: boxSize,
                          height: boxSize + 4,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: hasValue
                                  ? Colors.cyanAccent
                                  : Colors.white24,
                            ),
                          ),
                          child: Text(
                            hasValue ? '•' : '',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: boxSize * 0.46,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 0,
                height: 0,
                child: TextField(
                  controller: pinCtrl,
                  focusNode: pinFocus,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  enableInteractiveSelection: false,
                  showCursor: false,
                  onChanged: (_) => setLocalState(() {}),
                  decoration: InputDecoration(counterText: ''),
                ),
              ),
              if (localMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    localMessage,
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                context.l10n.cancelButton,
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: localSubmitting
                  ? null
                  : () async {
                      final pin = pinCtrl.text.trim();
                      if (pin.length < 4 || pin.length > 8) {
                        setLocalState(() {
                          localMessage = 'PIN must be 4 to 8 digits';
                        });
                        return;
                      }

                      setLocalState(() {
                        localSubmitting = true;
                        localMessage = '';
                      });

                      try {
                        await verifyWalletPinAPI(pin);
                        if (!mounted) return;
                        setState(() {
                          _walletUnlockedForSession = true;
                        });
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Wallet unlocked')),
                        );
                      } catch (e) {
                        setLocalState(() {
                          localMessage = e.toString().replaceFirst(
                            'Exception: ',
                            '',
                          );
                        });
                      } finally {
                        setLocalState(() {
                          localSubmitting = false;
                        });
                      }
                    },
              child: Text(
                localSubmitting ? 'Checking...' : 'Unlock',
                style: const TextStyle(color: Colors.cyanAccent),
              ),
            ),
          ],
        ),
      ),
    );

    pinFocus.dispose();
    pinCtrl.dispose();
  }

  String _shortWalletAddress(String input) {
    final text = input.trim();
    if (text.length <= 14) {
      return text;
    }
    return '${text.substring(0, 6)}...${text.substring(text.length - 4)}';
  }

  Widget _walletCircleAction({
    required String label,
    required IconData icon,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Ink(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.18),
              border: Border.all(
                color: accent.withValues(alpha: 0.8),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: accent, size: 24),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _showWalletComingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label will be enabled in the next wallet release.'),
      ),
    );
  }

  Widget web4SlidePage() {
    final antsPerAnetNum = network == null
        ? 100000000
        : (int.tryParse((network!['antsPerAnet'] ?? 100000000).toString()) ??
              100000000);
    final rewardPerSessionNum = network == null
        ? 0.0
        : (double.tryParse(
                (network!['rewardPerSession'] ?? network!['currentRate'] ?? 0)
                    .toString(),
              ) ??
              0.0);
    final rewardPerSessionAnts = network == null
        ? (rewardPerSessionNum * antsPerAnetNum).floor()
        : (int.tryParse((network!['rewardPerSessionAnts'] ?? 0).toString()) ??
              (rewardPerSessionNum * antsPerAnetNum).floor());
    final profile = _myProfile ?? const {};
    final referralStats = _myReferralStats ?? const {};
    final dashboardCompletedSessions =
        int.tryParse((_dashboardData?['completed_sessions'] ?? 0).toString()) ??
        0;
    final successfulSessions =
        int.tryParse(
          (referralStats['mySuccessfulSessions'] ??
                  profile['successful_sessions'] ??
                  0)
              .toString(),
        ) ??
        0;
    final displayedSessions = dashboardCompletedSessions > 0
        ? dashboardCompletedSessions
        : successfulSessions;
    final migrationTarget =
        int.tryParse(
          (referralStats['levelTargetSessions'] ?? 1000).toString(),
        ) ??
        1000;
    final migrationProgress = migrationTarget <= 0
        ? 0.0
        : (displayedSessions / migrationTarget).clamp(0, 1).toDouble();
    final rawProgressPercent = migrationProgress * 100;
    final progressPercent = displayedSessions > 0 && rawProgressPercent < 0.01
        ? 0.01
        : rawProgressPercent;
    final migrationPercentText = progressPercent.toStringAsFixed(2);
    final estimatedAnet = walletTrackedAnts / antsPerAnetNum;
    final trackedAntsText = '$walletTrackedAnts ANTS tracked';
    final remainingSessions = max(migrationTarget - displayedSessions, 0);
    final badge =
        _dashboardData?['badge']?.toString() ??
        (displayedSessions >= 1000
            ? 'Qualified'
            : displayedSessions >= 500
            ? 'Advanced'
            : displayedSessions >= 100
            ? 'Consistent'
            : displayedSessions >= 1
            ? 'Beginner'
            : 'Starter');
    final level = int.tryParse((_dashboardData?['level'] ?? 1).toString()) ?? 1;

    return _themedStage(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _staggeredReveal(
              order: 0,
              child: Column(
                children: [
                  _tabHero(
                    title: 'Web4 Integration Layer',
                    subtitle:
                        'A clearer product view of how Web2 accounting, Web3 visibility, and the live ANET Layer 1 private/enclosed mainnet fit together.',
                    icon: Icons.hub_rounded,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _signalPill('Three Economies, One Ecosystem'),
                      _signalPill(
                        'Layer 1 private/enclosed mainnet live',
                        color: _themeAccentAlt,
                      ),
                      _signalPill('2s settlement windows', color: _themeLime),
                      _signalPill(
                        'Badge $badge · Level $level',
                        color: _themeGold,
                      ),
                      _signalPill(trackedAntsText, color: _themeLime),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _staggeredReveal(
              order: 1,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  buildActionButton(
                    'Open Live Explorer',
                    () => openLinkInsideApp(
                      context,
                      '$_anetExplorerUrl/explorer',
                    ),
                    compact: true,
                    icon: Icons.travel_explore_rounded,
                  ),
                  buildActionButton(
                    'Open Web4 Page',
                    () => openLinkInsideApp(context, _anetWeb4Url),
                    compact: true,
                    icon: Icons.language_rounded,
                  ),
                  buildActionButton(
                    'Open DEX',
                    () => _openDexWithPinGate(context),
                    compact: true,
                    icon: Icons.currency_exchange_rounded,
                  ),
                  buildActionButton(
                    'Bridge to BSC',
                    () => _openBridgeBurnWithPinGate(context),
                    compact: true,
                    icon: Icons.swap_horiz_rounded,
                  ),
                  buildActionButton(
                    'Open NFT Page',
                    () => openLinkInsideApp(context, _anetNftUrl),
                    compact: true,
                    icon: Icons.emoji_objects_rounded,
                  ),
                  buildActionButton(
                    'Open Web5 Page',
                    () => openLinkInsideApp(context, _anetWeb5Url),
                    compact: true,
                    icon: Icons.groups_rounded,
                  ),
                  buildActionButton(
                    'My Ant Link',
                    _showAntLinkActions,
                    compact: true,
                    icon: Icons.link_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _staggeredReveal(
              order: 2,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  buildActionButton(
                    'Generate Wallet',
                    createWallet,
                    compact: true,
                    icon: Icons.add_card_rounded,
                  ),
                  buildActionButton(
                    'Set Migration Wallet',
                    _setMigrationAddress,
                    compact: true,
                    icon: Icons.account_tree_rounded,
                  ),
                  buildActionButton(
                    'Copy Address',
                    () {
                      final value = hasCreatedWallet
                          ? createdWalletAddress
                          : walletAddress;
                      _copyText(value, 'Wallet address');
                    },
                    compact: true,
                    icon: Icons.copy_rounded,
                  ),
                  buildActionButton(
                    'View Seed',
                    _showSeedPhraseDialog,
                    compact: true,
                    icon: Icons.key_rounded,
                  ),
                  buildActionButton(
                    walletPinEnabled ? 'Change PIN' : 'Set PIN',
                    () => _showSetPinDialog(isChange: walletPinEnabled),
                    compact: true,
                    icon: Icons.lock_outline_rounded,
                  ),
                  buildActionButton(
                    'Delete Account',
                    _requestAccountDelete,
                    compact: true,
                    icon: Icons.delete_forever_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _staggeredReveal(
              order: 3,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: _panelDecoration(emphasis: true),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Migration Readiness',
                      style: TextStyle(
                        color: _themeAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You are $migrationPercentText% toward migration eligibility.',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: migrationProgress,
                        minHeight: 11,
                        backgroundColor: Colors.white.withValues(alpha: 0.10),
                        valueColor: AlwaysStoppedAnimation<Color>(_themeAccent),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        metricCard(
                          'Estimated ANET',
                          estimatedAnet.toStringAsFixed(8),
                        ),
                        metricCard(
                          'Successful Sessions',
                          '$displayedSessions / $migrationTarget',
                        ),
                        metricCard('Sessions Remaining', '$remainingSessions'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      remainingSessions == 0
                          ? 'Migration threshold reached. Your account is positioned for future conversion events.'
                          : '$remainingSessions more sessions are needed to hit the current migration threshold.',
                      style: TextStyle(
                        color: remainingSessions == 0 ? _themeLime : _themeGold,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _staggeredReveal(
              order: 4,
              child: _insightCard(
                title: 'Network Summary',
                body:
                    'Every completed 6-hour session credits $rewardPerSessionAnts ANTS under the current distribution stage. ANTS remain the live ledger unit, while ANET is the settlement unit. The live Layer 1 private/enclosed mainnet records settlement activity in event-driven windows instead of forcing empty blocks.',
                icon: Icons.insights_rounded,
                accent: _themeAccentAlt,
              ),
            ),
            const SizedBox(height: 14),
            _staggeredReveal(
              order: 5,
              child: _insightCard(
                title: 'Architecture Stack',
                body:
                    'Web2 Ant Work ledger -> Web3 BNB Chain visibility -> Web4 ANET Layer 1 private/enclosed mainnet settlement. Web2 and Web3 are active today, and the Layer 1 private/enclosed mainnet now runs live event-driven settlement windows while migration and claim bridges remain staged.',
                icon: Icons.account_tree_outlined,
              ),
            ),
            const SizedBox(height: 14),
            _staggeredReveal(
              order: 6,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: min(360.0, MediaQuery.of(context).size.width - 40),
                    child: _insightCard(
                      title: 'Economy A · Web2',
                      body:
                          'Runs inside app services: missions, activity, engagement, utility distributions, analytics, and the session production layer that accumulates ANTS.',
                      icon: Icons.phone_android_rounded,
                    ),
                  ),
                  SizedBox(
                    width: min(360.0, MediaQuery.of(context).size.width - 40),
                    child: _insightCard(
                      title: 'Economy B · Web3',
                      body:
                          'Runs on BNB Chain as a visibility and transparency layer only. It should not be presented as the same thing as mined ANET until a verified claim or settlement bridge exists.',
                      icon: Icons.public_rounded,
                      accent: _themeAccentAlt,
                    ),
                  ),
                  SizedBox(
                    width: min(360.0, MediaQuery.of(context).size.width - 40),
                    child: _insightCard(
                      title: 'Economy C · Web4',
                      body:
                          'Own Layer 1 private/enclosed mainnet where ANTS becomes native to transaction fees, miner payouts, activated supply accounting, and long-term chain economics. It already produces event-driven settlement blocks, while production bridge rules are still staged.',
                      icon: Icons.hub_outlined,
                      accent: _themeLime,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _staggeredReveal(
              order: 7,
              child: _insightCard(
                title: 'Participation Standard',
                body:
                    'A-Network is a long-term ecosystem build, not a short-term promise engine. This presentation is intended to clarify the roadmap, risks, and current implementation stage without overstating what is already live.',
                icon: Icons.gavel_rounded,
                warm: true,
              ),
            ),
            const SizedBox(height: 14),
            _staggeredReveal(
              order: 8,
              child: _insightCard(
                title: 'Current Status',
                body:
                    'Web2 and Web3 economies are active today, and the ANET Layer 1 private/enclosed mainnet is live with event-driven settlement windows. Production bridge actions, audited conversion rules, and store-release migration flows remain staged for later rollout.',
                icon: Icons.rocket_launch_rounded,
                accent: _themeAccent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Swipe left for Web5 and the full whitepaper, privacy, and policy views',
              style: TextStyle(color: _themeMutedText.withValues(alpha: 0.8)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget morePage() {
    final screenWidth = MediaQuery.of(context).size.width;
    final compact = screenWidth < 720;
    return _themedStage(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _glassPanel(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.morePageTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.l10n.morePageSubtitle,
                              style: TextStyle(
                                color: _themeMutedText,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _infoIconButton(
                        title: context.l10n.morePageTitle,
                        body:
                            'This screen centralizes settings and support surfaces only. Lower-value repetition has been removed so users can reach security, legal, support, and theme controls faster.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _signalPill(_displayThemeLabel),
                      _signalPill('English', color: _themeAccentAlt),
                      _signalPill('Support Ready', color: _themeLime),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _menuSection('ACCOUNT'),
            _menuGridRow([
              _menuCard(
                Icons.person_outline,
                'Profile',
                'Identity and rank',
                () {
                  _showProfileDetailsDialog();
                },
                infoText:
                    'Profile shows your current account identity, rank, and linked wallet context used across the ecosystem.',
              ),
              _menuCard(
                Icons.shield_rounded,
                'Security',
                'Ownership and recovery',
                () {
                  _showSecurityOwnershipDialog();
                },
                infoText:
                    'Security explains the ownership model: your verified email plus wallet details form the core access path for account recovery and future migration checks.',
              ),
            ]),
            _menuGridRow([
              _menuCard(
                Icons.link_rounded,
                'My Ant Link',
                'Shareable invite links',
                () {
                  _showAntLinkActions();
                },
                infoText:
                    'Open, copy, and share your Ant Code invitation links for Google and APK users.',
              ),
              _menuCard(
                Icons.group_add_rounded,
                'Referrals',
                'Colony tracker',
                () {
                  _showReferralTrackerDialog();
                },
                infoText:
                    'Referrals are tracked for colony growth only. The live model does not grant coin bonuses or session credits. Every ANET must be accumulated through completed Ant Work sessions.',
              ),
            ]),
            const SizedBox(height: 18),
            _menuSection('SUPPORT & INFO'),
            _menuGridRow([
              _menuCard(
                Icons.chat_bubble_outline,
                'Support',
                'AI help and guidance',
                () {
                  _openSupportAI();
                },
              ),
              _menuCard(
                Icons.info_outline_rounded,
                'About',
                'Project and operator info',
                () {
                  _showAboutDialog();
                },
                infoText:
                    'About summarizes the live network model, operator details, distribution structure, and roadmap direction for the current production release.',
                onLongPress: () => showTreasuryAdminGate(context),
              ),
            ]),
            _menuGridRow([
              _menuCard(
                Icons.description_rounded,
                'Terms',
                'Service terms',
                () {
                  unawaited(openLinkInsideApp(context, _termsUri.toString()));
                },
              ),
              _menuCard(
                Icons.privacy_tip_rounded,
                'Privacy',
                'Privacy policy',
                () {
                  unawaited(
                    openLinkInsideApp(context, _privacyPolicyUri.toString()),
                  );
                },
              ),
            ]),
            const SizedBox(height: 18),
            _menuSection(context.l10n.morePageTitle.toUpperCase()),
            _menuGridRow([
              _menuCard(
                Icons.notifications_none_rounded,
                'Notifications',
                'Alert settings',
                () {
                  _showNotificationsDialog();
                },
                infoText:
                    'Notifications help you finish Ant Work on time and stay aware of important ecosystem events. Reliable delivery depends on device notification and battery settings.',
              ),
              _menuCard(
                Icons.dark_mode_rounded,
                'Theme',
                _displayThemeLabel,
                () {
                  _showThemeDialog();
                },
                infoText:
                    'Theme lets you switch between Classic, ANTS, and Studio Light presentations while keeping the same network data and workflow.',
              ),
            ]),
            _menuGridRow([
              _menuCard(
                Icons.language_rounded,
                'Language',
                appLanguageLabel(_appLanguageNotifier.value),
                () {
                  _showLanguageDialog();
                },
                infoText:
                    'Switch language manually or use auto-region mode for India, Pakistan, China, and English fallback.',
              ),
              _menuCard(
                Icons.account_balance_wallet_rounded,
                context.l10n.walletMenuLabel,
                context.l10n.walletMenuSubtitle,
                () {
                  _pageController.jumpToPage(2);
                },
                infoText:
                    'Wallet opens your ANET balance and Web3 tools, which bridge internal ANTS accounting with future on-chain visibility.',
              ),
            ]),

            const SizedBox(height: 20),

            // Log Out Button
            GestureDetector(
              onTap: _showLogoutConfirmation,
              child: _glassPanel(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.red.withValues(alpha: 0.15),
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.logoutButton,
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Securely sign out from your account',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white30),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _menuSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.cyanAccent,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _menuGridRow(List<Widget> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children:
            items
                .map((item) => Expanded(child: item))
                .toList()
                .expand((w) => [w, const SizedBox(width: 10)])
                .toList()
              ..removeLast(),
      ),
    );
  }

  Widget _menuCard(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    String? infoText,
    VoidCallback? onLongPress,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: _glassPanel(
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            if (infoText != null)
              Positioned(
                top: 0,
                right: 0,
                child: _infoIconButton(title: title, body: infoText),
              ),
            Column(
              spacing: 8,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.cyanAccent.withValues(alpha: 0.1),
                  ),
                  child: Icon(icon, color: Colors.cyanAccent, size: 22),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLogoutConfirmation() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1224),
        title: const Text(
          'Log Out?',
          style: TextStyle(color: Colors.redAccent, fontSize: 18),
        ),
        content: const Text(
          'Are you sure you want to log out? You\'ll need to log in again to access your account.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.l10n.cancelButton,
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _logout();
            },
            child: const Text(
              'Log Out',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthPage()),
      (_) => false,
    );
  }

  Widget whitepaperSlidePage() {
    return _themedStage(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _wt('wp_title'),
              style: const TextStyle(
                color: Colors.cyanAccent,
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _wt('wp_version'),
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orangeAccent.withValues(alpha: 0.45),
                ),
              ),
              child: Text(
                _wt('wp_risk_notice'),
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _whitepaperBlock(_wt('wp_1_title'), _wt('wp_1_body')),
            _whitepaperBlock(_wt('wp_2_title'), _wt('wp_2_body')),
            _whitepaperBlock(_wt('wp_3_title'), _wt('wp_3_body')),
            _whitepaperBlock(_wt('wp_4_title'), _wt('wp_4_body')),
            _whitepaperBlock(_wt('wp_5_title'), _wt('wp_5_body')),
            _whitepaperBlock(_wt('wp_6_title'), _wt('wp_6_body')),
            _whitepaperBlock(_wt('wp_7_title'), _wt('wp_7_body')),
            _whitepaperBlock(_wt('wp_8_title'), _wt('wp_8_body')),
            _whitepaperBlock(_wt('wp_9_title'), _wt('wp_9_body')),
            _whitepaperBlock(_wt('wp_10_title'), _wt('wp_10_body')),
            _whitepaperBlock(_wt('wp_11_title'), _wt('wp_11_body')),
            _whitepaperBlock(_wt('wp_12_title'), _wt('wp_12_body')),
            _whitepaperBlock(_wt('wp_13_title'), _wt('wp_13_body')),
            _whitepaperBlock(_wt('wp_14_title'), _wt('wp_14_body')),
            _whitepaperBlock(_wt('wp_15_title'), _wt('wp_15_body')),
            _whitepaperBlock(_wt('wp_16_title'), _wt('wp_16_body')),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                buildActionButton(
                  _wt('wp_open_privacy'),
                  () => openLegalPage(_privacyPolicyUri, 'Privacy Policy'),
                ),
                buildActionButton(
                  _wt('wp_open_terms'),
                  () => openLegalPage(_termsUri, 'Terms of Service'),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget web5SlidePage() {
    final transferSourceWallet = hasCreatedWallet
        ? createdWalletAddress
        : walletAddress;
    final copyAddressValue = transferSourceWallet.trim();

    return _themedStage(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _staggeredReveal(
              order: 0,
              child: _tabHero(
                title: _wt('col_title'),
                subtitle: _wt('col_subtitle'),
                icon: Icons.groups_rounded,
              ),
            ),
            const SizedBox(height: 14),
            _staggeredReveal(
              order: 1,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  buildActionButton(
                    _wt('col_worker_transfer'),
                    () => _openWorkerTransfer(fromWallet: transferSourceWallet),
                    compact: true,
                    icon: Icons.swap_horiz_rounded,
                  ),
                  buildActionButton(
                    _wt('col_copy_address'),
                    () {
                      if (copyAddressValue.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No wallet address available yet.'),
                          ),
                        );
                        return;
                      }
                      _copyText(copyAddressValue, 'Wallet address');
                    },
                    compact: true,
                    icon: Icons.copy_rounded,
                  ),
                  buildActionButton(
                    _wt('col_view_seed'),
                    _showSeedPhraseDialog,
                    compact: true,
                    icon: Icons.key_rounded,
                  ),
                  buildActionButton(
                    walletPinEnabled
                        ? _wt('col_change_pin')
                        : _wt('col_set_pin'),
                    () => _showSetPinDialog(isChange: walletPinEnabled),
                    compact: true,
                    icon: Icons.lock_outline_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _staggeredReveal(
              order: 2,
              child: _whitepaperBlock(
                _wt('col_quick_access_title'),
                _wt('col_quick_access_body'),
              ),
            ),
            const SizedBox(height: 14),
            _staggeredReveal(
              order: 3,
              child: const ReferralCommunityChatSection(),
            ),
            const SizedBox(height: 14),
            _staggeredReveal(
              order: 4,
              child: _whitepaperBlock(
                _wt('col_colony_access_title'),
                _wt('col_colony_access_body'),
              ),
            ),
            _staggeredReveal(
              order: 5,
              child: _whitepaperBlock(
                _wt('col_migration_title'),
                _wt('col_migration_body'),
              ),
            ),
            _staggeredReveal(
              order: 6,
              child: _whitepaperBlock(
                _wt('col_anet_core_title'),
                _wt('col_anet_core_body'),
              ),
            ),
            _staggeredReveal(
              order: 7,
              child: _whitepaperBlock(
                _wt('col_open_all_title'),
                _wt('col_open_all_body'),
              ),
            ),
            _staggeredReveal(
              order: 8,
              child: _whitepaperBlock(
                _wt('col_tracks_title'),
                _wt('col_tracks_body'),
              ),
            ),
            _staggeredReveal(
              order: 9,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orangeAccent.withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  _wt('col_roadmap_note'),
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _whitepaperBlock(String title, String body) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget miningPanel() {
    final screenWidth = MediaQuery.of(context).size.width;
    final compact = screenWidth < 430;
    final detailCardWidth = compact
        ? screenWidth - 28
        : min(280.0, (screenWidth - 60) / 2);
    final totalMinedNum = network == null
        ? 0.0
        : (double.tryParse(network!['totalMined'].toString()) ?? 0.0);
    final maxSupplyNum = network == null
        ? 21000000.0
        : (double.tryParse(network!['maxSupply'].toString()) ?? 21000000.0);
    final halvingSessions = network == null
        ? 3800000000
        : (int.tryParse(
                (network!['halvingInterval'] ??
                        network!['halvingRuleSessions'] ??
                        network!['halvingEligibilitySessions'])
                    .toString(),
              ) ??
              3800000000);
    final totalSessionsNum = network == null
        ? 0
        : (int.tryParse((network!['totalSessions'] ?? 0).toString()) ?? 0);
    final rewardPerSessionNum = network == null
        ? 0.0
        : (double.tryParse(
                (network!['rewardPerSession'] ?? network!['currentRate'] ?? 0)
                    .toString(),
              ) ??
              0.0);
    final antsPerAnetNum = network == null
        ? 100000000
        : (int.tryParse((network!['antsPerAnet'] ?? 100000000).toString()) ??
              100000000);
    final balanceAnts = (balance * antsPerAnetNum).floor();
    final rewardPerSessionAnts = network == null
        ? (rewardPerSessionNum * antsPerAnetNum).floor()
        : (int.tryParse((network!['rewardPerSessionAnts'] ?? 0).toString()) ??
              (rewardPerSessionNum * antsPerAnetNum).floor());
    final totalMinedAnts = network == null
        ? (totalMinedNum * antsPerAnetNum).floor()
        : (int.tryParse((network!['totalMinedAnts'] ?? 0).toString()) ??
              (totalMinedNum * antsPerAnetNum).floor());
    final maxSupplyAnts = network == null
        ? (maxSupplyNum * antsPerAnetNum).floor()
        : (int.tryParse((network!['maxSupplyAnts'] ?? 0).toString()) ??
              (maxSupplyNum * antsPerAnetNum).floor());
    final remainingSessionsToHalving = network == null
        ? 3800000000
        : (int.tryParse(
                (network!['remainingQualifiedUsersToNextLevel'] ??
                        network!['remainingSessionsToHalving'] ??
                        3800000000)
                    .toString(),
              ) ??
              3800000000);
    final nextHalvingTarget = network == null
        ? totalSessionsNum + remainingSessionsToHalving
        : (int.tryParse(
                (network!['nextLevelSessionsTarget'] ??
                        (totalSessionsNum + remainingSessionsToHalving))
                    .toString(),
              ) ??
              (totalSessionsNum + remainingSessionsToHalving));
    final nextRewardPerSessionNum = network == null
        ? rewardPerSessionNum
        : (double.tryParse(
                (network!['nextRewardPerSession'] ?? 0).toString(),
              ) ??
              rewardPerSessionNum);
    final nextRewardPerSessionAnts = network == null
        ? rewardPerSessionAnts
        : (int.tryParse(
                (network!['nextRewardPerSessionAnts'] ?? 0).toString(),
              ) ??
              rewardPerSessionAnts);

    final currentMinedText = '${totalMinedNum.toStringAsFixed(4)} ANET';
    final totalSupplyText = '${maxSupplyNum.toStringAsFixed(0)} ANET';
    final rewardPerSessionText =
        '${rewardPerSessionNum.toStringAsFixed(8)} ANET / session';
    final rewardPerSessionAntsText = '$rewardPerSessionAnts ANTS / session';
    final currentMinedAntsText = '${totalMinedAnts.toString()} ANTS';
    final totalSupplyAntsText = '${maxSupplyAnts.toString()} ANTS';
    final mineButtonLabel = isMining
        ? _wt('ant_work_running')
        : (isStartingMining ? _wt('starting') : _wt('start_ant_work'));
    final totalUsersText = (network?['totalUsers'] ?? 0).toString();
    final halvingStageText = (network?['halvingCount'] ?? 0).toString();
    final sessionStatusText = isMining
        ? formatTime(remainingSeconds)
        : _wt('ready');
    final sessionSupportText = isMining
        ? _wt('six_hour_session_active')
        : _wt('no_active_session');
    final halvingHeadline = remainingSessionsToHalving <= 0
        ? _wt('next_stage_unlocked')
        : '$remainingSessionsToHalving ${_wt('sessions_to_next_stage')}';
    final supplyProgress = maxSupplyNum <= 0
        ? 0.0
        : (totalMinedNum / maxSupplyNum).clamp(0.0, 1.0);
    final claimEligibilitySessions = 1000;

    return Stack(
      children: [
        Container(color: Colors.black.withValues(alpha: 0.6)),
        SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 22,
            vertical: 20,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _staggeredReveal(
                  order: 0,
                  child: _tabHero(
                    title: context.l10n.antWorkHeroTitle,
                    subtitle: context.l10n.antWorkHeroSubtitle,
                    icon: Icons.rocket_launch_rounded,
                  ),
                ),
                const SizedBox(height: 14),
                _staggeredReveal(
                  order: 1,
                  child: _glassPanel(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 14 : 18,
                      16,
                      compact ? 14 : 18,
                      16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sessionStatusText,
                                    style: TextStyle(
                                      color: isMining
                                          ? Colors.greenAccent
                                          : Colors.cyanAccent,
                                      fontSize: compact ? 28 : 34,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    sessionSupportText,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0E2745),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(
                                    0xFF4AB8FF,
                                  ).withValues(alpha: 0.25),
                                ),
                              ),
                              child: Text(
                                isMining ? _wt('live') : _wt('standby'),
                                style: TextStyle(
                                  color: isMining
                                      ? Colors.greenAccent
                                      : const Color(0xFF8EC9EE),
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _signalPill(
                              rewardPerSessionAntsText,
                              color: const Color(0xFFF2B948),
                            ),
                            _signalPill(
                              '\$ANET ${balance.toStringAsFixed(4)}',
                              color: const Color(0xFF6ACFFF),
                            ),
                            _signalPill(
                              '${_wt('halving_stage')} $halvingStageText',
                              color: const Color(0xFF7FE2BA),
                            ),
                            if (myRank != null && myRank!['rank'] != null)
                              _signalPill(
                                '${_wt('rank')} #${myRank!['rank']}',
                                color: const Color(0xFFFFC857),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _wt('supply_progress'),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '${(supplyProgress * 100).toStringAsFixed(3)}%',
                              style: const TextStyle(
                                color: Color(0xFF7DD6FF),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: supplyProgress,
                            minHeight: 8,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.08,
                            ),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF4AB8FF),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '$currentMinedText mined of $totalSupplyText max supply',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _staggeredReveal(
                  order: 2,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      buildActionButton(
                        mineButtonLabel,
                        startMining,
                        compact: true,
                        icon: Icons.play_arrow_rounded,
                        emphasized: true,
                        pulse: !isMining && !isStartingMining,
                      ),
                      buildActionButton(
                        _wt('refresh'),
                        loadAll,
                        compact: true,
                        icon: Icons.refresh_rounded,
                      ),
                      buildActionButton(
                        _wt('balance'),
                        getBalance,
                        compact: true,
                        icon: Icons.account_balance_wallet_rounded,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _staggeredReveal(
                  order: 3,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: detailCardWidth,
                        child: _miniStatCard(
                          icon: Icons.bolt_rounded,
                          title: _wt('session_output'),
                          value: rewardPerSessionNum.toStringAsFixed(8),
                          subtitle: rewardPerSessionAntsText,
                          subtitleColor: const Color(0xFFF2B948),
                        ),
                      ),
                      SizedBox(
                        width: detailCardWidth,
                        child: _miniStatCard(
                          icon: Icons.account_balance_wallet_rounded,
                          title: _wt('tracked_balance'),
                          value: balance.toStringAsFixed(4),
                          subtitle: '$balanceAnts ANTS ${_wt('tracked')}',
                          subtitleColor: const Color(0xFF6ACFFF),
                        ),
                      ),
                      SizedBox(
                        width: detailCardWidth,
                        child: _miniStatCard(
                          icon: Icons.groups_rounded,
                          title: _wt('network_scale'),
                          value: totalUsersText,
                          subtitle:
                              '$totalSessionsNum ${_wt('verified_sessions').toLowerCase()}',
                          subtitleColor: const Color(0xFF7FE2BA),
                        ),
                      ),
                      SizedBox(
                        width: detailCardWidth,
                        child: _miniStatCard(
                          icon: Icons.trending_up_rounded,
                          title: _wt('next_stage'),
                          value: remainingSessionsToHalving.toString(),
                          subtitle:
                              '${_wt('target')} $nextHalvingTarget ${_wt('sessions')}',
                          subtitleColor: const Color(0xFFFFC857),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _staggeredReveal(
                  order: 4,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: detailCardWidth,
                        child: _glassPanel(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _wt('session_rules'),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _signalPill(
                                _wt('validated_cycle_6h'),
                                color: const Color(0xFF6ACFFF),
                              ),
                              const SizedBox(height: 8),
                              _signalPill(
                                '$claimEligibilitySessions ${_wt('sessions_to_claim_anet')}',
                                color: const Color(0xFF7FE2BA),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _wt('rewards_tracked_ants_first'),
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: detailCardWidth,
                        child: _glassPanel(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _wt('network_rules'),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                halvingHeadline,
                                style: const TextStyle(
                                  color: Color(0xFFFFC857),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${_wt('next_output')}: ${nextRewardPerSessionNum.toStringAsFixed(8)} ANET / $nextRewardPerSessionAnts ANTS',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _wt('referrals_grow_colony_only'),
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _staggeredReveal(
                  order: 5,
                  child: _glassPanel(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _wt('supply_ledger'),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        stat(
                          _wt('global_mined'),
                          '$currentMinedText  |  $currentMinedAntsText',
                        ),
                        stat(
                          _wt('total_max_supply'),
                          '$totalSupplyText  |  $totalSupplyAntsText',
                        ),
                        stat(_wt('current_rate'), rewardPerSessionText),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget stat(String title, String value) {
    final compact = MediaQuery.of(context).size.width < 430;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$title:',
              style: TextStyle(
                color: Colors.white70,
                fontSize: compact ? 14 : 18,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 14 : 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSupportAI() async {
    final accessMode = await _showAiAccessPortal();
    if (accessMode == null || !mounted) {
      return;
    }

    if (accessMode == 'with_ads') {
      await AdsService.enableRuntime();
      await _showAiLoginAdIfDue();
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiSupportPage(loginWithAds: accessMode == 'with_ads'),
      ),
    );
  }

  Future<String?> _showAiAccessPortal() async {
    final pinCtrl = TextEditingController();
    String selectedMode = 'with_ads';
    bool submitting = false;
    String inlineError = '';

    final decision = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setLocalState) => AlertDialog(
          backgroundColor: const Color(0xFF0A1224),
          title: const Text(
            'AI Portal Login',
            style: TextStyle(
              color: Colors.cyanAccent,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Login using your wallet PIN. Choose ad-supported or no-ads access.',
                  style: TextStyle(color: Colors.white70, height: 1.35),
                ),
                const SizedBox(height: 12),
                RadioListTile<String>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: Colors.cyanAccent,
                  title: const Text(
                    'Login with ads',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Free access. Ad appears at most once every 6 hours.',
                    style: TextStyle(color: Colors.white54),
                  ),
                  value: 'with_ads',
                  groupValue: selectedMode,
                  onChanged: submitting
                      ? null
                      : (value) {
                          if (value == null) return;
                          setLocalState(() => selectedMode = value);
                        },
                ),
                RadioListTile<String>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: Colors.cyanAccent,
                  title: const Text(
                    'Login without ads',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Direct access for this session.',
                    style: TextStyle(color: Colors.white54),
                  ),
                  value: 'without_ads',
                  groupValue: selectedMode,
                  onChanged: submitting
                      ? null
                      : (value) {
                          if (value == null) return;
                          setLocalState(() => selectedMode = value);
                        },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 8,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: context.l10n.walletPINHint,
                    hintStyle: TextStyle(color: Colors.white54),
                    counterText: '',
                  ),
                ),
                if (inlineError.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      inlineError,
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: Text(
                context.l10n.cancelButton,
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final pin = pinCtrl.text.trim();
                      if (pin.length < 4 || pin.length > 8) {
                        setLocalState(() {
                          inlineError =
                              'Enter a valid wallet PIN (4 to 8 digits).';
                        });
                        return;
                      }

                      setLocalState(() {
                        submitting = true;
                        inlineError = '';
                      });

                      try {
                        await verifyWalletPinAPI(pin);
                        if (ctx.mounted) {
                          Navigator.pop(ctx, selectedMode);
                        }
                      } catch (e) {
                        if (!ctx.mounted) return;
                        final rawMessage = e.toString().trim();
                        final displayMessage =
                            rawMessage.startsWith('Exception: ')
                            ? rawMessage.substring('Exception: '.length)
                            : rawMessage;
                        setLocalState(() {
                          submitting = false;
                          inlineError = displayMessage.isEmpty
                              ? 'PIN verification failed. Please try again.'
                              : displayMessage;
                        });
                      }
                    },
              child: Text(
                submitting ? 'Verifying...' : 'Login',
                style: const TextStyle(color: Colors.cyanAccent),
              ),
            ),
          ],
        ),
      ),
    );

    pinCtrl.dispose();
    return decision;
  }

  Future<void> _showAiLoginAdIfDue() async {
    if (!AdsService.adsEnabled) {
      await AdsService.enableRuntime();
    }

    final prefs = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastShownMs = prefs.getInt(_aiLoginAdLastShownAtKey) ?? 0;
    final cooldownMs = const Duration(hours: 6).inMilliseconds;

    if (nowMs - lastShownMs < cooldownMs) {
      return;
    }

    // Allow enough time for initial ad load on slower networks.
    final shown = await AdsService.showAiLoginInterstitialBestEffort().timeout(
      const Duration(seconds: 8),
      onTimeout: () => false,
    );
    if (shown) {
      await prefs.setInt(_aiLoginAdLastShownAtKey, nowMs);
    } else {
      unawaited(AdsService.loadInterstitialAd());
    }
  }

  Future<void> _openWorkerTransfer({String? fromWallet}) async {
    if (!await _ensureWalletDappEligibility(view: 'transfer')) {
      return;
    }
    final trimmedWallet = fromWallet?.trim() ?? '';
    final uri = Uri.parse('$_anetExplorerUrl/explorer').replace(
      queryParameters: trimmedWallet.isNotEmpty
          ? {'view': 'transfer', 'from': trimmedWallet}
          : {'view': 'transfer'},
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InAppBrowserPage(
          initialUrl: uri.toString(),
          title: 'Worker Transfer',
        ),
      ),
    );
  }

  Future<void> _showSendCoinDialog() async {
    if (!walletL1SendEnabled) {
      final migrationHint =
          migrationWalletAddress.trim().isNotEmpty &&
              migrationWalletAddress.trim().toLowerCase() != 'not set'
          ? '\nMigration wallet: $migrationWalletAddress'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Direct ANET L1 send is enabled only for upgraded wallets. '
            'Current scheme: $walletScheme.$migrationHint',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    final toCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    bool submitting = false;
    String localMessage = '';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setLocalState) => AlertDialog(
          backgroundColor: const Color(0xFF0A1224),
          title: const Text(
            'Withdraw Mined Coin',
            style: TextStyle(color: Colors.cyanAccent),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter destination wallet, amount, and your wallet PIN. Every eligible withdrawal must produce a blockchain record (transaction hash) to be treated as completed.',
                  style: TextStyle(color: Colors.white70, height: 1.35),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: toCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Destination ANET wallet',
                    hintStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Amount (ANET)',
                    hintStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 8,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: context.l10n.walletPINHint,
                    hintStyle: TextStyle(color: Colors.white54),
                    counterText: '',
                  ),
                ),
                if (localMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      localMessage,
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                context.l10n.cancelButton,
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final to = toCtrl.text.trim();
                      final amount = amountCtrl.text.trim();
                      final pin = pinCtrl.text.trim();

                      if (to.isEmpty) {
                        setLocalState(() {
                          localMessage = 'Destination wallet is required';
                        });
                        return;
                      }
                      final parsedAmount = double.tryParse(amount);
                      if (parsedAmount == null || parsedAmount <= 0) {
                        setLocalState(() {
                          localMessage = 'Enter a valid ANET amount';
                        });
                        return;
                      }
                      if (pin.length < 4 || pin.length > 8) {
                        setLocalState(() {
                          localMessage = 'PIN must be 4 to 8 digits';
                        });
                        return;
                      }

                      setLocalState(() {
                        submitting = true;
                        localMessage = '';
                      });

                      try {
                        setLocalState(() {
                          localMessage = 'Validating transfer intent...';
                        });
                        final data = await createWalletTransferIntentAPI(
                          pin: pin,
                          toAddress: to,
                          amountAnet: amount,
                        );
                        final transfer =
                            data['transfer'] as Map<String, dynamic>?;
                        final fromWallet =
                            transfer?['fromWallet']?.toString() ??
                            createdWalletAddress;
                        final toWallet =
                            transfer?['toWallet']?.toString() ?? to;
                        final amountValue =
                            transfer?['amountAnet']?.toString() ?? amount;

                        if (!RegExp(
                          r'^ANET[A-F0-9]{36}$',
                        ).hasMatch(fromWallet.trim().toUpperCase())) {
                          throw Exception(
                            'Source wallet is not a valid ANET address',
                          );
                        }
                        if (!RegExp(
                          r'^ANET[A-F0-9]{36}$',
                        ).hasMatch(toWallet.trim().toUpperCase())) {
                          throw Exception(
                            'Destination wallet must be a valid ANET address',
                          );
                        }

                        final amountAnts = _parseAnetAmountToAnts(amountValue);
                        if (amountAnts == null || amountAnts <= 0) {
                          throw Exception(
                            'Amount must be in valid ANET format (max 8 decimals)',
                          );
                        }

                        setLocalState(() {
                          localMessage = 'Unlocking signing seed...';
                        });

                        String seedPhrase = '';
                        if (_hasUsableLocalSeedPhrase()) {
                          seedPhrase = createdSeedPhrase.trim();
                        } else {
                          final reveal = await revealSeedAPI(pin);
                          seedPhrase =
                              reveal['seedPhrase']?.toString().trim() ?? '';
                          final localFallback =
                              reveal['localSeedFallback'] == true;
                          if (seedPhrase.isEmpty &&
                              localFallback &&
                              _hasUsableLocalSeedPhrase()) {
                            seedPhrase = createdSeedPhrase.trim();
                          }
                        }

                        if (!_hasUsableLocalSeedPhrase(seedPhrase)) {
                          throw Exception(
                            'Seed phrase is unavailable. Open wallet security and reveal seed first.',
                          );
                        }

                        final derivedWallet = _deriveLegacyAnetWalletFromSeed(
                          seedPhrase,
                        );
                        if (derivedWallet != fromWallet.trim().toUpperCase()) {
                          throw Exception(
                            'Wallet signing seed does not match your active ANET wallet',
                          );
                        }

                        final secpWallet = _deriveSecpAnetWalletFromSeed(
                          seedPhrase,
                        );
                        if (secpWallet != fromWallet.trim().toUpperCase()) {
                          throw Exception(
                            'Direct L1 signed send is not available for this wallet yet. '
                            'Your wallet is on legacy derivation and requires migration signing support.',
                          );
                        }

                        setLocalState(() {
                          localMessage = 'Signing and submitting to ANET L1...';
                        });

                        var nonce =
                            int.tryParse(
                              transfer?['nonce']?.toString() ?? '',
                            ) ??
                            1;
                        Map<String, dynamic>? broadcast;
                        Map<String, dynamic>? signedTx;

                        for (var attempt = 0; attempt < 2; attempt++) {
                          signedTx = _buildSignedAnetTransferTx(
                            seedPhrase: seedPhrase,
                            fromWallet: fromWallet,
                            toWallet: toWallet,
                            amountAnts: amountAnts,
                            nonce: nonce,
                            feeAnts: _minL1FeeAnts,
                            payload: const <String, dynamic>{},
                          );

                          try {
                            broadcast = await submitL1TransactionAPI(signedTx);
                            break;
                          } catch (e) {
                            final msg = e.toString().replaceFirst(
                              'Exception: ',
                              '',
                            );
                            final expectedNonce = _parseExpectedNonceFromError(
                              msg,
                            );
                            if (attempt == 0 &&
                                expectedNonce > 0 &&
                                expectedNonce != nonce) {
                              nonce = expectedNonce;
                              continue;
                            }
                            rethrow;
                          }
                        }

                        if (broadcast == null || signedTx == null) {
                          throw Exception('Transfer submit failed');
                        }

                        final txHash = signedTx['tx_hash']?.toString();
                        final referenceNo =
                            broadcast['transaction_id']?.toString() ??
                            transfer?['intentId']?.toString() ??
                            data['intentId']?.toString();
                        final status =
                            broadcast['status']?.toString() ?? 'queued';
                        final explorerUrl =
                            (txHash != null && txHash.trim().isNotEmpty)
                            ? '$_anetNativeExplorerTxBase${txHash.trim()}'
                            : null;
                        final feeValue = (signedTx['fee_ants'] is num)
                            ? ((signedTx['fee_ants'] as num) / _antsPerAnet)
                                  .toStringAsFixed(8)
                            : null;
                        final blockNumber =
                            broadcast['blockNumber']?.toString() ??
                            broadcast['block']?.toString();

                        if (!mounted) return;
                        Navigator.pop(ctx);
                        await _showWithdrawalReceiptDialog(
                          amountAnet: amountValue,
                          toWallet: toWallet,
                          status: status,
                          txHash: txHash,
                          blockNumber: blockNumber,
                          referenceNo: referenceNo,
                          feeAnet: feeValue,
                          explorerUrl: explorerUrl,
                        );
                        await _openWorkerTransferPrefilled(
                          fromWallet: fromWallet,
                          toWallet: toWallet,
                          amountAnet: amountValue,
                        );
                      } catch (e) {
                        setLocalState(() {
                          localMessage = e.toString().replaceFirst(
                            'Exception: ',
                            '',
                          );
                        });
                      } finally {
                        setLocalState(() {
                          submitting = false;
                        });
                      }
                    },
              child: Text(
                submitting ? 'Preparing...' : 'Submit Withdrawal',
                style: const TextStyle(color: Colors.cyanAccent),
              ),
            ),
          ],
        ),
      ),
    );

    toCtrl.dispose();
    amountCtrl.dispose();
    pinCtrl.dispose();
  }

  Future<void> _claimAnetNow({required int completedSessions}) async {
    if (completedSessions < 1000 && !sessionGateBypassEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Claim unlocks after 1,000 verified sessions. Progress: $completedSessions/1000',
          ),
        ),
      );
      return;
    }

    try {
      final result = await claimAnetAPI();
      final claimedAnet = (result['claimedAnet'] ?? 0).toString();
      final claimedAnts = (result['claimedAnts'] ?? 0).toString();

      if (!mounted) return;
      await _syncWalletFromServer();
      await _loadWalletCoinHistory();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Claim successful: $claimedAnet ANET ($claimedAnts ANTS converted)',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _openNftStudio({required int completedSessions}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NftIdentityScreen(
          walletAddress: createdWalletAddress,
          completedSessions: completedSessions,
          sessionGateBypassEnabled: sessionGateBypassEnabled,
        ),
      ),
    );
  }

  Future<void> _openPublicNftProfile({required String walletAddress}) async {
    if (walletAddress.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicNftProfilePage(walletAddress: walletAddress),
      ),
    );
  }

  Future<void> _openWorkerTransferPrefilled({
    required String fromWallet,
    required String toWallet,
    required String amountAnet,
  }) async {
    if (!await _ensureWalletDappEligibility(view: 'transfer')) {
      return;
    }
    final from = fromWallet.trim();
    final to = toWallet.trim();
    final amount = amountAnet.trim();

    final query = <String, String>{'view': 'transfer'};
    if (from.isNotEmpty) query['from'] = from;
    if (to.isNotEmpty) query['to'] = to;
    if (amount.isNotEmpty) query['amount'] = amount;

    final uri = Uri.parse(
      '$_anetExplorerUrl/explorer',
    ).replace(queryParameters: query);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InAppBrowserPage(
          initialUrl: uri.toString(),
          title: 'Withdraw Mined Coin',
        ),
      ),
    );
  }

  Future<void> _showWithdrawalReceiptDialog({
    required String amountAnet,
    required String toWallet,
    required String status,
    String? txHash,
    String? blockNumber,
    String? referenceNo,
    String? feeAnet,
    String? explorerUrl,
  }) async {
    final hash = txHash?.trim() ?? '';
    final block = blockNumber?.trim() ?? '';
    final reference = referenceNo?.trim() ?? '';
    final fee = feeAnet?.trim() ?? '';
    final explorer = explorerUrl?.trim() ?? '';
    final normalizedStatus = status.trim().isEmpty
        ? 'submitted'
        : status.trim().toLowerCase();
    final completed =
        normalizedStatus == 'completed' ||
        normalizedStatus == 'confirmed' ||
        hash.isNotEmpty;
    final shortHash = hash.length > 14
        ? '${hash.substring(0, 8)}...${hash.substring(hash.length - 4)}'
        : hash;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1224),
        title: const Text(
          'Withdrawal Receipt',
          style: TextStyle(color: Colors.cyanAccent),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    completed
                        ? Icons.check_circle_rounded
                        : Icons.schedule_rounded,
                    color: completed ? Colors.greenAccent : Colors.orangeAccent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    completed ? 'Status: Completed' : 'Status: Submitted',
                    style: TextStyle(
                      color: completed
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Amount: $amountAnet ANET',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                'Network: ANET L1',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                'Address: $toWallet',
                style: const TextStyle(color: Colors.white70),
              ),
              if (fee.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Network Fee: $fee ANET',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
              if (shortHash.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Transaction ID: $shortHash',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
              if (block.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Block: $block',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
              if (reference.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Reference No: $reference',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                completed
                    ? 'This withdrawal has a blockchain record and can be verified from the explorer.'
                    : 'Waiting for blockchain hash. The withdrawal is not treated as completed until chain record is available.',
                style: const TextStyle(color: Colors.white54, height: 1.3),
              ),
            ],
          ),
        ),
        actions: [
          if (hash.isNotEmpty)
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: hash));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Transaction ID copied'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text(
                'Copy TX ID',
                style: TextStyle(color: Colors.cyanAccent),
              ),
            ),
          if (explorer.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                openLinkInsideApp(context, explorer);
              },
              child: const Text(
                'View on Blockchain Explorer',
                style: TextStyle(color: Colors.lightGreenAccent),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.l10n.closeButton,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  int _currentDisplayedSessions() {
    final profile = _myProfile ?? const {};
    final referralStats = _myReferralStats ?? const {};
    final completed =
        int.tryParse((_dashboardData?['completed_sessions'] ?? 0).toString()) ??
        0;
    final successful =
        int.tryParse(
          (referralStats['mySuccessfulSessions'] ??
                  _dashboardData?['successful_sessions'] ??
                  profile['successful_sessions'] ??
                  0)
              .toString(),
        ) ??
        0;
    // Use the highest verified value from available sources to avoid false locks.
    return completed > successful ? completed : successful;
  }

  bool _requiresQualifiedSessionsForView(String view) {
    const gatedViews = <String>{
      'bridge',
      'swap',
      'cashout',
      'trade',
      'buy',
      'sell',
      'send',
      'receive',
      'transfer',
    };
    return gatedViews.contains(view.trim().toLowerCase());
  }

  Future<bool> _ensureWalletDappEligibility({required String view}) async {
    if (!_requiresQualifiedSessionsForView(view)) {
      return true;
    }
    final sessions = _currentDisplayedSessions();
    if (sessions >= 1000 || sessionGateBypassEnabled) {
      return true;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This action unlocks after 1,000 verified sessions. Current: $sessions/1000.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
    return false;
  }

  Future<void> _openWalletDapp({required String view}) async {
    if (!await _ensureWalletDappEligibility(view: view)) {
      return;
    }

    // Open native MetaMask-style EVM wallet hub for the bridge view.
    if (view == 'bridge') {
      await _openNativeEvmWallet();
      return;
    }

    final from = createdWalletAddress.trim();
    final uri = Uri.parse('$_anetExplorerUrl/explorer').replace(
      queryParameters: {
        'view': view,
        'network': _selectedEvmNetwork,
        if (from.isNotEmpty && from != 'Not created') 'from': from,
      },
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InAppBrowserPage(
          initialUrl: uri.toString(),
          title: 'ANTS Browser',
          walletExtensionMode: true,
          walletAddress: from,
          walletNetwork: _selectedEvmNetwork,
          walletSeedPhrase: createdSeedPhrase,
          walletPinRequired: walletPinEnabled,
          allowedHosts: _walletDappAllowlistHosts,
          strictHostBlocking: true,
        ),
      ),
    );
  }

  /// Opens the native MetaMask-style EVM wallet page.
  Future<void> _openNativeEvmWallet() async {
    // Load seed from secure storage to derive EVM credentials.
    String? seed = await loadWalletSeedSecure();
    if ((seed == null || seed.trim().isEmpty) &&
        createdSeedPhrase.trim().isNotEmpty &&
        createdSeedPhrase.trim() != 'Hidden for security' &&
        createdSeedPhrase.trim() != 'No wallet created yet') {
      seed = createdSeedPhrase.trim();
    }

    if (seed == null || seed.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wallet seed unavailable. Please re-open your wallet.'),
        ),
      );
      return;
    }

    Uint8List privKeyBytes;
    String evmAddress;
    try {
      privKeyBytes = _deriveEvmPrivateKeyFromMnemonic(seed.trim());
      evmAddress = EthPrivateKey(privKeyBytes).address.hexEip55;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to derive EVM key: $e')));
      return;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EvmWalletPage(
          anetAddress: createdWalletAddress.trim(),
          evmAddress: evmAddress,
          privKeyBytes: privKeyBytes,
          completedSessions: _currentDisplayedSessions(),
          sessionGateBypassEnabled: sessionGateBypassEnabled,
        ),
      ),
    );
  }

  Future<bool> _isRealEvmTokenContract({
    required String contractAddress,
    required String network,
  }) async {
    if (_isAnetNativeNetwork(network)) {
      return false;
    }

    final rpcUrl = _rpcForNetwork(network);
    if (rpcUrl == null) return false;

    final client = Web3Client(rpcUrl, http.Client());
    try {
      final address = EthereumAddress.fromHex(contractAddress);
      final code = await client.getCode(address);
      if (code.isEmpty) {
        return false;
      }

      const abi =
          '[{"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"stateMutability":"view","type":"function"}]';
      final contract = DeployedContract(
        ContractAbi.fromJson(abi, 'ERC20Check'),
        address,
      );
      final decimalsFn = contract.function('decimals');
      final result = await client.call(
        contract: contract,
        function: decimalsFn,
        params: const [],
      );
      return result.isNotEmpty;
    } catch (_) {
      return false;
    } finally {
      client.dispose();
    }
  }

  Future<void> _showAddCustomCoinDialog() async {
    final nameCtrl = TextEditingController();
    final symbolCtrl = TextEditingController();
    final contractCtrl = TextEditingController();
    final decimalsCtrl = TextEditingController(text: '18');
    String localMessage = '';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setLocalState) => AlertDialog(
          backgroundColor: const Color(0xFF0A1224),
          title: const Text(
            'Add Custom Coin',
            style: TextStyle(color: Colors.cyanAccent),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(hintText: 'Coin name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: symbolCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(hintText: 'Symbol (e.g. USDT)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: contractCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Contract address (0x...)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: decimalsCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Decimals (default 18)',
                  ),
                ),
                if (localMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      localMessage,
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                context.l10n.cancelButton,
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final symbol = symbolCtrl.text.trim().toUpperCase();
                final contract = contractCtrl.text.trim();
                final decimals = decimalsCtrl.text.trim();

                if (name.isEmpty || symbol.isEmpty || contract.isEmpty) {
                  setLocalState(() {
                    localMessage = 'Name, symbol, and contract are required';
                  });
                  return;
                }
                if (!RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(contract)) {
                  setLocalState(() {
                    localMessage = 'Contract must be a valid EVM address';
                  });
                  return;
                }
                final decimalsNum = int.tryParse(
                  decimals.isEmpty ? '18' : decimals,
                );
                if (decimalsNum == null ||
                    decimalsNum < 0 ||
                    decimalsNum > 36) {
                  setLocalState(() {
                    localMessage = 'Decimals must be a number between 0 and 36';
                  });
                  return;
                }

                final exists = _customCoins.any(
                  (c) =>
                      (c['contract'] ?? '').toLowerCase() ==
                      contract.toLowerCase(),
                );
                if (exists) {
                  setLocalState(() {
                    localMessage = 'This contract is already added';
                  });
                  return;
                }

                setLocalState(() {
                  localMessage =
                      'Validating contract on $_selectedEvmNetwork...';
                });

                final isReal = await _isRealEvmTokenContract(
                  contractAddress: contract,
                  network: _selectedEvmNetwork,
                );
                if (!isReal) {
                  setLocalState(() {
                    localMessage =
                        'This address is not a valid ERC-20 contract on $_selectedEvmNetwork';
                  });
                  return;
                }

                if (!mounted) return;
                setState(() {
                  _customCoins = [
                    ..._customCoins,
                    {
                      'name': name,
                      'symbol': symbol,
                      'contract': contract,
                      'decimals': decimalsNum.toString(),
                    },
                  ];
                });
                await _persistEvmWalletPrefs();
                await _refreshCustomCoinBalances();
                await _refreshCustomTokenActivity();
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
              },
              child: const Text(
                'Add',
                style: TextStyle(color: Colors.cyanAccent),
              ),
            ),
          ],
        ),
      ),
    );

    nameCtrl.dispose();
    symbolCtrl.dispose();
    contractCtrl.dispose();
    decimalsCtrl.dispose();
  }

  Future<void> _openWalletHistory({String? walletAddress}) async {
    final trimmedWallet = walletAddress?.trim() ?? '';
    final uri = Uri.parse('$_anetExplorerUrl/explorer').replace(
      queryParameters: trimmedWallet.isNotEmpty
          ? {'view': 'history', 'address': trimmedWallet}
          : {'view': 'history'},
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InAppBrowserPage(
          initialUrl: uri.toString(),
          title: 'Wallet History',
        ),
      ),
    );
  }

  Widget _tabHero({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return _glassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _themeAccent.withValues(alpha: 0.14),
            ),
            child: Icon(icon, color: _themeAccent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _themeAccent,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: _themeMutedText,
                    fontSize: 12.5,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedTab = _tabFromPageIndex(_pageIndex);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _pageTitleForIndex(_pageIndex),
                          style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _pageSubtitleForIndex(_pageIndex),
                          style: TextStyle(
                            color: _themeMutedText,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _themeTabShell,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: _themeAccentAlt.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Text(
                      '${_pageIndex + 1}/7',
                      style: TextStyle(
                        color: _themeTabSelectedLabel,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: _showCurrentPageInfo,
                    icon: Icon(Icons.info_outline_rounded, color: _themeAccent),
                    tooltip: 'About this page',
                  ),
                  IconButton(
                    onPressed: _showAccountSheet,
                    icon: Icon(Icons.person_outline, color: _themeAccent),
                    tooltip: context.l10n.profileSupport,
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: [
                  mainSlidePage(),
                  miningPanel(),
                  web3SlidePage(),
                  web4SlidePage(),
                  whitepaperSlidePage(),
                  web5SlidePage(),
                  morePage(),
                ],
              ),
            ),
            // Footer banner ad removed (Google AdSense/AdMob ban).
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: _themeTabShell,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _themeAccentAlt.withValues(alpha: 0.28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _themeBackground.withValues(alpha: 0.42),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _bottomTabItem(
                      icon: Icons.home_rounded,
                      label: context.l10n.tabEcosystem,
                      selected: selectedTab == 0,
                      onTap: () => _goToPage(0),
                    ),
                    _bottomTabItem(
                      icon: Icons.bolt_rounded,
                      label: context.l10n.tabAntWork,
                      selected: selectedTab == 1,
                      highlighted: true,
                      onTap: () => _goToPage(1),
                    ),
                    _bottomTabItem(
                      icon: Icons.account_balance_wallet_rounded,
                      label: context.l10n.tabWallet,
                      selected: selectedTab == 2,
                      onTap: () => _goToPage(2),
                    ),
                    _bottomTabItem(
                      icon: Icons.groups_rounded,
                      label: context.l10n.tabColony,
                      selected: selectedTab == 3,
                      onTap: () => _goToPage(5),
                    ),
                    _bottomTabItem(
                      icon: Icons.more_horiz_rounded,
                      label: context.l10n.tabMore,
                      selected: selectedTab == 4,
                      onTap: () => _goToPage(6),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomTabItem({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool highlighted = false,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: EdgeInsets.fromLTRB(6, highlighted ? 2 : 6, 6, 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: selected ? _themeTabSelectedFill : Colors.transparent,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  width: highlighted ? 42 : 34,
                  height: highlighted ? 42 : 34,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: selected
                        ? _themeTabSelectedFill
                        : (highlighted
                              ? _themeTabShell.withValues(alpha: 0.84)
                              : Colors.transparent),
                    border: Border.all(
                      color: selected
                          ? _themeAccentAlt.withValues(alpha: 0.55)
                          : Colors.transparent,
                    ),
                    boxShadow: selected || highlighted
                        ? [
                            BoxShadow(
                              color: _themeBackground.withValues(alpha: 0.30),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    icon,
                    size: highlighted ? 22 : 20,
                    color: selected ? _themeTabSelectedIcon : _themeTabIdleIcon,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected
                        ? _themeTabSelectedLabel
                        : _themeTabIdleLabel,
                    fontSize: highlighted ? 11.5 : 11,
                    fontWeight: selected || highlighted
                        ? FontWeight.w700
                        : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    timer?.cancel();
    _statsRefreshTimer?.cancel();
    _announcementTimer?.cancel();
    _mainVideoInitTimer?.cancel();
    _antWorkPulseController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    targetPriceController.dispose();
    webSearchController.dispose();
    _pageController.dispose();
    _announcementPageController.dispose();
    _mainVideoController.dispose();
    super.dispose();
  }
}

class _StaticHealthCard extends StatelessWidget {
  const _StaticHealthCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xCC08162B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF4AB8FF).withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF041022).withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_outlined, color: Color(0xFF6ACFFF), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'NETWORK HEALTH',
                  style: TextStyle(
                    color: Color(0xFF89A5C2),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'Stable',
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Live services and activity tracking online',
            style: TextStyle(
              color: Color(0xFF7FE2BA),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class NftStudioPage extends StatefulWidget {
  const NftStudioPage({
    super.key,
    required this.walletAddress,
    required this.completedSessions,
    required this.sessionGateBypassEnabled,
  });

  final String walletAddress;
  final int completedSessions;
  final bool sessionGateBypassEnabled;

  @override
  State<NftStudioPage> createState() => _NftStudioPageState();
}

class _NftStudioPageState extends State<NftStudioPage> {
  bool _loading = true;
  bool _minting = false;
  List<Map<String, dynamic>> _nfts = const [];

  @override
  void initState() {
    super.initState();
    _loadNfts();
  }

  Future<void> _loadNfts() async {
    setState(() => _loading = true);
    try {
      final data = await getMyNftsAPI();
      final list = (data['nfts'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList();
      if (!mounted) return;
      setState(() {
        _nfts = list;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _showMintDialog() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final imageCtrl = TextEditingController();
    String errorText = '';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setLocalState) => AlertDialog(
          backgroundColor: const Color(0xFF0A1224),
          title: const Text(
            'Mint NFT',
            style: TextStyle(color: Colors.cyanAccent),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLength: 120,
                  decoration: const InputDecoration(
                    hintText: 'NFT title',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: Colors.white),
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 1200,
                  decoration: const InputDecoration(
                    hintText: 'Describe your NFT',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: imageCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Image URL (optional)',
                  ),
                ),
                if (errorText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      errorText,
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _minting ? null : () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: _minting
                  ? null
                  : () async {
                      final title = titleCtrl.text.trim();
                      final description = descCtrl.text.trim();
                      final imageUrl = imageCtrl.text.trim();

                      if (title.length < 3 || title.length > 120) {
                        setLocalState(() {
                          errorText = 'Title must be 3 to 120 characters';
                        });
                        return;
                      }
                      if (description.length < 8 || description.length > 1200) {
                        setLocalState(() {
                          errorText =
                              'Description must be 8 to 1200 characters';
                        });
                        return;
                      }
                      if (imageUrl.isNotEmpty &&
                          !RegExp(
                            r'^https?://',
                            caseSensitive: false,
                          ).hasMatch(imageUrl)) {
                        setLocalState(() {
                          errorText =
                              'Image URL must start with http:// or https://';
                        });
                        return;
                      }

                      setLocalState(() {
                        errorText = '';
                      });
                      setState(() => _minting = true);

                      try {
                        await mintNftAPI(
                          title: title,
                          description: description,
                          imageUrl: imageUrl.isEmpty ? null : imageUrl,
                          metadata: {
                            'wallet': widget.walletAddress,
                            'sessions': widget.completedSessions,
                            'mintedAt': DateTime.now()
                                .toUtc()
                                .toIso8601String(),
                          },
                        );
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        await _loadNfts();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'NFT mint submitted and recorded on-chain activity',
                            ),
                            duration: Duration(seconds: 4),
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        setLocalState(() {
                          errorText = e.toString().replaceFirst(
                            'Exception: ',
                            '',
                          );
                        });
                      } finally {
                        if (mounted) {
                          setState(() => _minting = false);
                        }
                      }
                    },
              child: Text(
                _minting ? 'Minting...' : 'Mint',
                style: const TextStyle(color: Colors.cyanAccent),
              ),
            ),
          ],
        ),
      ),
    );

    titleCtrl.dispose();
    descCtrl.dispose();
    imageCtrl.dispose();
  }

  Widget _buildNftCard(Map<String, dynamic> nft) {
    final title = (nft['title'] ?? '').toString();
    final description = (nft['description'] ?? '').toString();
    final imageUrl = (nft['image_url'] ?? '').toString();
    final status = (nft['onchain_status'] ?? 'pending').toString();
    final action = (nft['onchain_action'] ?? 'ui_nft_mint').toString();
    final createdAt = (nft['created_at'] ?? '').toString();

    final statusColor = status == 'accepted'
        ? const Color(0xFF69E4A7)
        : status == 'failed'
        ? const Color(0xFFFF8A80)
        : const Color(0xFFFFD166);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF101A2F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1D2A47)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
          if (imageUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              imageUrl,
              style: const TextStyle(color: Color(0xFF7AC3FF), fontSize: 12),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'On-chain action: $action',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          if (createdAt.isNotEmpty)
            Text(
              'Minted: $createdAt',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canMint =
        widget.completedSessions >= 1000 || widget.sessionGateBypassEnabled;
    return Scaffold(
      backgroundColor: const Color(0xFF070E1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070E1F),
        elevation: 0,
        title: const Text('NFT Studio'),
        actions: [
          IconButton(
            onPressed: _loadNfts,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: canMint && !_minting ? _showMintDialog : null,
        backgroundColor: canMint
            ? const Color(0xFF1677FF)
            : const Color(0xFF36435F),
        label: Text(canMint ? 'Mint NFT' : 'Unlock at 1,000 sessions'),
        icon: const Icon(Icons.auto_awesome_rounded),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF101A2F),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1D2A47)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Native NFT Mint + L1 Activity Record',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Wallet: ${widget.walletAddress}',
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Completed sessions: ${widget.completedSessions}/1000${widget.sessionGateBypassEnabled ? ' (review bypass enabled)' : ''}',
                    style: TextStyle(
                      color: canMint
                          ? const Color(0xFF69E4A7)
                          : const Color(0xFFFFD166),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'My NFTs',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF1677FF),
                      ),
                    )
                  : _nfts.isEmpty
                  ? const Center(
                      child: Text(
                        'No NFTs minted yet.',
                        style: TextStyle(color: Colors.white60),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadNfts,
                      child: ListView.builder(
                        itemCount: _nfts.length,
                        itemBuilder: (context, index) =>
                            _buildNftCard(_nfts[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
