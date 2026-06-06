import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web3dart/web3dart.dart';

import 'api.dart';
import 'evm_wallet_service.dart';
import 'username_registry_service.dart';

const _surface = Color(0xFF0A1224);
const _card = Color(0xFF0F1C2E);
const _blue = Color(0xFF1677FF);
const _green = Color(0xFF25C474);
const _gold = Color(0xFFFFB800);
const _red = Color(0xFFFF4D4F);
const _muted = Color(0xFF7B829A);

const String _bridgeHistoryKey = 'evm_bridge_history_v1';
const String _bridgeBalancesCacheKey = 'evm_bridge_balances_v1';
const String _bridgePricesCacheKey = 'evm_bridge_prices_v1';
const String _bridgeSlippageKey = 'evm_bridge_slippage_bps_v1';
const String _bridgeSwapFromKey = 'evm_bridge_swap_from_v1';
const String _bridgeSwapToKey = 'evm_bridge_swap_to_v1';
const Duration _bridgeCacheTtl = Duration(minutes: 5);

// ─── Swap constants (PancakeSwap V2, BSC mainnet) ────────────────────────────
const String _swapRouterAddr = '0x10ED43C718714eb63d5aA57B78B54704E256024E';
const String _swapWbnbAddr = '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c';
const String _swapFeeWallet = '0x9C7C1058fdc9b710f688ECb7562924D9AE771417';
const int _swapFeeBps = 100; // 1%
const String _swapRouterAbi = r'''[
  {"name":"swapExactETHForTokens","type":"function","stateMutability":"payable",
   "inputs":[{"name":"amountOutMin","type":"uint256"},{"name":"path","type":"address[]"},
             {"name":"to","type":"address"},{"name":"deadline","type":"uint256"}],
   "outputs":[{"name":"amounts","type":"uint256[]"}]},
  {"name":"swapExactTokensForTokens","type":"function","stateMutability":"nonpayable",
   "inputs":[{"name":"amountIn","type":"uint256"},{"name":"amountOutMin","type":"uint256"},
             {"name":"path","type":"address[]"},{"name":"to","type":"address"},
             {"name":"deadline","type":"uint256"}],
   "outputs":[{"name":"amounts","type":"uint256[]"}]},
  {"name":"swapExactTokensForETH","type":"function","stateMutability":"nonpayable",
   "inputs":[{"name":"amountIn","type":"uint256"},{"name":"amountOutMin","type":"uint256"},
             {"name":"path","type":"address[]"},{"name":"to","type":"address"},
             {"name":"deadline","type":"uint256"}],
   "outputs":[{"name":"amounts","type":"uint256[]"}]},
  {"name":"getAmountsOut","type":"function","stateMutability":"view",
   "inputs":[{"name":"amountIn","type":"uint256"},{"name":"path","type":"address[]"}],
   "outputs":[{"name":"amounts","type":"uint256[]"}]}
]''';
const String _swapErc20ApproveAbi = r'''[
  {"name":"allowance","type":"function","stateMutability":"view",
   "inputs":[{"name":"owner","type":"address"},{"name":"spender","type":"address"}],
   "outputs":[{"name":"","type":"uint256"}]},
  {"name":"approve","type":"function","stateMutability":"nonpayable",
   "inputs":[{"name":"spender","type":"address"},{"name":"amount","type":"uint256"}],
   "outputs":[{"name":"","type":"bool"}]}
]''';
const String _swapErc20TransferAbi = r'''[
  {"name":"transfer","type":"function","stateMutability":"nonpayable",
   "inputs":[{"name":"recipient","type":"address"},{"name":"amount","type":"uint256"}],
   "outputs":[{"name":"","type":"bool"}]}
]''';
const String _swapPiBackendBase = String.fromEnvironment(
  'PI_BACKEND_URL',
  defaultValue: 'https://pi-backend-q2ye.onrender.com',
);
const List<String> _swapRpcUrls = [
  'https://bsc-dataseed1.binance.org/',
  'https://bsc-dataseed2.binance.org/',
  'https://bsc-dataseed3.binance.org/',
  'https://bsc-dataseed4.binance.org/',
];

Future<Web3Client> _pickSwapBscClient() async {
  Exception? lastError;
  for (final url in _swapRpcUrls) {
    final c = Web3Client(url, http.Client());
    try {
      await c.getBlockNumber().timeout(const Duration(seconds: 5));
      return c;
    } catch (e) {
      c.dispose();
      lastError = Exception('BSC RPC $url unreachable: $e');
    }
  }
  throw lastError ?? Exception('All BSC RPC endpoints are unavailable');
}

Future<EtherAmount> _swapLiveGasPrice(Web3Client client) async {
  try {
    final raw = (await client.getGasPrice()).getInWei;
    final buffered = raw * BigInt.from(11) ~/ BigInt.from(10);
    final floor = BigInt.from(1000000000);
    return EtherAmount.fromBigInt(
      EtherUnit.wei,
      buffered > floor ? buffered : floor,
    );
  } catch (_) {
    return EtherAmount.fromBigInt(EtherUnit.wei, BigInt.from(1000000000));
  }
}

Future<void> _reportSwapActivity({
  required String txHash,
  required String tokenSymbol,
  required String amount,
  required String evmAddress,
  required String anetAddress,
}) async {
  try {
    await http
        .post(
          Uri.parse('$_swapPiBackendBase/api/evm/activity'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'txHash': txHash,
            'activityType': 'swap',
            'tokenSymbol': tokenSymbol,
            'amount': amount,
            'evmAddress': evmAddress,
            'anetAddress': anetAddress,
            'chainId': 56,
          }),
        )
        .timeout(const Duration(seconds: 10));
  } catch (_) {}
}

const _pairs = [
  {'label': 'ANET/BNB', 'from': 'BNB', 'icon': '🟡'},
  {'label': 'ANET/USDT', 'from': 'USDT', 'icon': '💵'},
  {'label': 'ANET/USDC', 'from': 'USDC', 'icon': '🔵'},
  {'label': 'ANET/ETH', 'from': 'ETH', 'icon': '🔷'},
  {'label': 'ANET/BTCB', 'from': 'BTCB', 'icon': '🟠'},
  {'label': 'ANET/CAKE', 'from': 'CAKE', 'icon': '🥞'},
  {'label': 'ANET/BUSD', 'from': 'BUSD', 'icon': '💛'},
  {'label': 'ANET/ANET(BNB)', 'from': 'ANET', 'icon': '🅰'},
];

/// EVM → ANET L1 bridge page — MetaMask-style.
class EvmBridgePage extends StatefulWidget {
  const EvmBridgePage({
    super.key,
    required this.anetAddress,
    required this.evmAddress,
    required this.privKeyBytes,
  });

  final String anetAddress;
  final String evmAddress;
  final Uint8List privKeyBytes;

  @override
  State<EvmBridgePage> createState() => _EvmBridgePageState();
}

class _EvmBridgePageState extends State<EvmBridgePage> {
  final _service = EvmWalletService();

  int _selectedPairIdx = 0;
  String get _selectedToken => _pairs[_selectedPairIdx]['from']!;

  Map<String, String> _balances = {};
  BigInt _bnbBalanceWei = BigInt.zero;
  Map<String, BigInt> _erc20BalancesWei = {};
  bool _balancesLoading = false;

  /// USD prices keyed by token symbol. Populated by [_loadPrices].
  Map<String, double> _prices = {};

  BigInt _gasPriceWei = BigInt.from(3000000000);
  // ignore: unused_field
  int _bscBlock = 0;
  BigInt _bridgeMinWei = BigInt.from(10000000000000000); // 0.01 BNB default
  /// Per-token on-chain limits fetched from `tokenConfigs(token)` on AnetSwap.
  /// Checked BEFORE submitting a bridge tx so the user gets a clear error
  /// instead of paying gas on a guaranteed BSC revert.
  Map<String, TokenBridgeConfig> _tokenLimits = {};
  Timer? _networkTimer;

  final _amountCtrl = TextEditingController();
  Timer? _amountDebounce;
  String _estimatedReceive = '';

  bool _bridging = false;
  String? _statusMsg;
  bool _statusSuccess = false;
  String? _txHash;

  List<Map<String, dynamic>> _history = [];

  Timer? _pollTimer;
  int _pollCount = 0;

  // MetaMask-style UI state.
  int _selectedTab = 0; // 0=Tokens, 1=Bridge, 2=Activity
  int _selectedChainIdx = 0; // 0 = BNB Smart Chain (only one active)
  bool _balanceHidden = false;

  /// Bridge chains. Only BNB Smart Chain is live; others are "Coming soon".
  static const List<Map<String, dynamic>> _chains = [
    {
      'name': 'BNB Smart Chain',
      'short': 'BNB Chain',
      'icon': '🟡',
      'color': 0xFFF0B90B,
      'available': true,
    },
    {
      'name': 'Ethereum',
      'short': 'Ethereum',
      'icon': '🔷',
      'color': 0xFF627EEA,
      'available': false,
    },
    {
      'name': 'Polygon',
      'short': 'Polygon',
      'icon': '🟣',
      'color': 0xFF8247E5,
      'available': false,
    },
    {
      'name': 'Arbitrum One',
      'short': 'Arbitrum',
      'icon': '🔵',
      'color': 0xFF28A0F0,
      'available': false,
    },
    {
      'name': 'Base',
      'short': 'Base',
      'icon': '🟦',
      'color': 0xFF0052FF,
      'available': false,
    },
    {
      'name': 'Optimism',
      'short': 'Optimism',
      'icon': '🔴',
      'color': 0xFFFF0420,
      'available': false,
    },
  ];

  Map<String, dynamic> get _chain => _chains[_selectedChainIdx];

  @override
  void initState() {
    super.initState();
    _loadCached();
    _loadBalances();
    _loadHistory();
    _loadNetworkInfo();
    _loadBridgeConfig();
    _loadUsername();
    _loadPrices();
    _networkTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _loadNetworkInfo(),
    );
  }

  /// Instantly paint the last-known balances and prices from SharedPreferences
  /// so the UI is populated before the network requests finish.
  Future<void> _loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final balRaw = prefs.getString(_bridgeBalancesCacheKey);
      final pxRaw = prefs.getString(_bridgePricesCacheKey);
      if (!mounted) return;
      if (balRaw != null) {
        final m = jsonDecode(balRaw) as Map<String, dynamic>;
        final addr = (m['address'] as String?) ?? '';
        if (addr.toLowerCase() == widget.evmAddress.toLowerCase()) {
          final bal = Map<String, String>.from(m['balances'] as Map);
          final rawBnb = m['bnbWei'] as String? ?? '0';
          final rawErc = Map<String, dynamic>.from(m['erc20Wei'] as Map? ?? {});
          setState(() {
            _balances = bal;
            _bnbBalanceWei = BigInt.tryParse(rawBnb) ?? BigInt.zero;
            _erc20BalancesWei = rawErc.map(
              (k, v) => MapEntry(k, BigInt.tryParse('$v') ?? BigInt.zero),
            );
          });
        }
      }
      if (pxRaw != null) {
        final m = jsonDecode(pxRaw) as Map<String, dynamic>;
        final ts = DateTime.tryParse(m['ts'] as String? ?? '');
        if (ts != null && DateTime.now().difference(ts) < _bridgeCacheTtl) {
          final px = Map<String, dynamic>.from(m['prices'] as Map);
          setState(() {
            _prices = px.map((k, v) => MapEntry(k, (v as num).toDouble()));
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _saveBalancesCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _bridgeBalancesCacheKey,
        jsonEncode({
          'address': widget.evmAddress,
          'ts': DateTime.now().toUtc().toIso8601String(),
          'balances': _balances,
          'bnbWei': _bnbBalanceWei.toString(),
          'erc20Wei': _erc20BalancesWei.map(
            (k, v) => MapEntry(k, v.toString()),
          ),
        }),
      );
    } catch (_) {}
  }

  Future<void> _savePricesCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _bridgePricesCacheKey,
        jsonEncode({
          'ts': DateTime.now().toUtc().toIso8601String(),
          'prices': _prices,
        }),
      );
    } catch (_) {}
  }

  /// Fetch USD prices from CoinGecko for the live BSC tokens. Best-effort —
  /// errors are silently swallowed; the UI falls back to `$0.00` when prices
  /// are unavailable.
  Future<void> _loadPrices() async {
    if (!mounted) return;
    try {
      const ids =
          'binancecoin,tether,usd-coin,binance-usd,dai,true-usd,'
          'ethereum,bitcoin,pancakeswap-token,'
          'dogecoin,shiba-inu,matic-network,cardano,ripple,litecoin,'
          'chainlink,polkadot,avalanche-2,solana,uniswap,tron,trust-wallet-token';
      final res = await http
          .get(
            Uri.parse(
              'https://api.coingecko.com/api/v3/simple/price'
              '?ids=$ids&vs_currencies=usd',
            ),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        double price(String id) => (data[id]?['usd'] as num?)?.toDouble() ?? 0;
        if (mounted) {
          setState(() {
            _prices = {
              'BNB': price('binancecoin'),
              'USDT': price('tether') == 0 ? 1 : price('tether'),
              'USDC': price('usd-coin') == 0 ? 1 : price('usd-coin'),
              'BUSD': price('binance-usd') == 0 ? 1 : price('binance-usd'),
              'DAI': price('dai') == 0 ? 1 : price('dai'),
              'TUSD': price('true-usd') == 0 ? 1 : price('true-usd'),
              'ETH': price('ethereum'),
              'BTCB': price('bitcoin'),
              'CAKE': price('pancakeswap-token'),
              'DOGE': price('dogecoin'),
              'SHIB': price('shiba-inu'),
              'MATIC': price('matic-network'),
              'ADA': price('cardano'),
              'XRP': price('ripple'),
              'LTC': price('litecoin'),
              'LINK': price('chainlink'),
              'DOT': price('polkadot'),
              'AVAX': price('avalanche-2'),
              'SOL': price('solana'),
              'UNI': price('uniswap'),
              'TRX': price('tron'),
              'TWT': price('trust-wallet-token'),
              'ANET': 0,
            };
          });
          unawaited(_savePricesCache());
        }
      }
    } catch (_) {}
  }

  /// Returns total wallet value across all live tokens in USD.
  double _totalUsdBalance() {
    double total = 0;
    for (final entry in bscTokens.entries) {
      final sym = entry.key;
      final info = entry.value;
      final dec = info['decimals'] as int;
      final raw = (info['native'] == true)
          ? _bnbBalanceWei
          : (_erc20BalancesWei[sym] ?? BigInt.zero);
      if (raw <= BigInt.zero) continue;
      final amt = raw / BigInt.from(10).pow(dec);
      total += amt * (_prices[sym] ?? 0);
    }
    return total;
  }

  String? _primaryUsername;

  Future<void> _loadUsername() async {
    if (!mounted) return;
    try {
      final name = await usernameRegistry.reverseResolve(widget.evmAddress);
      if (mounted) setState(() => _primaryUsername = name);
    } catch (_) {}
  }

  @override
  void dispose() {
    _networkTimer?.cancel();
    _amountDebounce?.cancel();
    _pollTimer?.cancel();
    _service.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  EthPrivateKey get _credentials => EthPrivateKey(widget.privKeyBytes);

  Future<void> _loadNetworkInfo() async {
    try {
      final gas = await _service.getGasPrice();
      final block = await _service.getCurrentBlock();
      if (!mounted) return;
      setState(() {
        _gasPriceWei = gas;
        _bscBlock = block;
      });
    } catch (_) {}
  }

  Future<void> _loadBridgeConfig() async {
    try {
      // address(0) = native BNB on BSC
      final zero = EthereumAddress.fromHex(
        '0x0000000000000000000000000000000000000000',
      );
      final min = await _service.getBridgeMinAmount(zero);
      if (min != null && min > BigInt.zero && mounted) {
        setState(() => _bridgeMinWei = min);
      }

      // Load per-token (ERC-20) on-chain limits so we can pre-validate
      // amounts and avoid paying gas on a guaranteed contract revert.
      final Map<String, TokenBridgeConfig> limits = {};
      for (final entry in bscTokens.entries) {
        final info = entry.value;
        if (info['native'] == true) continue;
        final addrStr = info['address'] as String;
        if (addrStr.isEmpty) continue;
        try {
          final cfg = await _service.getTokenConfig(
            EthereumAddress.fromHex(addrStr),
          );
          if (cfg != null) limits[entry.key] = cfg;
        } catch (_) {}
      }
      if (mounted && limits.isNotEmpty) {
        setState(() => _tokenLimits = limits);
      }
    } catch (_) {}
  }

  Future<void> _loadBalances() async {
    if (widget.evmAddress.isEmpty) return;
    setState(() => _balancesLoading = true);
    try {
      final addr = EthereumAddress.fromHex(widget.evmAddress);
      final Map<String, String> result = {};

      final bnbWei = await _service.getBnbBalance(addr);
      if (mounted) setState(() => _bnbBalanceWei = bnbWei);
      result['BNB'] = formatUnits(bnbWei, 18, displayDecimals: 5);

      final Map<String, BigInt> rawBalances = {};
      // Load balances for all known ERC-20 tokens
      for (final entry in bscTokens.entries) {
        final sym = entry.key;
        final info = entry.value;
        if (info['native'] == true) continue; // skip native BNB
        try {
          final tokenAddr = EthereumAddress.fromHex(info['address'] as String);
          final bal = await _service.getErc20Balance(addr, tokenAddr);
          rawBalances[sym] = bal;
          result[sym] = formatUnits(
            bal,
            info['decimals'] as int,
            displayDecimals: 4,
          );
        } catch (_) {
          rawBalances[sym] = BigInt.zero;
          result[sym] = '—';
        }
      }
      if (mounted) setState(() => _erc20BalancesWei = rawBalances);

      if (!mounted) return;
      setState(() {
        _balances = result;
        _balancesLoading = false;
      });
      unawaited(_saveBalancesCache());
    } catch (_) {
      if (!mounted) return;
      setState(() => _balancesLoading = false);
    }
  }

  void _onAmountChanged(String _) {
    _amountDebounce?.cancel();
    _amountDebounce = Timer(const Duration(milliseconds: 300), _updateEstimate);
    if (mounted) setState(() {});
  }

  void _updateEstimate() {
    final amt = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (!mounted) return;
    if (amt <= 0) {
      setState(() => _estimatedReceive = '');
      return;
    }
    final est = amt * 0.99;
    setState(() => _estimatedReceive = '≈ ${_fmtAmt(est)} ANET');
  }

  String _fmtAmt(double v) {
    if (v >= 1000) return v.toStringAsFixed(2);
    if (v >= 1) return v.toStringAsFixed(4);
    return v.toStringAsFixed(6);
  }

  String _computeMaxBnb() {
    final gasLimit = BigInt.from(220000);
    final gasReserve =
        gasLimit * _gasPriceWei * BigInt.from(3) ~/ BigInt.from(2);
    if (_bnbBalanceWei <= gasReserve) return '0';
    return formatUnits(_bnbBalanceWei - gasReserve, 18, displayDecimals: 6);
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_bridgeHistoryKey) ?? [];
      if (!mounted) return;
      setState(() {
        _history = raw
            .map((s) => Map<String, dynamic>.from(jsonDecode(s) as Map))
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _saveHistory(Map<String, dynamic> entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final updated = [entry, ..._history].take(25).toList();
      await prefs.setStringList(
        _bridgeHistoryKey,
        updated.map((e) => jsonEncode(e)).toList(),
      );
      if (!mounted) return;
      setState(() => _history = updated);
    } catch (_) {}
  }

  /// Clears all locally-stored bridge history after confirmation.
  /// Does NOT touch on-chain data — receipts remain on BscScan forever.
  Future<void> _clearHistory() async {
    if (_history.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1224),
        title: const Text(
          'Clear bridge history?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This removes the local list only. On-chain receipts on BscScan are not affected.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white60),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_bridgeHistoryKey);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _history = []);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Bridge history cleared')));
  }

  /// Copies the current bridge history as JSON to the clipboard so the user
  /// can paste it into a note, support ticket, or spreadsheet.
  Future<void> _exportHistory() async {
    if (_history.isEmpty) return;
    final payload = const JsonEncoder.withIndent('  ').convert(_history);
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${_history.length} entries as JSON')),
    );
  }

  Future<void> _executeBridge() async {
    final amtStr = _amountCtrl.text.trim();
    final amt = double.tryParse(amtStr);
    if (amt == null || amt <= 0) {
      _setStatus('Enter a valid amount.', success: false);
      return;
    }
    if (!widget.anetAddress.startsWith('ANET')) {
      _setStatus('ANET L1 wallet not connected.', success: false);
      return;
    }

    setState(() {
      _bridging = true;
      _statusMsg = 'Preparing transaction…';
      _statusSuccess = false;
      _txHash = null;
    });

    try {
      final tokenInfo = bscTokens[_selectedToken]!;
      final isNative = tokenInfo['native'] as bool;
      final decimals = tokenInfo['decimals'] as int;
      final amountUnits = parseUnits(amtStr, decimals);

      // Enforce contract minimum bridge amount for native BNB.
      if (isNative && amountUnits < _bridgeMinWei) {
        final minFmt = formatUnits(_bridgeMinWei, 18, displayDecimals: 4);
        _setStatus(
          'Minimum bridge amount is $minFmt BNB. '
          'Please enter at least $minFmt BNB.',
          success: false,
        );
        setState(() => _bridging = false);
        return;
      }

      if (!isNative) {
        // On-chain per-token limit guard — must pass BEFORE we send so the
        // user doesn't burn BSC gas on a contract revert. The contract's
        // `tokenConfigs(token)` view returns `accepted` + min/max per tx.
        final cfg = _tokenLimits[_selectedToken];
        if (cfg != null) {
          if (!cfg.accepted) {
            _setStatus(
              '$_selectedToken is not currently accepted by the bridge. '
              'Please pick a different token.',
              success: false,
            );
            setState(() => _bridging = false);
            return;
          }
          if (cfg.minAmount > BigInt.zero && amountUnits < cfg.minAmount) {
            final minFmt = formatUnits(
              cfg.minAmount,
              decimals,
              displayDecimals: 4,
            );
            _setStatus(
              'Minimum bridge amount is $minFmt $_selectedToken. '
              'Please increase the amount.',
              success: false,
            );
            setState(() => _bridging = false);
            return;
          }
          if (cfg.maxAmount > BigInt.zero && amountUnits > cfg.maxAmount) {
            final maxFmt = formatUnits(
              cfg.maxAmount,
              decimals,
              displayDecimals: 4,
            );
            _setStatus(
              'Maximum bridge amount is $maxFmt $_selectedToken per tx. '
              'Please reduce the amount or bridge in smaller batches.',
              success: false,
            );
            setState(() => _bridging = false);
            return;
          }
        }

        final tokenBalance = _erc20BalancesWei[_selectedToken] ?? BigInt.zero;
        if (amountUnits > tokenBalance) {
          final balFmt = formatUnits(
            tokenBalance,
            decimals,
            displayDecimals: 4,
          );
          _setStatus(
            'Insufficient $_selectedToken balance. '
            'You have $balFmt $_selectedToken.',
            success: false,
          );
          setState(() => _bridging = false);
          return;
        }
      }

      if (isNative) {
        final gasLimit = BigInt.from(220000);
        final gasPrice = _gasPriceWei > BigInt.zero
            ? _gasPriceWei
            : BigInt.from(3000000000);
        final gasCost = gasLimit * gasPrice;

        if (amountUnits + gasCost > _bnbBalanceWei) {
          final maxBridge = _bnbBalanceWei > gasCost
              ? _bnbBalanceWei - gasCost
              : BigInt.zero;
          final gasFmt = formatUnits(gasCost, 18, displayDecimals: 6);
          final maxFmt = formatUnits(maxBridge, 18, displayDecimals: 5);
          _setStatus(
            'Insufficient BNB for gas fees (~$gasFmt BNB). '
            'Max you can bridge: $maxFmt BNB. Use the MAX button.',
            success: false,
          );
          setState(() => _bridging = false);
          return;
        }
      } else {
        // Pre-flight BNB gas reserve check for ERC20 bridges. ERC20 bridge
        // costs ~600k (swap) + ~100k (approve) = ~750k gas at 3 gwei =
        // ~0.00225 BNB. Block submit if the wallet can't cover it so we don't
        // burn gas on an out-of-gas revert.
        final gasLimit = BigInt.from(750000);
        final gasPrice = _gasPriceWei > BigInt.zero
            ? _gasPriceWei
            : BigInt.from(3000000000);
        final gasCost = gasLimit * gasPrice;
        if (gasCost > _bnbBalanceWei) {
          final needFmt = formatUnits(gasCost, 18, displayDecimals: 6);
          final haveFmt = formatUnits(_bnbBalanceWei, 18, displayDecimals: 6);
          _setStatus(
            'Insufficient BNB for gas (~$needFmt BNB needed, you have $haveFmt). '
            'Add BNB to your wallet to cover network fees, then retry.',
            success: false,
          );
          setState(() => _bridging = false);
          return;
        }
      }

      String txHash;
      if (isNative) {
        _setStatus('Step 1/2 — Broadcasting to BSC…');
        txHash = await _service.bridgeNative(
          credentials: _credentials,
          amountWei: amountUnits,
          anetRecipient: widget.anetAddress,
        );
      } else {
        _setStatus('Step 1/3 — Approving token spend…');
        txHash = await _service.bridgeToken(
          credentials: _credentials,
          tokenSymbol: _selectedToken,
          amountUnits: amountUnits,
          anetRecipient: widget.anetAddress,
        );
      }

      setState(() => _txHash = txHash);
      _setStatus('Step 2 — Waiting for BSC confirmation…');

      try {
        await bridgeEvmNotifyAPI(
          txHash: txHash,
          chainId: bscChainId,
          fromAddress: widget.evmAddress,
          anetRecipient: widget.anetAddress,
          amount: amtStr,
          tokenSymbol: _selectedToken,
        );
      } catch (_) {}

      final receipt = await _service.waitForReceipt(txHash);
      if (receipt == null) {
        _setStatus('TX broadcast — confirming on BSC…', success: true);
      } else if (receipt.status == true) {
        _setStatus(
          'BSC confirmed (block #${receipt.blockNumber.blockNum}) — crediting ANET L1…',
          success: true,
        );
      } else {
        _setStatus(
          'Transaction reverted on BSC. No funds were lost.',
          success: false,
        );
        // Persist the failed attempt so the user can see it in Activity and
        // tap Retry to re-submit with the same token + amount.
        await _saveHistory({
          'ts': DateTime.now().toUtc().toIso8601String(),
          'token': _selectedToken,
          'amount': amtStr,
          'txHash': txHash,
          'anetRecipient': widget.anetAddress,
          'status': 'failed',
        });
        setState(() => _bridging = false);
        return;
      }

      await _saveHistory({
        'ts': DateTime.now().toUtc().toIso8601String(),
        'token': _selectedToken,
        'amount': amtStr,
        'txHash': txHash,
        'anetRecipient': widget.anetAddress,
        'status': 'pending',
      });

      _startPolling(txHash);
    } catch (e) {
      if (!mounted) return;
      _setStatus(_humanizeRpcError(e.toString()), success: false);
      setState(() => _bridging = false);
    }
  }

  String _humanizeRpcError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('insufficient funds')) {
      return 'Insufficient BNB — the amount + gas fees exceed your balance. '
          'Use the MAX button to see the safe maximum.';
    }
    if (lower.contains('execution reverted') ||
        lower.contains('-32000') ||
        lower.contains('revert')) {
      return 'Transaction reverted by the smart contract. '
          'Check your balance and try a smaller amount.';
    }
    if (lower.contains('nonce too low')) {
      return 'Nonce conflict — a previous transaction may still be pending. '
          'Wait a few seconds and retry.';
    }
    if (lower.contains('already known')) {
      return 'This transaction was already submitted. Wait for BSC to confirm it.';
    }
    if (lower.contains('network') ||
        lower.contains('timeout') ||
        lower.contains('socket') ||
        lower.contains('connection')) {
      return 'Network error — could not reach BSC. Check your connection and try again.';
    }
    return raw
        .replaceFirst('Exception: ', '')
        .replaceFirst('RPCError: ', '')
        .replaceFirst('FormatException: ', '');
  }

  void _startPolling(String txHash) {
    _pollCount = 0;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) async {
      _pollCount++;
      if (_pollCount > 20) {
        _pollTimer?.cancel();
        if (mounted) {
          setState(() => _bridging = false);
          _setStatus(
            'TX sent. ANET L1 credit may take a few minutes.',
            success: true,
          );
        }
        return;
      }
      try {
        final status = await bridgeEvmStatusAPI(txHash);
        if (status['processed'] == true) {
          _pollTimer?.cancel();
          if (!mounted) return;
          setState(() => _bridging = false);
          _setStatus(
            'ANET L1 credited! TxID: ${status['anetTxId'] ?? 'confirmed'}',
            success: true,
          );
          _amountCtrl.clear();
          setState(() => _estimatedReceive = '');
          _loadBalances();
          final updated = _history.map((h) {
            if (h['txHash'] == txHash) {
              return {
                ...h,
                'status': 'completed',
                'anetTxId': status['anetTxId'],
              };
            }
            return h;
          }).toList();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList(
            _bridgeHistoryKey,
            updated.map((e) => jsonEncode(e)).toList(),
          );
          if (mounted) setState(() => _history = updated);
        }
      } catch (_) {}
    });
  }

  void _setStatus(String msg, {bool success = false}) {
    if (!mounted) return;
    setState(() {
      _statusMsg = msg;
      _statusSuccess = success;
    });
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _openBscScan(String txHash) async {
    if (txHash.isEmpty) return;
    final uri = Uri.parse('https://bscscan.com/tx/$txHash');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    _copy(txHash);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('TX hash copied — paste into BscScan'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _blue,
      backgroundColor: _surface,
      onRefresh: () async {
        await _loadNetworkInfo();
        await _loadBalances();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAccountHeader(),
            const SizedBox(height: 22),
            _buildBigBalance(),
            const SizedBox(height: 22),
            _buildActionButtons(),
            const SizedBox(height: 24),
            _buildTabBar(),
            const SizedBox(height: 14),
            if (_selectedTab == 0) ...[
              _buildChainPickerBar(),
              const SizedBox(height: 10),
              _buildTokensList(),
            ] else if (_selectedTab == 1) ...[
              _buildChainPickerBar(),
              const SizedBox(height: 12),
              _buildPairSelector(),
              const SizedBox(height: 14),
              _buildSwapCard(),
              if (_statusMsg != null) ...[
                const SizedBox(height: 12),
                _buildStatusCard(),
              ],
              if (_txHash != null) ...[
                const SizedBox(height: 8),
                _buildTxHashCard(),
              ],
              const SizedBox(height: 22),
              _buildInfoFooter(),
            ] else ...[
              _buildActivityTab(),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  MetaMask-style header (account name + address pill).
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAccountHeader() {
    final evmShort = _shortAddr(widget.evmAddress);
    return Row(
      children: [
        // Avatar — chain badge stack to hint multi-chain.
        SizedBox(
          width: 28,
          height: 22,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                child: _AvatarCircle(
                  color: Color(_chain['color'] as int),
                  label: _chain['icon'] as String,
                ),
              ),
              const Positioned(
                left: 9,
                child: _AvatarCircle(color: Color(0xFF25C474), label: '🅰'),
              ),
              const Positioned(
                left: 18,
                child: _AvatarCircle(color: Color(0xFF627EEA), label: '🔷'),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      (_primaryUsername ?? '').isNotEmpty
                          ? '@$_primaryUsername'
                          : 'NFT Passport',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if ((_primaryUsername ?? '').isNotEmpty) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified_rounded,
                      color: Color(0xFF25C474),
                      size: 14,
                    ),
                  ],
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white.withValues(alpha: 0.6),
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: () => _copy(widget.evmAddress),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      evmShort,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.copy,
                      size: 11,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.menu,
            color: Colors.white.withValues(alpha: 0.7),
            size: 22,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: _showAccountMenu,
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Big hidden-style balance + Discover link.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBigBalance() {
    final tokenCount = _balances.length;
    final usd = _totalUsdBalance();
    final usdLabel = _balanceHidden ? '••••••' : '\$${usd.toStringAsFixed(2)}';
    final subLabel = _balanceHidden
        ? '••••••'
        : (tokenCount > 0 ? '$tokenCount Tokens' : '—');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _balanceHidden = !_balanceHidden),
          child: Row(
            children: [
              Text(
                usdLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                _balanceHidden
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: Colors.white.withValues(alpha: 0.4),
                size: 20,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              subLabel,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _setTab(1),
              child: const Row(
                children: [
                  Text(
                    'Bridge',
                    style: TextStyle(
                      color: _blue,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 3),
                  Icon(Icons.open_in_new, color: _blue, size: 13),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Four action buttons row: Buy, Swap, Send, Receive.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _actionButton(
          icon: Icons.attach_money,
          label: 'Buy',
          onTap: _showComingSoon,
        ),
        _actionButton(
          icon: Icons.swap_horiz_rounded,
          label: 'Swap',
          onTap: _openSwapSheet,
        ),
        _actionButton(
          icon: Icons.send_outlined,
          label: 'Send',
          onTap: _openSendSheet,
        ),
        _actionButton(
          icon: Icons.south_west,
          label: 'Receive',
          onTap: _showReceiveSheet,
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Tab bar: Tokens | Bridge | Activity.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    const tabs = ['Tokens', 'Bridge', 'Activity'];
    return Row(
      children: List.generate(tabs.length, (i) {
        final sel = i == _selectedTab;
        return Padding(
          padding: const EdgeInsets.only(right: 20),
          child: GestureDetector(
            onTap: () => _setTab(i),
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tabs[i],
                  style: TextStyle(
                    color: sel
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    fontSize: 16,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 36,
                  height: 2,
                  color: sel ? Colors.white : Colors.transparent,
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  void _setTab(int i) {
    if (_selectedTab == i) return;
    setState(() => _selectedTab = i);
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Chain dropdown + filter/menu row.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildChainPickerBar() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _showChainPicker,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    _chain['icon'] as String,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _chain['short'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: _green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _squareIconButton(Icons.tune, _showComingSoon),
        const SizedBox(width: 8),
        _squareIconButton(Icons.more_vert, _showAccountMenu),
      ],
    );
  }

  Widget _squareIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.85),
          size: 20,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Tokens tab body — list of BSC tokens with balance.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTokensList() {
    if (_balances.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 36),
        alignment: Alignment.center,
        child: _balancesLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: _blue, strokeWidth: 2),
              )
            : Text(
                'No tokens detected on ${_chain['short']}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              ),
      );
    }
    return Column(
      children: _balances.entries.map((e) {
        final sym = e.key;
        final balDisplay = e.value;
        final info = bscTokens[sym];
        final iconText = _iconFor(sym);
        final iconColor = _colorFor(sym);
        return _tokenRow(
          symbol: sym,
          name: (info?['name'] as String?) ?? sym,
          icon: iconText,
          iconColor: iconColor,
          balance: balDisplay,
          onTap: () {
            setState(() {
              final idx = _pairs.indexWhere((p) => p['from'] == sym);
              if (idx >= 0) _selectedPairIdx = idx;
              _selectedTab = 1;
            });
          },
        );
      }).toList(),
    );
  }

  Widget _tokenRow({
    required String symbol,
    required String name,
    required String icon,
    required Color iconColor,
    required String balance,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(icon, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Bridge to ANET L1',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _balanceHidden ? '••••••' : balance,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  symbol,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _iconFor(String sym) {
    for (final p in _pairs) {
      if (p['from'] == sym) return p['icon'] ?? '🔘';
    }
    return '🔘';
  }

  Color _colorFor(String sym) {
    switch (sym) {
      case 'BNB':
        return const Color(0xFFF0B90B);
      case 'USDT':
        return const Color(0xFF26A17B);
      case 'USDC':
        return const Color(0xFF2775CA);
      case 'ETH':
        return const Color(0xFF627EEA);
      case 'BTCB':
        return const Color(0xFFF7931A);
      case 'CAKE':
        return const Color(0xFFD1884F);
      case 'BUSD':
        return const Color(0xFFF0B90B);
      case 'ANET':
        return const Color(0xFF25C474);
      default:
        return const Color(0xFF1A2744);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Activity tab body — bridge history (re-uses existing _buildHistory).
  //  Wrapped in a bounded SizedBox so the inner RefreshIndicator's ListView
  //  gets finite height inside the outer Column/SingleChildScrollView.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildActivityTab() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.55,
      child: RefreshIndicator(
        color: _blue,
        backgroundColor: _card,
        onRefresh: () async {
          await _loadHistory();
          // Re-poll any still-pending transactions so the user sees fresh
          // statuses without leaving the tab.
          for (final h in _history) {
            final tx = h['txHash'] as String? ?? '';
            final status = h['status'] as String? ?? '';
            if (tx.isNotEmpty && status != 'completed' && status != 'failed') {
              unawaited(Future(() => _startPolling(tx)));
            }
          }
        },
        child: _history.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 56),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          color: Colors.white.withValues(alpha: 0.3),
                          size: 42,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No bridge activity yet',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Pull down to refresh',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [_buildHistory()],
              ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Bottom sheets.
  // ─────────────────────────────────────────────────────────────────────────
  void _showChainPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Select Network',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                ..._chains.asMap().entries.map((entry) {
                  final i = entry.key;
                  final c = entry.value;
                  final available = c['available'] as bool;
                  final sel = i == _selectedChainIdx;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(
                          c['color'] as int,
                        ).withValues(alpha: available ? 1.0 : 0.25),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        c['icon'] as String,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                    title: Text(
                      c['name'] as String,
                      style: TextStyle(
                        color: available
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.45),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: available
                        ? const Text(
                            'Live · ANET L1 bridge enabled',
                            style: TextStyle(color: _green, fontSize: 11),
                          )
                        : Text(
                            'Coming soon',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                            ),
                          ),
                    trailing: available
                        ? (sel
                              ? const Icon(Icons.check_circle, color: _green)
                              : const Icon(Icons.chevron_right, color: _muted))
                        : Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Soon',
                              style: TextStyle(
                                color: _gold,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                    onTap: () {
                      if (!available) return;
                      setState(() => _selectedChainIdx = i);
                      Navigator.pop(ctx);
                    },
                    enabled: available,
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coming soon'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _openSwapSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0A1224),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => _BridgeSwapSheet(
        evmAddress: widget.evmAddress,
        anetAddress: widget.anetAddress,
        privKeyBytes: widget.privKeyBytes,
      ),
    ).then((_) => _loadBalances());
  }

  void _showAccountMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: const Icon(Icons.copy, color: Colors.white),
                  title: const Text(
                    'Copy BSC address',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _copy(widget.evmAddress);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.copy_all, color: Colors.white),
                  title: const Text(
                    'Copy ANET L1 address',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _copy(widget.anetAddress);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.refresh, color: Colors.white),
                  title: const Text(
                    'Refresh balances',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _loadBalances();
                    _loadNetworkInfo();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.open_in_new, color: Colors.white),
                  title: const Text(
                    'View on BscScan',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final uri = Uri.parse(
                      'https://bscscan.com/address/${widget.evmAddress}',
                    );
                    try {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (_) {}
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showReceiveSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool showBscQr = true;
        return StatefulBuilder(
          builder: (ctx2, setSt) {
            final address = showBscQr ? widget.evmAddress : widget.anetAddress;
            final chainLabel = showBscQr ? 'BNB Smart Chain (BSC)' : 'ANET L1';
            final chainColor = showBscQr ? const Color(0xFFF0B90B) : _green;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Receive',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Chain toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _chainToggleBtn(
                          label: 'BSC',
                          color: const Color(0xFFF0B90B),
                          selected: showBscQr,
                          onTap: () => setSt(() => showBscQr = true),
                        ),
                        const SizedBox(width: 10),
                        _chainToggleBtn(
                          label: 'ANET L1',
                          color: _green,
                          selected: !showBscQr,
                          onTap: () => setSt(() => showBscQr = false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // QR code
                    if (address.isNotEmpty)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: QrImageView(
                            data: address,
                            version: QrVersions.auto,
                            size: 190,
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    // Chain label
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: chainColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          chainLabel,
                          style: TextStyle(
                            color: chainColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Address row
                    _receiveRow(
                      label: chainLabel,
                      address: address,
                      color: chainColor,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _chainToggleBtn({
    required String label,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : _muted,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _receiveRow({
    required String label,
    required String address,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  address.isNotEmpty ? address : '—',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _copy(address),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.copy, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openSendSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0A1224),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => _BridgeSendSheet(
        evmAddress: widget.evmAddress,
        anetAddress: widget.anetAddress,
        privKeyBytes: widget.privKeyBytes,
        rawBalances: {'BNB': _bnbBalanceWei, ..._erc20BalancesWei},
      ),
    ).then((_) => _loadBalances());
  }

  String _shortAddr(String a) {
    if (a.length < 14) return a;
    return '${a.substring(0, 6)}…${a.substring(a.length - 4)}';
  }

  Widget _buildPairSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SELECT PAIR',
          style: TextStyle(
            color: _muted,
            fontSize: 11,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(_pairs.length, (i) {
              final pair = _pairs[i];
              final sel = i == _selectedPairIdx;
              return GestureDetector(
                onTap: _bridging
                    ? null
                    : () {
                        setState(() {
                          _selectedPairIdx = i;
                          _amountCtrl.clear();
                          _estimatedReceive = '';
                          _statusMsg = null;
                          _txHash = null;
                        });
                      },
                child: Container(
                  margin: EdgeInsets.only(right: i < _pairs.length - 1 ? 8 : 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: sel ? _blue : _card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sel ? _blue : _muted.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(pair['icon']!, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        pair['label']!,
                        style: TextStyle(
                          color: sel ? Colors.white : _muted,
                          fontSize: 13,
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildSwapCard() {
    final token = _selectedToken;
    final bal = _balances[token] ?? '—';
    final pair = _pairs[_selectedPairIdx];
    final tokenInfo = bscTokens[token]!;
    final isNative = tokenInfo['native'] as bool;
    final showMax = isNative
        ? _bnbBalanceWei > BigInt.zero
        : (_erc20BalancesWei[token] ?? BigInt.zero) > BigInt.zero;

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'You Pay',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'Balance: $bal',
                          style: const TextStyle(color: _muted, fontSize: 11),
                        ),
                        if (showMax) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _bridging
                                ? null
                                : () {
                                    final String max;
                                    if (isNative) {
                                      max = _computeMaxBnb();
                                    } else {
                                      final rawBal =
                                          _erc20BalancesWei[token] ??
                                          BigInt.zero;
                                      final dec = tokenInfo['decimals'] as int;
                                      max = formatUnits(
                                        rawBal,
                                        dec,
                                        displayDecimals: 6,
                                      );
                                    }
                                    if (max != '0') {
                                      _amountCtrl.text = max;
                                      _onAmountChanged(max);
                                    }
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
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        enabled: !_bridging,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          hintText: '0.0',
                          hintStyle: TextStyle(
                            color: Color(0xFF3A4460),
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'),
                          ),
                        ],
                        onChanged: _onAmountChanged,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          Text(
                            pair['icon']!,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            token,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down,
                            color: _muted,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Minimum bridge amount hint for native BNB
          if (_selectedToken == 'BNB')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
              child: Text(
                'Min: ${formatUnits(_bridgeMinWei, 18, displayDecimals: 4)} BNB',
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
            ),
          Stack(
            alignment: Alignment.center,
            children: [
              const Divider(color: Color(0xFF1A2744), height: 1),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _blue.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: const Icon(Icons.arrow_downward, color: _blue, size: 16),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'You Receive',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '1% bridge fee',
                        style: TextStyle(color: _green, fontSize: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _estimatedReceive.isNotEmpty
                                ? _estimatedReceive
                                : 'ANET',
                            style: TextStyle(
                              color: _estimatedReceive.isNotEmpty
                                  ? Colors.white
                                  : const Color(0xFF3A4460),
                              fontSize: _estimatedReceive.isNotEmpty ? 24 : 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_estimatedReceive.isNotEmpty)
                            const Text(
                              'estimated — actual depends on contract rate',
                              style: TextStyle(color: _muted, fontSize: 10),
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
                        color: _green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _green.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Text('🅰', style: TextStyle(fontSize: 16)),
                          SizedBox(width: 6),
                          Text(
                            'ANET',
                            style: TextStyle(
                              color: _green,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'L1',
                            style: TextStyle(color: _muted, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet,
                      color: _green,
                      size: 13,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.anetAddress.isNotEmpty
                            ? widget.anetAddress
                            : 'No ANET wallet connected',
                        style: const TextStyle(color: _muted, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _bridging ? null : _executeBridge,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  disabledBackgroundColor: _blue.withValues(alpha: 0.35),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _bridging
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Processing…',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        'Bridge $token → ANET L1',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _statusSuccess
            ? _green.withValues(alpha: 0.1)
            : _red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _statusSuccess
              ? _green.withValues(alpha: 0.4)
              : _red.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_bridging)
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: SizedBox(
                height: 14,
                width: 14,
                child: CircularProgressIndicator(color: _blue, strokeWidth: 2),
              ),
            )
          else
            Icon(
              _statusSuccess ? Icons.check_circle_outline : Icons.error_outline,
              color: _statusSuccess ? _green : _red,
              size: 16,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _statusMsg!,
              style: TextStyle(
                color: _statusSuccess ? _green : _red,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTxHashCard() {
    final hash = _txHash!;
    final short = '${hash.substring(0, 12)}…${hash.substring(hash.length - 8)}';
    return GestureDetector(
      onTap: () => _openBscScan(hash),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _gold.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.receipt_long, color: _gold, size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'BSC Transaction',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    short,
                    style: const TextStyle(
                      color: _gold,
                      fontSize: 12,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.open_in_new, color: _blue, size: 11),
                  SizedBox(width: 4),
                  Text('BscScan', style: TextStyle(color: _blue, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Bridge History',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_history.length}',
                    style: const TextStyle(color: _blue, fontSize: 11),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _exportHistory,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.ios_share, color: _blue, size: 16),
                  ),
                ),
                GestureDetector(
                  onTap: _clearHistory,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.delete_outline,
                      color: Colors.white54,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: _loadHistory,
                  child: const Text(
                    'Refresh',
                    style: TextStyle(color: _blue, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._history.take(15).map(_buildHistoryTile),
      ],
    );
  }

  Widget _buildHistoryTile(Map<String, dynamic> h) {
    final ts = DateTime.tryParse(h['ts'] as String? ?? '')?.toLocal();
    final now = DateTime.now();
    String timeStr = '';
    if (ts != null) {
      final diff = now.difference(ts);
      if (diff.inMinutes < 1) {
        timeStr = 'Just now';
      } else if (diff.inHours < 1) {
        timeStr = '${diff.inMinutes}m ago';
      } else if (diff.inDays < 1) {
        timeStr = '${diff.inHours}h ago';
      } else {
        timeStr =
            '${ts.month}/${ts.day} ${ts.hour}:${ts.minute.toString().padLeft(2, '0')}';
      }
    }
    final status = h['status'] as String? ?? 'pending';
    final anetTxId = h['anetTxId'] as String? ?? '';
    final txHash = h['txHash'] as String? ?? '';
    final statusColor = status == 'completed'
        ? _green
        : status == 'failed'
        ? _red
        : _gold;
    final statusLabel = status == 'completed'
        ? '✓ credited'
        : status == 'failed'
        ? '✗ failed'
        : '⏳ pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(10),
      ),
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
                      '${h['amount']} ${h['token']} → ANET L1',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (timeStr.isNotEmpty)
                      Text(
                        timeStr,
                        style: const TextStyle(color: _muted, fontSize: 11),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (anetTxId.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.check_circle, color: _green, size: 11),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'ANET TxID: $anetTxId',
                    style: const TextStyle(color: _green, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (txHash.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${txHash.substring(0, 12)}…${txHash.substring(txHash.length - 8)}',
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _openBscScan(txHash),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.open_in_new, color: _blue, size: 10),
                        SizedBox(width: 3),
                        Text(
                          'BscScan',
                          style: TextStyle(color: _blue, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (status == 'failed') ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _retryFailed(h),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _red.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, color: _red, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'Retry',
                      style: TextStyle(
                        color: _red,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Re-opens the bridge tab with token + amount pre-filled from a failed
  /// history entry so the user can resubmit in one tap (after topping up
  /// BNB for gas, if that was the cause).
  void _retryFailed(Map<String, dynamic> h) {
    final token = h['token'] as String?;
    final amount = h['amount'] as String?;
    if (token == null || amount == null) return;
    setState(() {
      final idx = _pairs.indexWhere((p) => p['from'] == token);
      if (idx >= 0) _selectedPairIdx = idx;
      _amountCtrl.text = amount;
      _selectedTab = 1;
      _statusMsg = null;
      _txHash = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Retry prepared — $amount $token. Review and submit.'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildInfoFooter() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: _blue, size: 14),
              SizedBox(width: 6),
              Text(
                'How the Bridge Works',
                style: TextStyle(
                  color: _blue,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '1. Send BNB or tokens to the AnetSwap contract on BSC.\n'
            '2. The contract verifies your ANET L1 destination address.\n'
            '3. ANET tokens are credited to your L1 wallet within minutes.\n'
            '4. Bridge fee: 1% deducted by the smart contract.\n'
            '5. Gas fees (~0.0001–0.0003 BNB) are paid from your BSC wallet.',
            style: TextStyle(color: _muted, fontSize: 11.5, height: 1.6),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _copy(anetSwapContractAddr),
            child: Row(
              children: [
                const Icon(Icons.code, color: _muted, size: 12),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Contract: $anetSwapContractAddr',
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.copy, color: _muted, size: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final Color color;
  final String label;
  const _AvatarCircle({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF0A1224), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared token picker — used by both Swap and Send sheets. Replaces the
//  cramped DropdownButton with a searchable bottom sheet showing every BSC
//  token plus the user's current balance (when available).
// ─────────────────────────────────────────────────────────────────────────────

Future<String?> _showTokenPicker(
  BuildContext context, {
  required String selected,
  Iterable<String>? exclude,
  Map<String, BigInt>? balances,
}) {
  final all = bscTokens.keys
      .where((t) => exclude == null || !exclude.contains(t))
      .toList();
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: _surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final searchCtrl = TextEditingController();
      return StatefulBuilder(
        builder: (ctx, setSt) {
          final q = searchCtrl.text.trim().toLowerCase();
          final filtered = q.isEmpty
              ? all
              : all.where((t) => t.toLowerCase().contains(q)).toList();
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.7,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2540),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 14, 20, 8),
                    child: Row(
                      children: [
                        Text(
                          'Select token',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: searchCtrl,
                      autofocus: true,
                      onChanged: (_) => setSt(() {}),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search by symbol (BNB, USDT, ANET…)',
                        hintStyle: TextStyle(
                          color: _muted.withValues(alpha: 0.6),
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: _muted,
                          size: 18,
                        ),
                        filled: true,
                        fillColor: _card,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF1A2540),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _blue),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final sym = filtered[i];
                        final info = bscTokens[sym]!;
                        final dec = info['decimals'] as int;
                        final raw = balances?[sym] ?? BigInt.zero;
                        final balLabel = balances != null
                            ? formatUnits(raw, dec, displayDecimals: 4)
                            : '';
                        final isSel = sym == selected;
                        return InkWell(
                          onTap: () => Navigator.of(ctx).pop(sym),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? _blue.withValues(alpha: 0.08)
                                  : Colors.transparent,
                              border: Border(
                                bottom: BorderSide(
                                  color: const Color(
                                    0xFF1A2540,
                                  ).withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _card,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF1A2540),
                                    ),
                                  ),
                                  child: Text(
                                    sym.characters.first,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        sym,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (info['native'] == true)
                                        const Text(
                                          'Native BNB',
                                          style: TextStyle(
                                            color: _muted,
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (balLabel.isNotEmpty)
                                  Text(
                                    balLabel,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                if (isSel)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 8),
                                    child: Icon(
                                      Icons.check_circle,
                                      color: _blue,
                                      size: 18,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  PancakeSwap V2 swap sheet — shown from ANET DEX EVM Bridge page.
// ─────────────────────────────────────────────────────────────────────────────

class _BridgeSwapSheet extends StatefulWidget {
  const _BridgeSwapSheet({
    required this.evmAddress,
    required this.anetAddress,
    required this.privKeyBytes,
  });

  final String evmAddress;
  final String anetAddress;
  final Uint8List privKeyBytes;

  @override
  State<_BridgeSwapSheet> createState() => _BridgeSwapSheetState();
}

class _BridgeSwapSheetState extends State<_BridgeSwapSheet> {
  final _amtCtrl = TextEditingController();
  String _fromToken = 'BNB';
  String _toToken = 'USDT';
  bool _loading = false;
  bool _quoting = false;
  String? _message;
  bool _success = false;
  String? _lastTxHash;
  String _estimatedOut = '';
  Timer? _quoteTimer;

  /// User-selected slippage tolerance in basis points (50 = 0.5%, 100 = 1%,
  /// 300 = 3%, 500 = 5%). Used as `(10000 - bps) / 10000` to compute the
  /// minimum acceptable output for the swap. Persisted in SharedPreferences
  /// so the choice survives between sessions.
  int _slippageBps = 100;
  static const List<int> _slippageOptions = [50, 100, 300, 500];

  @override
  void initState() {
    super.initState();
    _loadSlippage();
    _loadLastPair();
  }

  Future<void> _loadSlippage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getInt(_bridgeSlippageKey);
      if (v != null && _slippageOptions.contains(v) && mounted) {
        setState(() => _slippageBps = v);
      }
    } catch (_) {}
  }

  Future<void> _setSlippage(int bps) async {
    setState(() => _slippageBps = bps);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_bridgeSlippageKey, bps);
    } catch (_) {}
  }

  /// Restore the last swap pair the user picked so the sheet opens to the
  /// same context next time. Falls back to BNB→USDT defaults.
  Future<void> _loadLastPair() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final from = prefs.getString(_bridgeSwapFromKey);
      final to = prefs.getString(_bridgeSwapToKey);
      if (!mounted) return;
      setState(() {
        if (from != null && bscTokens.containsKey(from)) _fromToken = from;
        if (to != null && bscTokens.containsKey(to) && to != _fromToken) {
          _toToken = to;
        }
      });
    } catch (_) {}
  }

  Future<void> _persistPair() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_bridgeSwapFromKey, _fromToken);
      await prefs.setString(_bridgeSwapToKey, _toToken);
    } catch (_) {}
  }

  // All 23 tokens from bscTokens
  List<String> get _tokens => bscTokens.keys.toList();

  @override
  void dispose() {
    _quoteTimer?.cancel();
    _amtCtrl.dispose();
    super.dispose();
  }

  void _onAmountChanged(String _) {
    _quoteTimer?.cancel();
    _quoteTimer = Timer(const Duration(milliseconds: 700), _fetchQuote);
  }

  List<EthereumAddress> _getPath(String from, String to) {
    EthereumAddress addr(String sym) => sym == 'BNB'
        ? EthereumAddress.fromHex(_swapWbnbAddr)
        : EthereumAddress.fromHex(bscTokens[sym]!['address'] as String);
    if (from == 'BNB' || to == 'BNB') return [addr(from), addr(to)];
    return [addr(from), EthereumAddress.fromHex(_swapWbnbAddr), addr(to)];
  }

  Future<void> _fetchQuote() async {
    final amtVal = double.tryParse(_amtCtrl.text.trim());
    if (amtVal == null || amtVal <= 0 || _fromToken == _toToken) {
      if (mounted) setState(() => _estimatedOut = '');
      return;
    }
    if (mounted) setState(() => _quoting = true);
    try {
      final client = await _pickSwapBscClient();
      try {
        final fromDec = bscTokens[_fromToken]!['decimals'] as int;
        final toDec = bscTokens[_toToken]!['decimals'] as int;
        final netAmt = parseUnits(
          (amtVal * 0.99).toStringAsFixed(fromDec),
          fromDec,
        );
        final router = DeployedContract(
          ContractAbi.fromJson(_swapRouterAbi, 'PancakeRouter'),
          EthereumAddress.fromHex(_swapRouterAddr),
        );
        final res = await client.call(
          contract: router,
          function: router.function('getAmountsOut'),
          params: [netAmt, _getPath(_fromToken, _toToken)],
        );
        final outRaw = (res[0] as List).last as BigInt;
        if (mounted) {
          setState(
            () =>
                _estimatedOut = formatUnits(outRaw, toDec, displayDecimals: 6),
          );
        }
      } finally {
        client.dispose();
      }
    } catch (_) {
      if (mounted) setState(() => _estimatedOut = 'unavailable');
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  Future<void> _executeSwap() async {
    final amtVal = double.tryParse(_amtCtrl.text.trim());
    if (amtVal == null || amtVal <= 0) {
      setState(() {
        _message = 'Enter a valid amount.';
        _success = false;
      });
      return;
    }
    if (_fromToken == _toToken) {
      setState(() {
        _message = 'From and To tokens must be different.';
        _success = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final creds = EthPrivateKey(widget.privKeyBytes);
      final fromInfo = bscTokens[_fromToken]!;
      final fromDec = fromInfo['decimals'] as int;
      final amtUnits = parseUnits(_amtCtrl.text.trim(), fromDec);
      final feeUnits =
          amtUnits * BigInt.from(_swapFeeBps) ~/ BigInt.from(10000);
      final netUnits = amtUnits - feeUnits;
      final feeAddr = EthereumAddress.fromHex(_swapFeeWallet);
      final client = await _pickSwapBscClient();
      String txHash = '';

      try {
        // Get amountOutMin with user-selected slippage tolerance.
        BigInt amountOutMin = BigInt.zero;
        try {
          final router0 = DeployedContract(
            ContractAbi.fromJson(_swapRouterAbi, 'PancakeRouter'),
            EthereumAddress.fromHex(_swapRouterAddr),
          );
          final qRes = await client.call(
            contract: router0,
            function: router0.function('getAmountsOut'),
            params: [netUnits, _getPath(_fromToken, _toToken)],
          );
          final outRaw = (qRes[0] as List).last as BigInt;
          final keep = BigInt.from(10000 - _slippageBps);
          amountOutMin = outRaw * keep ~/ BigInt.from(10000);
        } catch (_) {}

        final senderAddr = creds.address;
        var baseNonce = await client.getTransactionCount(
          senderAddr,
          atBlock: const BlockNum.pending(),
        );
        final gasPrice = await _swapLiveGasPrice(client);
        final router = DeployedContract(
          ContractAbi.fromJson(_swapRouterAbi, 'PancakeRouter'),
          EthereumAddress.fromHex(_swapRouterAddr),
        );
        final deadline = BigInt.from(
          (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 300,
        );
        final path = _getPath(_fromToken, _toToken);

        if (fromInfo['native'] == true) {
          // BNB → ERC20
          if (feeUnits > BigInt.zero) {
            try {
              await client.sendTransaction(
                creds,
                Transaction(
                  to: feeAddr,
                  value: EtherAmount.fromBigInt(EtherUnit.wei, feeUnits),
                  gasPrice: gasPrice,
                  maxGas: 21000,
                  nonce: baseNonce,
                ),
                chainId: bscChainId,
              );
              baseNonce += 1;
            } catch (_) {}
          }
          txHash = await client.sendTransaction(
            creds,
            Transaction.callContract(
              contract: router,
              function: router.function('swapExactETHForTokens'),
              parameters: [amountOutMin, path, senderAddr, deadline],
              value: EtherAmount.fromBigInt(EtherUnit.wei, netUnits),
              gasPrice: gasPrice,
              maxGas: 250000,
              nonce: baseNonce,
            ),
            chainId: bscChainId,
          );
        } else {
          // ERC20 → BNB or ERC20 → ERC20
          final tokenAddr = EthereumAddress.fromHex(
            fromInfo['address'] as String,
          );
          final erc20Approve = DeployedContract(
            ContractAbi.fromJson(_swapErc20ApproveAbi, 'ERC20'),
            tokenAddr,
          );
          final allowRes = await client.call(
            contract: erc20Approve,
            function: erc20Approve.function('allowance'),
            params: [senderAddr, EthereumAddress.fromHex(_swapRouterAddr)],
          );
          final allowance = allowRes[0] as BigInt;
          if (allowance < amtUnits) {
            final maxApprove = BigInt.parse(
              'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
              radix: 16,
            );
            await client.sendTransaction(
              creds,
              Transaction.callContract(
                contract: erc20Approve,
                function: erc20Approve.function('approve'),
                parameters: [
                  EthereumAddress.fromHex(_swapRouterAddr),
                  maxApprove,
                ],
                gasPrice: gasPrice,
                maxGas: 60000,
                nonce: baseNonce,
              ),
              chainId: bscChainId,
            );
            baseNonce += 1;
          }

          if (feeUnits > BigInt.zero) {
            try {
              final erc20Transfer = DeployedContract(
                ContractAbi.fromJson(_swapErc20TransferAbi, 'ERC20Transfer'),
                tokenAddr,
              );
              await client.sendTransaction(
                creds,
                Transaction.callContract(
                  contract: erc20Transfer,
                  function: erc20Transfer.function('transfer'),
                  parameters: [feeAddr, feeUnits],
                  gasPrice: gasPrice,
                  maxGas: 65000,
                  nonce: baseNonce,
                ),
                chainId: bscChainId,
              );
              baseNonce += 1;
            } catch (_) {}
          }

          if (_toToken == 'BNB') {
            txHash = await client.sendTransaction(
              creds,
              Transaction.callContract(
                contract: router,
                function: router.function('swapExactTokensForETH'),
                parameters: [
                  netUnits,
                  amountOutMin,
                  path,
                  senderAddr,
                  deadline,
                ],
                gasPrice: gasPrice,
                maxGas: 250000,
                nonce: baseNonce,
              ),
              chainId: bscChainId,
            );
          } else {
            txHash = await client.sendTransaction(
              creds,
              Transaction.callContract(
                contract: router,
                function: router.function('swapExactTokensForTokens'),
                parameters: [
                  netUnits,
                  amountOutMin,
                  path,
                  senderAddr,
                  deadline,
                ],
                gasPrice: gasPrice,
                maxGas: 300000,
                nonce: baseNonce,
              ),
              chainId: bscChainId,
            );
          }
        }
      } finally {
        client.dispose();
      }

      if (mounted) {
        setState(() {
          _loading = false;
          _success = true;
          _lastTxHash = txHash;
          _message =
              '✅ Swap submitted! TX: ${txHash.length >= 10 ? txHash.substring(0, 10) : txHash}…';
        });
      }
      if (txHash.isNotEmpty) {
        unawaited(
          _reportSwapActivity(
            txHash: txHash,
            tokenSymbol: '$_fromToken→$_toToken',
            amount: _amtCtrl.text.trim(),
            evmAddress: widget.evmAddress,
            anetAddress: widget.anetAddress,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _success = false;
          _message = 'Error: ${e.toString().replaceFirst('Exception: ', '')}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final toTokens = _tokens.where((t) => t != _fromToken).toList();
    final safeToToken = toTokens.contains(_toToken) ? _toToken : toTokens.first;
    if (_toToken != safeToToken) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => setState(() => _toToken = safeToToken),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2540),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9B59FF).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF9B59FF).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.swap_horiz_rounded,
                    color: Color(0xFF9B59FF),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Swap',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _muted.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '1% fee',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // FROM row
            Row(
              children: [
                const Text(
                  'From',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _TokenPickButton(
                  token: _fromToken,
                  onTap: () async {
                    final pick = await _showTokenPicker(
                      context,
                      selected: _fromToken,
                    );
                    if (pick == null) return;
                    setState(() {
                      _fromToken = pick;
                      if (_toToken == pick) {
                        _toToken = _tokens.firstWhere((t) => t != pick);
                      }
                      _estimatedOut = '';
                    });
                    unawaited(_persistPair());
                    _fetchQuote();
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _amtCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    onChanged: _onAmountChanged,
                    decoration: InputDecoration(
                      hintText: '0.0',
                      hintStyle: TextStyle(
                        color: _muted.withValues(alpha: 0.5),
                      ),
                      filled: true,
                      fillColor: _card,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF1A2540)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF9B59FF)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Swap direction button
            Center(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    final tmp = _fromToken;
                    _fromToken = _toToken;
                    _toToken = tmp;
                    _estimatedOut = '';
                  });
                  unawaited(_persistPair());
                  _fetchQuote();
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9B59FF).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF9B59FF).withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Icon(
                    Icons.swap_vert,
                    color: Color(0xFF9B59FF),
                    size: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // TO row
            Row(
              children: [
                const Text(
                  'To',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (_quoting)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: _muted,
                    ),
                  ),
                if (_estimatedOut.isNotEmpty && !_quoting)
                  Text(
                    '≈ $_estimatedOut $_toToken',
                    style: const TextStyle(
                      color: _green,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: _TokenPickButton(
                token: safeToToken,
                fullWidth: true,
                onTap: () async {
                  final pick = await _showTokenPicker(
                    context,
                    selected: safeToToken,
                    exclude: [_fromToken],
                  );
                  if (pick == null) return;
                  setState(() {
                    _toToken = pick;
                    _estimatedOut = '';
                  });
                  unawaited(_persistPair());
                  _fetchQuote();
                },
              ),
            ),
            const SizedBox(height: 16),
            // Slippage tolerance row
            Row(
              children: [
                const Text(
                  'Slippage',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                ..._slippageOptions.map((bps) {
                  final sel = _slippageBps == bps;
                  final label = bps < 100
                      ? '${(bps / 100).toStringAsFixed(1)}%'
                      : '${bps ~/ 100}%';
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => _setSlippage(bps),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: sel
                              ? const Color(0xFF9B59FF).withValues(alpha: 0.18)
                              : _card,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: sel
                                ? const Color(0xFF9B59FF)
                                : const Color(0xFF1A2540),
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: sel
                                ? const Color(0xFF9B59FF)
                                : Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 8),
            // Min received estimate
            if (_estimatedOut.isNotEmpty && _estimatedOut != 'unavailable')
              Builder(
                builder: (_) {
                  final outVal = double.tryParse(_estimatedOut) ?? 0;
                  final minOut = outVal * (10000 - _slippageBps) / 10000;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF1A2540)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          color: _muted,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Min received',
                          style: TextStyle(color: _muted, fontSize: 11),
                        ),
                        const Spacer(),
                        Text(
                          '${minOut.toStringAsFixed(6)} $_toToken',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 12),
            // Message
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _message!,
                  style: TextStyle(
                    color: _success ? _green : _red,
                    fontSize: 13,
                  ),
                ),
              ),
            // Swap button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _executeSwap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9B59FF),
                  disabledBackgroundColor: const Color(
                    0xFF9B59FF,
                  ).withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Swap',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
            if (_success && _lastTxHash != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse(
                      'https://bscscan.com/tx/$_lastTxHash',
                    );
                    try {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (_) {}
                  },
                  child: const Center(
                    child: Text(
                      'View on BscScan ↗',
                      style: TextStyle(
                        color: _blue,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Send sheet — transfer BNB or any ERC-20 to an external BSC address.
// ─────────────────────────────────────────────────────────────────────────────

class _BridgeSendSheet extends StatefulWidget {
  const _BridgeSendSheet({
    required this.evmAddress,
    required this.anetAddress,
    required this.privKeyBytes,
    required this.rawBalances,
  });

  final String evmAddress;
  final String anetAddress;
  final Uint8List privKeyBytes;
  final Map<String, BigInt> rawBalances;

  @override
  State<_BridgeSendSheet> createState() => _BridgeSendSheetState();
}

class _BridgeSendSheetState extends State<_BridgeSendSheet> {
  final _toCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  String _token = 'BNB';
  bool _loading = false;
  String? _message;
  bool _success = false;
  String? _lastTxHash;

  List<String> get _tokens => bscTokens.keys.toList();

  @override
  void dispose() {
    _toCtrl.dispose();
    _amtCtrl.dispose();
    super.dispose();
  }

  String _availableBalance() {
    final raw = widget.rawBalances[_token] ?? BigInt.zero;
    final info = bscTokens[_token];
    if (info == null) return '0';
    return formatUnits(raw, info['decimals'] as int, displayDecimals: 6);
  }

  void _setMax() {
    final raw = widget.rawBalances[_token] ?? BigInt.zero;
    final info = bscTokens[_token];
    if (info == null) return;
    final dec = info['decimals'] as int;
    // For BNB leave a tiny gas reserve (0.001 BNB) so the tx itself can fly.
    BigInt usable = raw;
    if (info['native'] == true) {
      final reserve = BigInt.from(10).pow(15); // 0.001 BNB
      usable = raw > reserve ? raw - reserve : BigInt.zero;
    }
    _amtCtrl.text = formatUnits(usable, dec, displayDecimals: dec);
    setState(() {});
  }

  Future<void> _executeSend() async {
    final toRaw = _toCtrl.text.trim();
    final amtVal = double.tryParse(_amtCtrl.text.trim());
    if (toRaw.isEmpty || !RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(toRaw)) {
      setState(() {
        _message = 'Enter a valid 0x… BSC address.';
        _success = false;
      });
      return;
    }
    if (amtVal == null || amtVal <= 0) {
      setState(() {
        _message = 'Enter a valid amount.';
        _success = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final creds = EthPrivateKey(widget.privKeyBytes);
      final info = bscTokens[_token]!;
      final dec = info['decimals'] as int;
      final amtUnits = parseUnits(_amtCtrl.text.trim(), dec);
      final toAddr = EthereumAddress.fromHex(toRaw);
      final client = await _pickSwapBscClient();
      String txHash = '';
      try {
        final gasPrice = await _swapLiveGasPrice(client);
        final senderAddr = creds.address;
        final nonce = await client.getTransactionCount(
          senderAddr,
          atBlock: const BlockNum.pending(),
        );
        if (info['native'] == true) {
          // Native BNB transfer
          txHash = await client.sendTransaction(
            creds,
            Transaction(
              to: toAddr,
              value: EtherAmount.fromBigInt(EtherUnit.wei, amtUnits),
              gasPrice: gasPrice,
              maxGas: 21000,
              nonce: nonce,
            ),
            chainId: bscChainId,
          );
        } else {
          // ERC-20 transfer
          final tokenAddr = EthereumAddress.fromHex(info['address'] as String);
          final erc20 = DeployedContract(
            ContractAbi.fromJson(_swapErc20TransferAbi, 'ERC20Transfer'),
            tokenAddr,
          );
          txHash = await client.sendTransaction(
            creds,
            Transaction.callContract(
              contract: erc20,
              function: erc20.function('transfer'),
              parameters: [toAddr, amtUnits],
              gasPrice: gasPrice,
              maxGas: 70000,
              nonce: nonce,
            ),
            chainId: bscChainId,
          );
        }
      } finally {
        client.dispose();
      }

      if (mounted) {
        setState(() {
          _loading = false;
          _success = true;
          _lastTxHash = txHash;
          _message =
              '✅ Sent! TX: ${txHash.length >= 10 ? txHash.substring(0, 10) : txHash}…';
        });
      }
      if (txHash.isNotEmpty) {
        unawaited(
          _reportSwapActivity(
            txHash: txHash,
            tokenSymbol: '$_token (send)',
            amount: _amtCtrl.text.trim(),
            evmAddress: widget.evmAddress,
            anetAddress: widget.anetAddress,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _success = false;
          _message = 'Error: ${e.toString().replaceFirst('Exception: ', '')}';
        });
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      _toCtrl.text = data!.text!.trim();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2540),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _blue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: _blue.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(
                    Icons.send_outlined,
                    color: _blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Send',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0B90B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'BSC',
                    style: TextStyle(
                      color: Color(0xFFF0B90B),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Token selector
            const Text(
              'Token',
              style: TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: _TokenPickButton(
                token: _token,
                fullWidth: true,
                balanceLabel: _availableBalance(),
                onTap: () async {
                  final pick = await _showTokenPicker(
                    context,
                    selected: _token,
                    balances: widget.rawBalances,
                  );
                  if (pick == null) return;
                  setState(() => _token = pick);
                },
              ),
            ),
            const SizedBox(height: 14),
            // Recipient row
            Row(
              children: [
                const Text(
                  'To address',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _pasteFromClipboard,
                  child: const Text(
                    'Paste',
                    style: TextStyle(
                      color: _blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _toCtrl,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: '0x…',
                hintStyle: TextStyle(color: _muted.withValues(alpha: 0.5)),
                filled: true,
                fillColor: _card,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF1A2540)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _blue),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Amount row
            Row(
              children: [
                const Text(
                  'Amount',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  'Available: ${_availableBalance()} $_token',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _setMax,
                  child: const Text(
                    'MAX',
                    style: TextStyle(
                      color: _blue,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _amtCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: '0.0',
                hintStyle: TextStyle(color: _muted.withValues(alpha: 0.5)),
                filled: true,
                fillColor: _card,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF1A2540)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _blue),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _message!,
                  style: TextStyle(
                    color: _success ? _green : _red,
                    fontSize: 13,
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _executeSend,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  disabledBackgroundColor: _blue.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Send',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
            if (_success && _lastTxHash != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse(
                      'https://bscscan.com/tx/$_lastTxHash',
                    );
                    try {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (_) {}
                  },
                  child: const Center(
                    child: Text(
                      'View on BscScan ↗',
                      style: TextStyle(
                        color: _blue,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pill-style button that opens the [_showTokenPicker] modal. Replaces the
/// cramped DropdownButton inside Swap and Send sheets so users can search
/// instead of scrolling through 23 entries.
class _TokenPickButton extends StatelessWidget {
  const _TokenPickButton({
    required this.token,
    required this.onTap,
    this.fullWidth = false,
    this.balanceLabel,
  });

  final String token;
  final VoidCallback onTap;
  final bool fullWidth;
  final String? balanceLabel;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1A2540)),
      ),
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _surface,
              shape: BoxShape.circle,
            ),
            child: Text(
              token.characters.first,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            token,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (fullWidth) const Spacer() else const SizedBox(width: 6),
          if (balanceLabel != null && balanceLabel!.isNotEmpty) ...[
            Text(
              balanceLabel!,
              style: const TextStyle(
                color: _muted,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 6),
          ],
          const Icon(Icons.expand_more, color: _muted, size: 18),
        ],
      ),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: pill,
    );
  }
}
