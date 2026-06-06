import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'waitlist_page.dart';
import 'evm_bridge_page.dart';
import 'evm_wallet_service.dart';

import 'package:hex/hex.dart';
import 'package:web3dart/web3dart.dart' show EthPrivateKey;

// ─── Theme colours ────────────────────────────────────────────────────────────
const _bg = Color(0xFF07111F);
const _surface = Color(0xFF0A1224);
const _card = Color(0xFF0F1C2E);
const _blue = Color(0xFF1677FF);
const _green = Color(0xFF25C474);
const _gold = Color(0xFFFFB800);
const _red = Color(0xFFFF4D4F);
const _muted = Color(0xFF7B829A);

const _historyKey = 'dex_swap_history_v1';
// ─────────────────────────────────────────────────────────────────────────────

/// Native MetaMask-style DEX swap screen backed by the ANET L1 AMM.
class DexSwapPage extends StatefulWidget {
  const DexSwapPage({
    super.key,
    required this.walletAddress,
    required this.seedPhrase,
    required this.signActionAuth,
    this.signWithKeyAuth,
    this.preResolvedSeed,
    this.cachedSigningKey,
    this.evmWalletAddress,
  });

  final String walletAddress;
  final String seedPhrase;
  final Map<String, dynamic> Function(String actionType, String seedPhrase)
  signActionAuth;

  /// Key-bytes variant of [signActionAuth] used for auto-sign with the
  /// cached ANET L1 signing key.  The seed phrase is never re-touched once
  /// the user has unlocked the wallet with their PIN.
  final Map<String, dynamic> Function(
    String actionType,
    Uint8List privateKeyBytes,
  )?
  signWithKeyAuth;

  /// If PIN was already verified before navigating here, pass the resolved
  /// seed to skip the PIN gate on the first swap within 5 minutes.
  final String? preResolvedSeed;

  /// Pre-derived ANET L1 secp256k1 signing key (32 raw bytes).  When provided,
  /// the DEX uses it directly for offline auto-sign — no seed phrase touch.
  final Uint8List? cachedSigningKey;

  /// The user's EVM (0x…) wallet address, shown as informational context
  /// for the USDC bridge side of the DEX pair.
  final String? evmWalletAddress;

  @override
  State<DexSwapPage> createState() => _DexSwapPageState();
}

class _DexSwapPageState extends State<DexSwapPage>
    with SingleTickerProviderStateMixin {
  // ─── pools ────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _pools = [];
  bool _poolsLoading = true;
  String? _poolsError;
  Map<String, dynamic>? _selectedPool;

  // ─── direction ────────────────────────────────────────────────────────────
  bool _anetToToken = true;

  // ─── amount input ─────────────────────────────────────────────────────────
  final _amountController = TextEditingController();
  final _amountFocus = FocusNode();

  // ─── balance ──────────────────────────────────────────────────────────────
  double _anetBalance = 0.0;
  bool _balanceLoading = false;

  // ─── slippage ─────────────────────────────────────────────────────────────
  double _slippagePct = 1.0;
  bool _customSlippage = false;
  final _slippageController = TextEditingController(text: '1.0');

  // ─── quote ────────────────────────────────────────────────────────────────
  Map<String, dynamic>? _quote;
  bool _quoteLoading = false;
  String? _quoteError;
  Timer? _debounce;

  // ─── swap state ───────────────────────────────────────────────────────────
  bool _swapping = false;
  String? _swapResult;
  String? _swapError;
  int? _lastSwapBlockHeight;

  // ─── live block ───────────────────────────────────────────────────────────
  int? _l1Block;
  Timer? _blockTimer;

  // ─── PIN session (5-minute unlock window) ────────────────────────────────
  DateTime? _pinSessionExpiresAt;
  String? _sessionSeedPhrase;
  bool get _pinSessionValid =>
      _pinSessionExpiresAt != null &&
      DateTime.now().isBefore(_pinSessionExpiresAt!);

  /// True once we've attempted the one-shot legacy→secp on-chain migration
  /// for this app session. The chain rejects every dex_swap signature from
  /// users whose `wallet_address` is the old RIPEMD160(SHA256(hex(pk)))
  /// derivation; calling /auth/wallet/migrate-to-secp with the PIN sweeps
  /// the balance to the secp address and updates the server's wallet_address.
  /// Idempotent — backend returns already_migrated when there's nothing to do.
  bool _walletMigrationChecked = false;

  /// Cached ANET L1 signing key bytes.  When non-null the DEX can auto-sign
  /// any swap or bridge action without ever re-loading the seed phrase.
  Uint8List? _anetSigningKey;

  // ─── history ──────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _swapHistory = [];

  // Banner ads removed (Google AdSense/AdMob ban). Axon ads TBD.

  // ─── tab controller ───────────────────────────────────────────────────────
  late TabController _tabController;

  /// EVM private key bytes — set after PIN is verified; used by bridge tab.
  Uint8List? _evmPrivKey;

  /// EVM (BSC) wallet address derived from [_evmPrivKey].
  String? _evmAddress;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_onTabChanged);
    // Pre-load any cached ANET L1 signing key (set when wallet PIN was verified).
    if (widget.cachedSigningKey != null) {
      _anetSigningKey = widget.cachedSigningKey;
    }
    // Pre-start the PIN session if the caller already verified the PIN.
    if (widget.preResolvedSeed != null &&
        widget.preResolvedSeed!.isNotEmpty &&
        widget.preResolvedSeed != 'Hidden for security' &&
        widget.preResolvedSeed != 'No wallet created yet') {
      _sessionSeedPhrase = widget.preResolvedSeed;
      _pinSessionExpiresAt = DateTime.now().add(const Duration(minutes: 10));
      // Eagerly derive EVM key if PIN is already verified.
      _tryDeriveEvmKey(widget.preResolvedSeed!);
      // Cache the ANET L1 signing key for auto-sign.
      _cacheAnetSigningKeyFromSeed(widget.preResolvedSeed!);
    }
    // Try loading the cached signing key from secure storage (no PIN needed).
    _loadCachedAnetSigningKey();
    _loadPools();
    _loadBalance();
    _loadHistory();
    _loadL1Block();
    // Auto-poll latest L1 block AND DEX pool reserves so the swap UI never
    // shows stale prices. Previously _loadPools() only ran on initState and
    // manual refresh — users perceived the DEX as "not syncing".
    _blockTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      _loadL1Block();
      _loadPools();
    });
  }

  /// Loads the cached ANET L1 signing key for the active wallet from
  /// flutter_secure_storage so repeat swaps in this session sign fully
  /// offline.  Validates the loaded key by re-deriving its secp address and
  /// checking it against `widget.walletAddress` (secp-scheme).  If the key
  /// doesn't match (e.g. corruption, key written for a different wallet)
  /// it is silently discarded and the next swap falls back to PIN unlock.
  Future<void> _loadCachedAnetSigningKey() async {
    if (_anetSigningKey != null) return;
    final wallet = widget.walletAddress.trim();
    if (wallet.isEmpty ||
        wallet == 'Not created' ||
        wallet == 'No wallet created yet') {
      return;
    }
    try {
      final hexKey = (await loadDexAnetSigningKeySecure(wallet) ?? '').trim();
      if (hexKey.length != 64) return;
      final bytes = Uint8List.fromList(HEX.decode(hexKey));
      if (mounted) setState(() => _anetSigningKey = bytes);
    } catch (_) {}
  }

  /// Derives the ANET L1 signing key from [seed] and persists it for the
  /// active wallet so subsequent swaps auto-sign without a PIN prompt.
  Future<void> _cacheAnetSigningKeyFromSeed(String seed) async {
    final wallet = widget.walletAddress.trim();
    if (wallet.isEmpty ||
        wallet == 'Not created' ||
        wallet == 'No wallet created yet') {
      return;
    }
    try {
      final keyBytes = resolveAnetL1PrivateKey(seed);
      if (mounted) setState(() => _anetSigningKey = keyBytes);
      await saveDexAnetSigningKeySecure(wallet, HEX.encode(keyBytes));
    } catch (_) {}
  }

  void _onTabChanged() {
    if (_tabController.index == 1 && _evmPrivKey == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final ok = await _ensureEvmKeyForBridge();
        if (!ok || !mounted) _tabController.animateTo(0);
      });
    }
  }

  /// Loads (or creates) the EVM bridge private key without requiring the ANET
  /// seed phrase.  Works for every wallet type:
  ///   1. Already loaded → return immediately.
  ///   2. Cached in secure storage (`evm_bridge.privkey`) → use it.
  ///   3. BIP39 or legacy seed in local secure storage → derive + cache.
  ///   4. Otherwise → verify PIN, then generate a fresh random key + cache.
  Future<bool> _ensureEvmKeyForBridge() async {
    if (_evmPrivKey != null) return true;

    // Step 1a: Load the wallet-scoped EVM signing key (preferred — supports
    // multiple accounts on the same device without collisions).
    final scopedWallet = widget.walletAddress.trim();
    if (scopedWallet.isNotEmpty &&
        scopedWallet != 'Not created' &&
        scopedWallet != 'No wallet created yet') {
      try {
        final stored = (await loadDexEvmSigningKeySecure(scopedWallet) ?? '')
            .trim();
        if (stored.length == 64) {
          final keyBytes = Uint8List.fromList(HEX.decode(stored));
          final addr = EthPrivateKey(keyBytes).address.hexEip55;
          if (mounted) {
            setState(() {
              _evmPrivKey = keyBytes;
              _evmAddress = addr;
            });
          }
          return true;
        }
      } catch (_) {}
    }

    // Step 1b: Legacy unscoped fallback (single-account devices upgraded
    // from older app versions).
    try {
      final stored = (await loadEvmBridgePrivKeySecure() ?? '').trim();
      if (stored.isNotEmpty) {
        final keyBytes = Uint8List.fromList(HEX.decode(stored));
        final addr = EthPrivateKey(keyBytes).address.hexEip55;
        // Opportunistically upgrade to the wallet-scoped key.
        if (scopedWallet.isNotEmpty &&
            scopedWallet != 'Not created' &&
            scopedWallet != 'No wallet created yet') {
          unawaited(
            saveDexEvmSigningKeySecure(scopedWallet, HEX.encode(keyBytes)),
          );
        }
        if (mounted) {
          setState(() {
            _evmPrivKey = keyBytes;
            _evmAddress = addr;
          });
        }
        return true;
      }
    } catch (_) {}

    // Step 2: Derive from local seed (works for BIP39, evmkey:, and legacy).
    try {
      final localSeed = (await loadWalletSeedSecure() ?? '').trim();
      if (localSeed.isNotEmpty &&
          localSeed != 'Hidden for security' &&
          localSeed != 'No wallet created yet') {
        final keyBytes = deriveEvmPrivateKey(localSeed);
        final addr = EthPrivateKey(keyBytes).address.hexEip55;
        await saveEvmBridgePrivKeySecure(HEX.encode(keyBytes));
        if (scopedWallet.isNotEmpty &&
            scopedWallet != 'Not created' &&
            scopedWallet != 'No wallet created yet') {
          await saveDexEvmSigningKeySecure(scopedWallet, HEX.encode(keyBytes));
        }
        if (mounted) {
          setState(() {
            _evmPrivKey = keyBytes;
            _evmAddress = addr;
          });
        }
        return true;
      }
    } catch (_) {}

    // Step 3: Verify PIN (identity check only), then generate a fresh key.
    if (!mounted) return false;
    bool pinOk = false;
    await _showEvmPinDialog(onVerified: () => pinOk = true);
    if (!pinOk || !mounted) return false;

    try {
      final keyBytes = generateRandomEvmPrivateKey();
      final addr = EthPrivateKey(keyBytes).address.hexEip55;
      await saveEvmBridgePrivKeySecure(HEX.encode(keyBytes));
      if (mounted) {
        setState(() {
          _evmPrivKey = keyBytes;
          _evmAddress = addr;
        });
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Lightweight PIN dialog used by the EVM bridge — verifies identity only,
  /// does not attempt to retrieve or use the ANET seed phrase.
  Future<void> _showEvmPinDialog({required VoidCallback onVerified}) async {
    final pinCtrl = TextEditingController();
    final pinFocus = FocusNode();
    String localMsg = '';
    bool submitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setS) {
          final pin = pinCtrl.text;
          return AlertDialog(
            backgroundColor: _card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Column(
              children: [
                Icon(Icons.lock_outline, color: _blue, size: 32),
                SizedBox(height: 8),
                Text(
                  'Enter PIN',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4),
                Text(
                  'Verify your identity to access the EVM Bridge',
                  style: TextStyle(color: _muted, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // OTP-style PIN boxes (FittedBox auto-scales on small screens)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (i) {
                      final filled = i < pin.length;
                      final active = i == pin.length;
                      return Container(
                        width: 42,
                        height: 52,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: active
                                ? _blue
                                : (filled
                                      ? _blue.withValues(alpha: 0.5)
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
                // Hidden real TextField
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
                    ),
                  ),
                ),
                if (localMsg.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      localMsg,
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
                      onPressed: submitting ? null : () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _muted,
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
                      onPressed: submitting
                          ? null
                          : () async {
                              final p = pinCtrl.text.trim();
                              if (p.length < 4) {
                                setS(() => localMsg = 'PIN must be 4–8 digits');
                                return;
                              }
                              setS(() {
                                submitting = true;
                                localMsg = '';
                              });
                              try {
                                await verifyWalletPinAPI(p);
                                onVerified();
                                if (ctx.mounted) Navigator.pop(ctx);
                              } catch (e) {
                                setS(() {
                                  submitting = false;
                                  localMsg = e.toString().replaceFirst(
                                    'Exception: ',
                                    '',
                                  );
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
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
                              'Confirm',
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
  }

  void _tryDeriveEvmKey(String seed) {
    if (seed.isEmpty ||
        seed == 'Hidden for security' ||
        seed == 'No wallet created yet') {
      return;
    }
    try {
      final keyBytes = deriveEvmPrivateKey(seed);
      final addr = EthPrivateKey(keyBytes).address.hexEip55;
      if (mounted) {
        setState(() {
          _evmPrivKey = keyBytes;
          _evmAddress = addr;
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnack(
          'Could not load EVM wallet: ${e.toString().replaceFirst("Exception: ", "")}',
          isError: true,
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _debounce?.cancel();
    _blockTimer?.cancel();
    _amountController.dispose();
    _amountFocus.dispose();
    _slippageController.dispose();
    super.dispose();
  }

  Future<void> _loadL1Block() async {
    try {
      final info = await getLatestBlockInfoAPI();
      if (!mounted) return;
      setState(() {
        _l1Block = info != null
            ? int.tryParse(info['block_height'].toString())
            : _l1Block;
      });
    } catch (_) {}
  }

  // ─── helpers ──────────────────────────────────────────────────────────────

  String get _fromSymbol =>
      _anetToToken ? 'ANET' : (_selectedPool?['token_symbol'] as String? ?? '');

  String get _toSymbol =>
      _anetToToken ? (_selectedPool?['token_symbol'] as String? ?? '') : 'ANET';

  bool get _hasValidInput {
    final v = double.tryParse(_amountController.text.trim());
    return v != null && v > 0;
  }

  bool get _hasValidWallet =>
      widget.walletAddress.isNotEmpty &&
      widget.walletAddress != 'Not created' &&
      widget.walletAddress.startsWith('ANET');

  int _toAnts(double v) => (v * 100000000).round();

  double _fromAnts(dynamic u) =>
      (int.tryParse(u?.toString() ?? '0') ?? 0) / 100000000.0;

  double _tokenUnitsToDouble(int units, String symbol) {
    const sixDec = {'USDC', 'USDT', 'BUSD', 'DAI'};
    return units /
        (sixDec.contains(symbol.toUpperCase()) ? 1000000.0 : 100000000.0);
  }

  String _fmt(double v) {
    if (v >= 1000) return v.toStringAsFixed(2);
    if (v >= 1) return v.toStringAsFixed(4);
    if (v >= 0.0001) return v.toStringAsFixed(6);
    return v.toStringAsFixed(8);
  }

  String _spotRate() {
    if (_selectedPool == null) return '';
    final anetRes = _fromAnts(_selectedPool!['anet_reserve_ants']);
    final tokUnits =
        int.tryParse(_selectedPool!['token_reserve_units'].toString()) ?? 0;
    final symbol = _selectedPool!['token_symbol'] as String? ?? '';
    final tokDouble = _tokenUnitsToDouble(tokUnits, symbol);
    if (anetRes <= 0 || tokDouble <= 0) return '';
    if (_anetToToken) {
      return '1 ANET ≈ ${_fmt(tokDouble / anetRes)} $symbol';
    } else {
      return '1 $symbol ≈ ${_fmt(anetRes / tokDouble)} ANET';
    }
  }

  int _calcMinOut() {
    if (_quote == null) return 0;
    final out = int.tryParse(_quote!['amount_out'].toString()) ?? 0;
    return (out * (1.0 - _slippagePct / 100.0)).round();
  }

  // ─── data loading ─────────────────────────────────────────────────────────

  Future<void> _loadPools() async {
    setState(() {
      _poolsLoading = true;
      _poolsError = null;
    });
    try {
      final pools = await getDexPoolsAPI();
      if (!mounted) return;
      setState(() {
        _pools = pools;
        _poolsLoading = false;
        if (pools.isNotEmpty && _selectedPool == null) {
          _selectedPool = pools.first;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _poolsLoading = false;
        _poolsError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadBalance() async {
    if (!_hasValidWallet) return;
    setState(() => _balanceLoading = true);
    try {
      final acc = await getL1AccountAPI(widget.walletAddress);
      if (!mounted) return;
      setState(() {
        _anetBalance = (acc['ants_balance'] as int? ?? 0) / 100000000.0;
        _balanceLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _balanceLoading = false);
    }
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_historyKey) ?? [];
      if (!mounted) return;
      setState(() {
        _swapHistory = raw
            .map((s) => Map<String, dynamic>.from(jsonDecode(s) as Map))
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _saveHistory(Map<String, dynamic> entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final updated = [entry, ..._swapHistory].take(10).toList();
      await prefs.setStringList(
        _historyKey,
        updated.map((e) => jsonEncode(e)).toList(),
      );
      if (!mounted) return;
      setState(() => _swapHistory = updated);
    } catch (_) {}
  }

  // ─── quote ────────────────────────────────────────────────────────────────

  void _onAmountChanged(String _) {
    _debounce?.cancel();
    setState(() {
      _quote = null;
      _quoteError = null;
      _swapResult = null;
      _swapError = null;
    });
    if (!_hasValidInput || _selectedPool == null) return;
    _debounce = Timer(const Duration(milliseconds: 600), _fetchQuote);
  }

  Future<void> _fetchQuote() async {
    if (!_hasValidInput || _selectedPool == null) return;
    final symbol = _selectedPool!['token_symbol'] as String;
    final amountIn = _toAnts(double.parse(_amountController.text.trim()));
    setState(() {
      _quoteLoading = true;
      _quoteError = null;
      _quote = null;
    });
    try {
      final q = await getDexSwapQuoteAPI(
        tokenSymbol: symbol,
        amountIn: amountIn,
        anetToToken: _anetToToken,
      );
      if (!mounted) return;
      setState(() {
        _quote = q;
        _quoteLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _quoteLoading = false;
        _quoteError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ─── execute swap ─────────────────────────────────────────────────────────

  Future<void> _executeSwap() async {
    if (_selectedPool == null || !_hasValidInput) return;
    if (!_hasValidWallet) {
      _showSnack('Wallet not connected.', isError: true);
      return;
    }
    // Minimum swap: $1.00 for stablecoins (USDC / USDT)
    if (_fromSymbol == 'USDC' || _fromSymbol == 'USDT') {
      final amt = double.tryParse(_amountController.text.trim()) ?? 0.0;
      if (amt < 1.0) {
        _showSnack('Minimum swap is 1.0 $_fromSymbol (\$1)', isError: true);
        return;
      }
    }

    // ── Build the ECDSA auth blob ─────────────────────────────────────────
    // Preferred path: use the locally-cached signing key (fully offline).
    // Fallback: re-derive from the seed phrase after PIN verification.
    Map<String, dynamic>? auth;
    if (_anetSigningKey != null && widget.signWithKeyAuth != null) {
      // Auto-sign with cached key — no PIN prompt needed if session valid.
      final pinOk = await _ensurePinSession();
      if (!pinOk) return;
      try {
        auth = widget.signWithKeyAuth!('dex_swap', _anetSigningKey!);
      } catch (e) {
        _showSnack('Signing failed: $e', isError: true);
        return;
      }
    } else {
      // Legacy path: require PIN + resolve seed phrase, then sign.
      final pinOk = await _ensurePinSession();
      if (!pinOk) return;
      final seed = _sessionSeedPhrase ?? widget.seedPhrase;
      if (seed.isEmpty ||
          seed == 'Hidden for security' ||
          seed == 'No wallet created yet') {
        _showSnack(
          'Unable to retrieve signing key. Please re-open your wallet.',
          isError: true,
        );
        return;
      }
      try {
        auth = widget.signActionAuth('dex_swap', seed);
      } catch (e) {
        _showSnack('Signing failed: $e', isError: true);
        return;
      }
      // Opportunistically cache the signing key from the seed for next time.
      unawaited(_cacheAnetSigningKeyFromSeed(seed));
    }

    final symbol = _selectedPool!['token_symbol'] as String;
    final amountIn = _toAnts(double.parse(_amountController.text.trim()));
    final minOut = _calcMinOut();

    setState(() {
      _swapping = true;
      _swapError = null;
      _swapResult = null;
    });
    try {
      // trader MUST equal the address the chain recovers from the auth
      // signature.  The signed auth (built in main.dart) now uses the
      // secp-derived wallet — use that exact value here, not
      // widget.walletAddress (which may still be the legacy form until
      // the on-chain migration completes).
      final traderAddr = (auth['wallet']?.toString() ?? widget.walletAddress)
          .trim()
          .toUpperCase();
      final result = await executeDexSwapAPI(
        trader: traderAddr,
        tokenSymbol: symbol,
        amountIn: amountIn,
        anetToToken: _anetToToken,
        auth: auth,
        minAmountOut: minOut,
      );
      if (!mounted) return;

      final outUnits = int.tryParse(result['amount_out'].toString()) ?? 0;
      final outDouble = _tokenUnitsToDouble(
        outUnits,
        _anetToToken ? symbol : 'ANET',
      );
      final inAmt = _amountController.text.trim();

      await _saveHistory({
        'ts': DateTime.now().toUtc().toIso8601String(),
        'from_symbol': _fromSymbol,
        'to_symbol': _toSymbol,
        'amount_in': inAmt,
        'amount_out': _fmt(outDouble),
        'pair_id': _selectedPool!['pair_id'],
      });

      // Fetch the latest block info so the user can verify on-chain.
      final blockInfo = await getLatestBlockInfoAPI();

      if (!mounted) return;
      setState(() {
        _swapping = false;
        _swapResult = 'Received ${_fmt(outDouble)} $_toSymbol';
        _lastSwapBlockHeight = blockInfo != null
            ? int.tryParse(blockInfo['block_height'].toString())
            : null;
        _amountController.clear();
        _quote = null;
      });
      _loadBalance();
      _loadPools();
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString().replaceFirst('Exception: ', '');
      final lower = raw.toLowerCase();
      // A swap can fail because the wallet's ANET L1 account does not exist
      // on-chain yet — i.e. it has never received ANET (0 balance, or a
      // bridge credit is still pending). The chain returns a low-level
      // "account not found" / "no on-chain balance" error. Translate that
      // into a clear, actionable message instead of a cryptic red box, and
      // offer the waitlist so the swap can auto-run once funds land.
      final isNotFunded =
          lower.contains('account not found') ||
          lower.contains('no on-chain balance') ||
          lower.contains('mining session');
      setState(() {
        _swapping = false;
        _swapError = isNotFunded
            ? 'Your ANET L1 account isn\'t funded yet. Mine ANET in the app, '
                  'or wait for a pending bridge to complete, then try again.'
            : raw;
      });
      if (isNotFunded) {
        _showSnack(
          'No ANET L1 balance yet — join the waitlist to auto-swap when funds arrive.',
          isError: true,
        );
        unawaited(_offerJoinWaitlist());
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? _red : _green,
      ),
    );
  }

  /// Enqueue the current swap into the off-chain waitlist so the backend
  /// can mark it ready as soon as the wallet finishes activating (or the
  /// pending bridge credit lands). This is a Phase 1 path — Phase 2 will
  /// add a one-tap auto-execute prompt the next time the user opens the
  /// app and the intent is in the 'ready' state.
  Future<void> _offerJoinWaitlist() async {
    if (!mounted) return;
    final amountText = _amountController.text.trim();
    final amountDouble = double.tryParse(amountText) ?? 0.0;
    if (amountDouble <= 0) {
      _showSnack('Enter a swap amount first', isError: true);
      return;
    }
    final fromSym = _fromSymbol;
    final toSym = _toSymbol;
    final amountAnts = _toAnts(amountDouble).toString();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        title: const Text(
          'Add to waitlist?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'We will queue:\n\n'
          '  $amountText $fromSym → $toSym\n\n'
          'You will be notified once your wallet is activated and the '
          'intent becomes ready. You can cancel anytime from the '
          'waitlist screen. No funds are moved by joining the waitlist.',
          style: const TextStyle(color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Add to waitlist',
              style: TextStyle(color: _blue),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await createWaitlistIntentAPI(
        intentType: 'swap',
        fromToken: fromSym,
        toToken: toSym,
        fromAmount: amountAnts,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _green,
          content: const Text('Added to waitlist'),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const WaitlistPage()));
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  /// True while the one-tap legacy→secp sweep is running (drives the
  /// "Sync bridged balance" button spinner).
  bool _syncingBridgedBalance = false;

  /// One-tap recovery for users whose bridged USDC→ANET credit landed on
  /// their legacy ANET address but whose wallet now signs with the secp
  /// scheme, so the DEX balance shows 0 / "account not found".
  ///
  /// Prompts for the PIN, runs the idempotent
  /// `/auth/wallet/migrate-to-secp` server-side migration (sweeps the
  /// legacy balance onto the secp address), then refreshes the balance.
  /// Safe to tap repeatedly — the backend returns `already_migrated` when
  /// there is nothing to move.
  Future<void> _syncBridgedBalance() async {
    if (_syncingBridgedBalance) return;

    final pinCtrl = TextEditingController();
    String? approvedPin;
    String localMessage = '';
    bool busy = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setLocalState) {
          return AlertDialog(
            backgroundColor: _card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Sync bridged balance',
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
                  'Enter your wallet PIN to move any bridged ANET from your '
                  'legacy address onto your current swap wallet. No new funds '
                  'are created — this only sweeps what is already yours.',
                  style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  style: const TextStyle(
                    color: Colors.white,
                    letterSpacing: 6,
                    fontSize: 18,
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '••••',
                    hintStyle: TextStyle(color: _muted),
                    border: OutlineInputBorder(),
                  ),
                ),
                if (localMessage.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    localMessage,
                    style: const TextStyle(color: _red, fontSize: 12),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _blue),
                onPressed: busy
                    ? null
                    : () async {
                        final p = pinCtrl.text.trim();
                        if (p.length < 4) {
                          setLocalState(
                            () => localMessage = 'PIN must be 4–8 digits',
                          );
                          return;
                        }
                        setLocalState(() {
                          busy = true;
                          localMessage = '';
                        });
                        try {
                          approvedPin = p;
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          setLocalState(() {
                            busy = false;
                            localMessage = e.toString().replaceFirst(
                              'Exception: ',
                              '',
                            );
                          });
                        }
                      },
                child: const Text('Sync'),
              ),
            ],
          );
        },
      ),
    );

    pinCtrl.dispose();
    if (approvedPin == null) return;

    if (mounted) setState(() => _syncingBridgedBalance = true);
    try {
      final mig = await migrateWalletToSecpAPI(approvedPin!);
      final status = (mig['status'] ?? '').toString();
      if (!mounted) return;
      if (status == 'migrated' || status == 'synced_from_chain') {
        _showSnack('Bridged balance synced — refreshing…');
      } else if (status == 'already_migrated') {
        _showSnack('Wallet already synced — refreshing balance…');
      } else {
        _showSnack('Sync complete — refreshing balance…');
      }
      await _loadBalance();
    } catch (e) {
      if (!mounted) return;
      final clean = e.toString().replaceFirst('Exception: ', '');
      final lower = clean.toLowerCase();
      if (lower.contains('not activated') || lower.contains('mining session')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _red,
            duration: const Duration(seconds: 10),
            content: Text(clean, style: const TextStyle(color: Colors.white)),
          ),
        );
      } else {
        _showSnack(clean, isError: true);
      }
    } finally {
      if (mounted) setState(() => _syncingBridgedBalance = false);
    }
  }

  // ─── PIN session gate ─────────────────────────────────────────────────────

  /// Shows a PIN dialog if the 5-minute session has expired.
  /// Returns true if the session is valid (either already active or PIN accepted).
  Future<bool> _ensurePinSession() async {
    if (_pinSessionValid) return true;

    // For EVM-imported wallets (stored as 'evmkey:HEX'), no PIN is required.
    // Silently reload from secure storage and refresh the session.
    try {
      final storedSeed = (await loadWalletSeedSecure() ?? '').trim();
      if (storedSeed.startsWith('evmkey:') && storedSeed.length > 7) {
        if (mounted) setState(() => _sessionSeedPhrase = storedSeed);
        _pinSessionExpiresAt = DateTime.now().add(const Duration(minutes: 5));
        return true;
      }
    } catch (_) {}

    if (!mounted) return false;
    final pinCtrl = TextEditingController();
    final pinFocus = FocusNode();
    bool approved = false;
    String? approvedPin;
    String localMessage = '';
    bool submitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setLocalState) {
          final pin = pinCtrl.text;
          return AlertDialog(
            backgroundColor: _card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Column(
              children: [
                Icon(Icons.swap_horiz, color: _blue, size: 32),
                SizedBox(height: 8),
                Text(
                  'Confirm Swap',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4),
                Text(
                  'Enter your wallet PIN to authorise this swap.',
                  style: TextStyle(color: _muted, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // OTP-style PIN boxes (FittedBox auto-scales on small screens)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (i) {
                      final filled = i < pin.length;
                      final active = i == pin.length;
                      return Container(
                        width: 42,
                        height: 52,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: active
                                ? _blue
                                : (filled
                                      ? _blue.withValues(alpha: 0.5)
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
                // Hidden real text field
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
                      onChanged: (_) => setLocalState(() {}),
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
                      onPressed: submitting ? null : () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _muted,
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
                        backgroundColor: _blue,
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
                                setLocalState(
                                  () => localMessage = 'PIN must be 4–8 digits',
                                );
                                return;
                              }
                              setLocalState(() {
                                submitting = true;
                                localMessage = '';
                              });
                              try {
                                await verifyWalletPinAPI(p);
                                approved = true;
                                approvedPin = p;
                                if (ctx.mounted) Navigator.pop(ctx);
                              } catch (e) {
                                setLocalState(() {
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
                              'Confirm',
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

    if (approved) {
      // ── One-shot legacy → secp on-chain migration ─────────────────────
      // Runs once per app session. The backend is idempotent; this is what
      // unblocks "signature recovery does not match action wallet" for
      // users whose wallet_address is still the legacy RIPEMD160 derivation.
      if (!_walletMigrationChecked && approvedPin != null) {
        _walletMigrationChecked = true;
        try {
          final mig = await migrateWalletToSecpAPI(approvedPin!);
          final status = (mig['status'] ?? '').toString();
          if (status == 'migrated' || status == 'synced_from_chain') {
            if (mounted) {
              _showSnack(
                'Wallet upgraded for swap signing — refreshing balances…',
                isError: false,
              );
            }
            // Refresh balances against the new secp wallet address. The
            // parent passed walletAddress, so a full reload requires going
            // back; here we just re-fetch what we can.
            unawaited(_loadBalance());
          }
        } catch (e) {
          // Surface known recoverable migration errors so the user knows
          // why the swap path is blocked instead of getting a cryptic
          // "account not found" later. Non-recoverable errors fall
          // through silently; the chain will return a clear error.
          final msg = e.toString().toLowerCase();
          if (msg.contains('mining session') ||
              msg.contains('stuck on chain') ||
              msg.contains('no on-chain balance') ||
              msg.contains('contact support')) {
            if (mounted) {
              final clean = e
                  .toString()
                  .replaceFirst('Exception: ', '')
                  .replaceFirst('FormatException: ', '');
              // Activation-blocked path: offer to enqueue the intent
              // so the swap auto-becomes "ready" once the wallet is
              // activated. We only show the action for activation
              // errors (mining session/no on-chain balance), not for
              // generic stuck-on-chain orphans which need admin help.
              final canOfferWaitlist =
                  msg.contains('mining session') ||
                  msg.contains('no on-chain balance');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: _red,
                  duration: const Duration(seconds: 10),
                  content: Text(
                    clean,
                    style: const TextStyle(color: Colors.white),
                  ),
                  action: canOfferWaitlist
                      ? SnackBarAction(
                          label: 'Join Waitlist',
                          textColor: Colors.white,
                          onPressed: _offerJoinWaitlist,
                        )
                      : null,
                ),
              );
            }
            return false; // do not proceed to swap — it will fail anyway
          }
          // Migration failures are non-fatal for the seed-only swap path;
          // the chain will return a clear error if the signature still
          // doesn't recover, and the user can retry.
        }
      }

      // Resolve the signing seed:
      // 1. Device secure storage (fastest, always try first)
      // 2. Server reveal with PIN (works when OTP is not required)
      // 3. widget.preResolvedSeed — already resolved when DEX was opened
      // 4. widget.seedPhrase      — passed from parent, PIN verified above
      String? resolvedSeed;
      try {
        final localSeed = (await loadWalletSeedSecure() ?? '').trim();
        if (localSeed.isNotEmpty &&
            localSeed != 'Hidden for security' &&
            localSeed != 'No wallet created yet') {
          resolvedSeed = localSeed;
        } else if (approvedPin != null) {
          try {
            final reveal = await revealSeedForDexAPI(approvedPin!);
            final serverSeed = (reveal['seedPhrase']?.toString() ?? '').trim();
            if (serverSeed.isNotEmpty) {
              resolvedSeed = serverSeed;
            }
          } catch (_) {
            // Network error — fall through to widget seed
          }
        }
      } catch (_) {}

      // Fallback: use seed already available in this widget (identity was
      // verified by verifyWalletPinAPI above, so this is safe).
      if (resolvedSeed == null || resolvedSeed.isEmpty) {
        final pre = (widget.preResolvedSeed ?? '').trim();
        if (pre.isNotEmpty &&
            pre != 'Hidden for security' &&
            pre != 'No wallet created yet') {
          resolvedSeed = pre;
        }
      }
      if (resolvedSeed == null || resolvedSeed.isEmpty) {
        final ws = widget.seedPhrase.trim();
        if (ws.isNotEmpty &&
            ws != 'Hidden for security' &&
            ws != 'No wallet created yet') {
          resolvedSeed = ws;
        }
      }

      if (resolvedSeed == null || resolvedSeed.isEmpty) {
        if (mounted) {
          _showSnack(
            'Wallet seed unavailable. Please close and re-open the DEX.',
            isError: true,
          );
        }
        return false;
      }

      if (mounted) setState(() => _sessionSeedPhrase = resolvedSeed);
      _pinSessionExpiresAt = DateTime.now().add(const Duration(minutes: 10));
      return true;
    }
    return false;
  }

  // ─── confirm dialog ───────────────────────────────────────────────────────

  Future<bool?> _confirmSwap() async {
    if (_quote == null || _selectedPool == null) return false;
    final symbol = _selectedPool!['token_symbol'] as String;
    final outUnits = int.tryParse(_quote!['amount_out'].toString()) ?? 0;
    final outDouble = _tokenUnitsToDouble(
      outUnits,
      _anetToToken ? symbol : 'ANET',
    );
    final impactBps = int.tryParse(_quote!['price_impact_bps'].toString()) ?? 0;
    final feeUnits = int.tryParse(_quote!['fee_paid'].toString()) ?? 0;
    final feeDouble = feeUnits / 100000000.0;
    final minDouble = _tokenUnitsToDouble(
      _calcMinOut(),
      _anetToToken ? symbol : 'ANET',
    );

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Review Swap',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _confirmRow(
              'You pay',
              '${_amountController.text.trim()} $_fromSymbol',
            ),
            const SizedBox(height: 8),
            _confirmRow(
              'You receive',
              '${_fmt(outDouble)} $_toSymbol',
              valueColor: _green,
            ),
            const Divider(color: Colors.white12, height: 20),
            _confirmRow('Rate', _spotRate()),
            const SizedBox(height: 6),
            _confirmRow('Fee (0.30%)', '${_fmt(feeDouble)} $_fromSymbol'),
            const SizedBox(height: 6),
            _confirmRow('Slippage', '${_slippagePct.toStringAsFixed(1)}%'),
            const SizedBox(height: 6),
            _confirmRow('Min received', '${_fmt(minDouble)} $_toSymbol'),
            const SizedBox(height: 6),
            _confirmRow(
              'Price impact',
              '${(impactBps / 100).toStringAsFixed(2)}%',
              valueColor: impactBps > 200
                  ? _red
                  : (impactBps > 50 ? _gold : _green),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Swap'),
          ),
        ],
      ),
    );
  }

  Widget _confirmRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: _muted, fontSize: 13)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Tab 0: ANET L1 AMM
          _poolsLoading
              ? const Center(child: CircularProgressIndicator(color: _blue))
              : _poolsError != null
              ? _buildFullError(_poolsError!)
              : _pools.isEmpty
              ? _buildEmpty()
              : _buildBody(),
          // Tab 1: EVM Bridge
          _evmPrivKey != null
              ? EvmBridgePage(
                  anetAddress: widget.walletAddress,
                  evmAddress: _evmAddress ?? widget.evmWalletAddress ?? '',
                  privKeyBytes: _evmPrivKey!,
                )
              : const Center(child: CircularProgressIndicator(color: _blue)),
        ],
      ),
      // Banner ad removed (Google AdSense/AdMob ban).
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.white,
          size: 18,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          const Text(
            'ANET DEX',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(width: 8),
          if (_pools.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${_pools.length} pair${_pools.length == 1 ? '' : 's'}',
                style: const TextStyle(color: _blue, fontSize: 11),
              ),
            ),
        ],
      ),
      actions: [
        if (_l1Block != null)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: _green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '#$_l1Block',
                    style: const TextStyle(
                      color: _green,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.queue_outlined, color: _muted),
          tooltip: 'Swap waitlist',
          onPressed: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const WaitlistPage()));
          },
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: _muted),
          onPressed: _poolsLoading
              ? null
              : () {
                  _loadPools();
                  _loadBalance();
                  _loadL1Block();
                },
          tooltip: 'Refresh',
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: _blue,
        indicatorWeight: 2,
        labelColor: _blue,
        unselectedLabelColor: _muted,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
        tabs: const [
          Tab(text: 'ANET L1 AMM'),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('EVM Bridge'),
                SizedBox(width: 4),
                Icon(Icons.swap_horiz, size: 13),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullError(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: _muted, size: 48),
            const SizedBox(height: 16),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadPools,
              style: ElevatedButton.styleFrom(backgroundColor: _blue),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.swap_horiz, color: _muted, size: 48),
          SizedBox(height: 16),
          Text(
            'No trading pairs available yet.',
            style: TextStyle(color: _muted, fontSize: 15),
          ),
          SizedBox(height: 6),
          Text(
            'Check back soon.',
            style: TextStyle(color: _muted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ─── main body ────────────────────────────────────────────────────────────

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWalletCard(),
          const SizedBox(height: 12),
          _buildDisclaimerBanner(),
          const SizedBox(height: 16),
          _buildPoolSelector(),
          const SizedBox(height: 12),
          _buildSlippageSelector(),
          const SizedBox(height: 16),
          _buildFromCard(),
          _buildRateLine(),
          _buildDirectionToggle(),
          _buildToCard(),
          const SizedBox(height: 16),
          _buildQuoteSection(),
          const SizedBox(height: 20),
          _buildSwapButton(),
          if (_swapResult != null) ...[
            const SizedBox(height: 16),
            _buildSwapSuccessBanner(_swapResult!),
          ],
          if (_swapError != null) ...[
            const SizedBox(height: 12),
            _buildBanner(_swapError!, isSuccess: false),
          ],
          if (_swapHistory.isNotEmpty) ...[
            const SizedBox(height: 28),
            _buildSwapHistory(),
          ],
          const SizedBox(height: 28),
          _buildPoolList(),
        ],
      ),
    );
  }

  // ─── wallet card ──────────────────────────────────────────────────────────

  Widget _buildWalletCard() {
    final anetAddr = widget.walletAddress;
    final evmAddr = widget.evmWalletAddress;
    final hasEvm = evmAddr != null && evmAddr.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _hasValidWallet
              ? _blue.withValues(alpha: 0.35)
              : _muted.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── header ──────────────────────────────────────────────────────
          Row(
            children: [
              Icon(
                _hasValidWallet
                    ? Icons.account_balance_wallet
                    : Icons.account_balance_wallet_outlined,
                color: _hasValidWallet ? _blue : _muted,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                _hasValidWallet ? 'Connected Wallets' : 'No Wallet Connected',
                style: TextStyle(
                  color: _hasValidWallet ? _blue : _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              if (_pinSessionValid)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_open, color: _green, size: 10),
                      SizedBox(width: 3),
                      Text(
                        'Authorized',
                        style: TextStyle(
                          color: _green,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (_hasValidWallet) ...[
            const SizedBox(height: 12),
            // ── ANET L1 row ─────────────────────────────────────────────
            Row(
              children: [
                _tokenIcon('ANET', size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ANET L1 Wallet',
                        style: TextStyle(color: _muted, fontSize: 10),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        anetAddr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _balanceLoading ? '…' : '${_fmt(_anetBalance)} ANET',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Balance',
                      style: TextStyle(color: _muted, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: anetAddr));
                    _showSnack('ANET address copied');
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.copy, color: _muted, size: 14),
                  ),
                ),
              ],
            ),
            // ── Sync bridged balance ────────────────────────────────────
            // One-tap recovery for bridged USDC→ANET credits that landed on
            // the legacy address but don't show on the secp swap wallet.
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _syncingBridgedBalance ? null : _syncBridgedBalance,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _blue,
                  side: BorderSide(color: _blue.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: _syncingBridgedBalance
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          color: _blue,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.sync, size: 16),
                label: Text(
                  _syncingBridgedBalance ? 'Syncing…' : 'Sync bridged balance',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (hasEvm) ...[
              const SizedBox(height: 10),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 10),
              // ── EVM row ──────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.electric_bolt,
                      color: _green,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'EVM Wallet · USDC Bridge',
                          style: TextStyle(color: _muted, fontSize: 10),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          evmAddr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _green.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'Bridge',
                      style: TextStyle(
                        color: _green,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: evmAddr));
                      _showSnack('EVM address copied');
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.copy, color: _muted, size: 14),
                    ),
                  ),
                ],
              ),
            ] else if (_pinSessionValid) ...[
              // PIN was verified but EVM address wasn't derived — won't happen
              // in normal flow, but guard gracefully.
            ] else ...[
              const SizedBox(height: 8),
              const Text(
                'Open DEX via the wallet screen to load your EVM bridge wallet.',
                style: TextStyle(color: _muted, fontSize: 11, height: 1.4),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ─── swap success banner with block verification ──────────────────────────

  Widget _buildSwapSuccessBanner(String msg) {
    final blockHeight = _lastSwapBlockHeight;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline, color: _green, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  msg,
                  style: const TextStyle(
                    color: _green,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.link, color: _muted, size: 13),
              const SizedBox(width: 6),
              Text(
                blockHeight != null
                    ? 'Recorded on ANET L1 · Block #$blockHeight'
                    : 'Recorded on ANET L1 blockchain',
                style: const TextStyle(color: _muted, fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              final uri = Uri.parse('https://explorer.a-network.net/explorer');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Row(
              children: [
                const Icon(Icons.open_in_new, color: _blue, size: 12),
                const SizedBox(width: 5),
                const Text(
                  'View on ANET Explorer',
                  style: TextStyle(
                    color: _blue,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── disclaimer ───────────────────────────────────────────────────────────

  Widget _buildDisclaimerBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _blue.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outlined, color: _blue, size: 14),
              const SizedBox(width: 6),
              const Text(
                'Fully Decentralized · Non-Custodial',
                style: TextStyle(
                  color: _blue,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'All swaps execute directly on the ANET Layer 1 blockchain via a '
            'constant-product AMM (x·y=k). A-Network never holds, controls, or '
            'has access to your funds. Every transaction is publicly verifiable '
            'on-chain — transparent by design.',
            style: TextStyle(color: _muted, fontSize: 11.5, height: 1.45),
          ),
          const SizedBox(height: 8),
          const Text(
            '⚠  Trading involves risk. Token values are volatile and you may '
            'receive less than expected. Only trade what you can afford to lose.',
            style: TextStyle(color: _gold, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ─── pool selector ────────────────────────────────────────────────────────

  Widget _buildPoolSelector() {
    return GestureDetector(
      onTap: _pools.length > 1 ? _showPoolPicker : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _blue.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            _tokenIcon('ANET', size: 32),
            const SizedBox(width: 4),
            _tokenIcon(
              _selectedPool?['token_symbol'] as String? ?? '',
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedPool?['pair_id'] as String? ?? '—',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _buildReserveSubtitle(),
                ],
              ),
            ),
            if (_pools.length > 1)
              const Icon(Icons.keyboard_arrow_down, color: _muted),
          ],
        ),
      ),
    );
  }

  Widget _buildReserveSubtitle() {
    if (_selectedPool == null) return const SizedBox.shrink();
    final symbol = _selectedPool!['token_symbol'] as String? ?? '';
    final anetRes = _fromAnts(_selectedPool!['anet_reserve_ants']);
    final tokUnits =
        int.tryParse(_selectedPool!['token_reserve_units'].toString()) ?? 0;
    final tokDouble = _tokenUnitsToDouble(tokUnits, symbol);
    return Text(
      '${_fmt(anetRes)} ANET / ${_fmt(tokDouble)} $symbol',
      style: const TextStyle(color: _muted, fontSize: 11),
    );
  }

  void _showPoolPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Select Trading Pair',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            ..._pools.map((pool) {
              final isSelected = pool['pair_id'] == _selectedPool?['pair_id'];
              return ListTile(
                tileColor: isSelected ? _blue.withValues(alpha: 0.1) : null,
                leading: _tokenIcon(
                  pool['token_symbol'] as String? ?? '',
                  size: 32,
                ),
                title: Text(
                  pool['pair_id'] as String? ?? '',
                  style: TextStyle(
                    color: isSelected ? _blue : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Fee: ${(pool['fee_bps'] as int? ?? 30) / 100}%',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
                onTap: () {
                  setState(() {
                    _selectedPool = pool;
                    _quote = null;
                    _quoteError = null;
                    _swapResult = null;
                    _swapError = null;
                  });
                  Navigator.pop(ctx);
                  if (_hasValidInput) _fetchQuote();
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  // ─── slippage selector ────────────────────────────────────────────────────

  Widget _buildSlippageSelector() {
    const options = [0.5, 1.0, 2.0];
    return Row(
      children: [
        const Text('Slippage:', style: TextStyle(color: _muted, fontSize: 12)),
        const SizedBox(width: 8),
        ...options.map(
          (opt) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _slippageChip(
              label: '${opt == opt.truncateToDouble() ? opt.toInt() : opt}%',
              selected: !_customSlippage && _slippagePct == opt,
              onTap: () => setState(() {
                _slippagePct = opt;
                _customSlippage = false;
              }),
            ),
          ),
        ),
        _slippageChip(
          label: _customSlippage
              ? '${_slippagePct.toStringAsFixed(1)}%'
              : 'Custom',
          selected: _customSlippage,
          selectedColor: _gold,
          onTap: _showCustomSlippage,
        ),
      ],
    );
  }

  Widget _slippageChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color selectedColor = _blue,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? selectedColor.withValues(alpha: 0.15) : _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? selectedColor : Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? selectedColor : _muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showCustomSlippage() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Custom Slippage',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: _slippageController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'e.g. 0.5',
            hintStyle: TextStyle(color: _muted),
            suffixText: '%',
            suffixStyle: TextStyle(color: _muted),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _blue),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _blue),
            onPressed: () {
              final val = double.tryParse(_slippageController.text.trim());
              if (val != null && val > 0 && val <= 50) {
                setState(() {
                  _slippagePct = val;
                  _customSlippage = true;
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Set', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── from card ────────────────────────────────────────────────────────────

  Widget _buildFromCard() {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'You pay',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
              Row(
                children: [
                  if (_balanceLoading)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        color: _muted,
                        strokeWidth: 1.5,
                      ),
                    )
                  else
                    Text(
                      _anetToToken
                          ? 'Balance: ${_fmt(_anetBalance)} ANET'
                          : 'Balance: — $_fromSymbol',
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  const SizedBox(width: 6),
                  if (!_balanceLoading && _anetToToken && _anetBalance > 0)
                    GestureDetector(
                      onTap: () {
                        final max = (_anetBalance - 0.00001).clamp(
                          0.0,
                          double.infinity,
                        );
                        _amountController.text = _fmt(max);
                        _onAmountChanged('');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'MAX',
                          style: TextStyle(
                            color: _blue,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  focusNode: _amountFocus,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '0.0',
                    hintStyle: TextStyle(color: _muted, fontSize: 26),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: _onAmountChanged,
                ),
              ),
              _tokenBadge(_fromSymbol),
            ],
          ),
        ],
      ),
    );
  }

  // ─── rate line ────────────────────────────────────────────────────────────

  Widget _buildRateLine() {
    final rate = _spotRate();
    if (rate.isEmpty) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.compare_arrows, color: _muted, size: 12),
          const SizedBox(width: 4),
          Text(rate, style: const TextStyle(color: _muted, fontSize: 11)),
        ],
      ),
    );
  }

  // ─── direction toggle ─────────────────────────────────────────────────────

  Widget _buildDirectionToggle() {
    return Center(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _anetToToken = !_anetToToken;
            _quote = null;
            _quoteError = null;
            _swapResult = null;
            _swapError = null;
          });
          if (_hasValidInput) _fetchQuote();
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _blue.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: _blue.withValues(alpha: 0.4)),
          ),
          child: const Icon(Icons.swap_vert, color: _blue, size: 20),
        ),
      ),
    );
  }

  // ─── to card ──────────────────────────────────────────────────────────────

  Widget _buildToCard() {
    final symbol = _selectedPool?['token_symbol'] as String? ?? '';
    final outUnits = _quote != null
        ? int.tryParse(_quote!['amount_out'].toString())
        : null;
    final outDouble = outUnits != null
        ? _tokenUnitsToDouble(outUnits, _anetToToken ? symbol : 'ANET')
        : null;

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'You receive',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _quoteLoading
                    ? const SizedBox(
                        height: 32,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: _blue,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      )
                    : Text(
                        outDouble != null ? _fmt(outDouble) : '—',
                        style: TextStyle(
                          color: outDouble != null ? _green : _muted,
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              _tokenBadge(_toSymbol),
            ],
          ),
        ],
      ),
    );
  }

  // ─── token icon & badge ───────────────────────────────────────────────────

  Widget _tokenIcon(String symbol, {double size = 28}) {
    const Map<String, Color> colors = {
      'ANET': _blue,
      'USDC': Color(0xFF2775CA),
      'USDT': Color(0xFF26A17B),
      'WANET': Color(0xFF9B59B6),
      'BTC': _gold,
      'ETH': Color(0xFF627EEA),
      'BNB': Color(0xFFF3BA2F),
    };
    final color = colors[symbol.toUpperCase()] ?? _muted;
    final letter = symbol.isEmpty ? '?' : symbol[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.2),
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            color: color,
            fontSize: size * 0.40,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _tokenBadge(String symbol) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _tokenIcon(symbol, size: 22),
        const SizedBox(width: 6),
        Text(
          symbol.isEmpty ? '—' : symbol,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  // ─── quote section ────────────────────────────────────────────────────────

  Widget _buildQuoteSection() {
    if (_quoteError != null) {
      return _buildBanner(_quoteError!, isSuccess: false);
    }
    if (_quote == null) return const SizedBox.shrink();

    final symbol = _selectedPool!['token_symbol'] as String? ?? '';
    final feeUnits = int.tryParse(_quote!['fee_paid'].toString()) ?? 0;
    final feeDouble = feeUnits / 100000000.0;
    final impactBps = int.tryParse(_quote!['price_impact_bps'].toString()) ?? 0;
    final minDouble = _tokenUnitsToDouble(
      _calcMinOut(),
      _anetToToken ? symbol : 'ANET',
    );

    Color impactColor = _green;
    if (impactBps > 200) {
      impactColor = _red;
    } else if (impactBps > 50) {
      impactColor = _gold;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          _quoteRow('Rate', _spotRate()),
          const SizedBox(height: 6),
          _quoteRow('Fee (0.30%)', '${_fmt(feeDouble)} $_fromSymbol'),
          const SizedBox(height: 6),
          _quoteRow(
            'Price impact',
            '${(impactBps / 100).toStringAsFixed(2)}%',
            valueColor: impactColor,
          ),
          const SizedBox(height: 6),
          _quoteRow(
            'Min received (${_slippagePct.toStringAsFixed(1)}%)',
            '${_fmt(minDouble)} $_toSymbol',
          ),
        ],
      ),
    );
  }

  Widget _quoteRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ─── swap button ──────────────────────────────────────────────────────────

  Widget _buildSwapButton() {
    final inputAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final hasInsufficientBalance =
        _hasValidInput && _anetToToken && _anetBalance < inputAmount;
    final disabled =
        _swapping ||
        !_hasValidInput ||
        _selectedPool == null ||
        !_hasValidWallet ||
        hasInsufficientBalance ||
        _quoteLoading;

    final String label;
    if (!_hasValidWallet) {
      label = 'Wallet not connected';
    } else if (_selectedPool == null) {
      label = 'Select a pair';
    } else if (!_hasValidInput) {
      label = 'Enter amount';
    } else if (hasInsufficientBalance) {
      label = 'Insufficient ANET balance';
    } else {
      label = 'Swap $_fromSymbol → $_toSymbol';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: disabled ? _surface : _blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: disabled
                ? null
                : () async {
                    HapticFeedback.mediumImpact();
                    if (_quote == null) {
                      await _fetchQuote();
                      if (_quote == null) return;
                    }
                    final confirmed = await _confirmSwap();
                    if (confirmed == true) await _executeSwap();
                  },
            child: _swapping
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      color: disabled ? _muted : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
        if (_hasValidWallet && !_balanceLoading && _anetBalance == 0.0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _gold.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: _gold, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Your ANET balance is 0. Mine or earn ANET in the app '
                    'before swapping. You need ANET tokens to use the DEX.',
                    style: TextStyle(
                      color: _gold,
                      fontSize: 11.5,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ─── banners ──────────────────────────────────────────────────────────────

  Widget _buildBanner(String msg, {required bool isSuccess}) {
    final color = isSuccess ? _green : _red;
    final icon = isSuccess ? Icons.check_circle_outline : Icons.error_outline;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg, style: TextStyle(color: color, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ─── swap history ─────────────────────────────────────────────────────────

  Widget _buildSwapHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Swaps',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        ..._swapHistory.take(5).map(_buildHistoryRow),
      ],
    );
  }

  Widget _buildHistoryRow(Map<String, dynamic> entry) {
    final from = entry['from_symbol'] as String? ?? '';
    final to = entry['to_symbol'] as String? ?? '';
    final amtIn = entry['amount_in'] as String? ?? '';
    final amtOut = entry['amount_out'] as String? ?? '';
    final tsRaw = entry['ts'] as String? ?? '';

    String timeStr = '';
    try {
      final dt = DateTime.parse(tsRaw).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) {
        timeStr = 'Just now';
      } else if (diff.inHours < 1) {
        timeStr = '${diff.inMinutes}m ago';
      } else if (diff.inDays < 1) {
        timeStr = '${diff.inHours}h ago';
      } else {
        timeStr = '${diff.inDays}d ago';
      }
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _tokenIcon(from, size: 26),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward, color: _muted, size: 12),
          const SizedBox(width: 4),
          _tokenIcon(to, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$amtIn $from → $amtOut $to',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  timeStr,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: _green, size: 16),
        ],
      ),
    );
  }

  // ─── pool list ────────────────────────────────────────────────────────────

  Widget _buildPoolList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Available Pairs',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        ..._pools.map(_buildPoolCard),
      ],
    );
  }

  Widget _buildPoolCard(Map<String, dynamic> pool) {
    final pairId = pool['pair_id'] as String? ?? '';
    final symbol = pool['token_symbol'] as String? ?? '';
    final feeBps = pool['fee_bps'] as int? ?? 30;
    final anetRes = _fromAnts(pool['anet_reserve_ants']);
    final tokUnits = int.tryParse(pool['token_reserve_units'].toString()) ?? 0;
    final tokDouble = _tokenUnitsToDouble(tokUnits, symbol);
    final lp = pool['lp_holders'] ?? 0;
    final isSelected = pool['pair_id'] == _selectedPool?['pair_id'];

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPool = pool;
          _quote = null;
          _quoteError = null;
          _swapResult = null;
          _swapError = null;
        });
        if (_hasValidInput) _fetchQuote();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? _blue.withValues(alpha: 0.5)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _tokenIcon('ANET', size: 30),
                const SizedBox(width: 3),
                _tokenIcon(symbol, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pairId,
                        style: TextStyle(
                          color: isSelected ? _blue : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Fee: ${feeBps / 100}%  ·  LP: $lp holders',
                        style: const TextStyle(color: _muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(
                        color: _blue,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ANET Reserve',
                        style: TextStyle(color: _muted, fontSize: 10),
                      ),
                      Text(
                        '${_fmt(anetRes)} ANET',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$symbol Reserve',
                        style: const TextStyle(color: _muted, fontSize: 10),
                      ),
                      Text(
                        '${_fmt(tokDouble)} $symbol',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.show_chart, color: _muted, size: 11),
                const SizedBox(width: 4),
                Text(
                  anetRes > 0 && tokDouble > 0
                      ? 'Rate: 1 ANET ≈ ${_fmt(tokDouble / anetRes)} $symbol'
                      : 'No liquidity',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
