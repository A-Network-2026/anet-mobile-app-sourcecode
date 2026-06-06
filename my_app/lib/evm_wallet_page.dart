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
import 'evm_bridge_page.dart';
import 'evm_wallet_service.dart';
import 'nft_identity_screen.dart';
import 'public_nft_profile_page.dart';
import 'username_registry_service.dart';

// ─── Colours (same palette as evm_bridge_page) ────────────────────────────────
const _bg = Color(0xFF07111F);
const _surface = Color(0xFF0A1224);
const _card = Color(0xFF0F1C2E);
const _blue = Color(0xFF1677FF);
const _green = Color(0xFF25C474);
const _red = Color(0xFFFF4D4F);
const _muted = Color(0xFF7B829A);
const _border = Color(0xFF1A2540);
const _gold = Color(0xFFFFB800);

const String _erc20TransferAbi = r'''[
  {"name":"transfer","type":"function","stateMutability":"nonpayable",
   "inputs":[{"name":"recipient","type":"address"},{"name":"amount","type":"uint256"}],
   "outputs":[{"name":"","type":"bool"}]}
]''';

const String _erc20ApproveAbi = r'''[
  {"name":"allowance","type":"function","stateMutability":"view",
   "inputs":[{"name":"owner","type":"address"},{"name":"spender","type":"address"}],
   "outputs":[{"name":"","type":"uint256"}]},
  {"name":"approve","type":"function","stateMutability":"nonpayable",
   "inputs":[{"name":"spender","type":"address"},{"name":"amount","type":"uint256"}],
   "outputs":[{"name":"","type":"bool"}]}
]''';

// PancakeSwap V2 Router (BSC mainnet) ─ used for EVM token swaps
const String _pancakeRouterAddr = '0x10ED43C718714eb63d5aA57B78B54704E256024E';
const String _wbnbAddr = '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c';

const String _pancakeRouterAbi = r'''[
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

// ─── Platform fee (matches AnetSwap contract feeBps = 100) ──────────────────
const String _anetFeeWallet = '0x9C7C1058fdc9b710f688ECb7562924D9AE771417';
const int _platformFeeBps = 100; // 1 %  (100 / 10 000)

// ─── ANET L1 activity reporting ──────────────────────────────────────────────
const String _piBackendBase = String.fromEnvironment(
  'PI_BACKEND_URL',
  defaultValue: 'https://pi-backend-q2ye.onrender.com',
);

/// Ordered list of BSC RPC endpoints. The first reachable one is used.
const List<String> _bscRpcUrls = [
  'https://bsc-dataseed1.binance.org/',
  'https://bsc-dataseed2.binance.org/',
  'https://bsc-dataseed3.binance.org/',
  'https://bsc-dataseed4.binance.org/',
];

/// Returns the first [Web3Client] that responds to a block number probe,
/// cycling through [_bscRpcUrls]. The caller must call `client.dispose()`.
Future<Web3Client> _pickWorkingBscClient() async {
  Exception? lastError;
  for (final url in _bscRpcUrls) {
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

/// Fetches the current BSC gas price and returns it with a 10% buffer.
/// Floor is 1 gwei to ensure TX acceptance without overpaying.
Future<EtherAmount> _liveGasPrice(Web3Client client) async {
  try {
    final raw = (await client.getGasPrice()).getInWei;
    final buffered = raw * BigInt.from(11) ~/ BigInt.from(10); // +10%
    final floor = BigInt.from(1000000000); // 1 gwei (BSC hard minimum)
    return EtherAmount.fromBigInt(
      EtherUnit.wei,
      buffered > floor ? buffered : floor,
    );
  } catch (_) {
    return EtherAmount.fromBigInt(EtherUnit.wei, BigInt.from(1000000000));
  }
}

/// Fire-and-forget: report EVM wallet activity to the pi-backend so it can
/// create a block event on the ANET L1 chain. Errors are silently swallowed.
Future<void> _reportEvmActivity({
  required String txHash,
  required String activityType, // 'send' | 'swap' | 'receive'
  required String tokenSymbol,
  required String amount,
  required String evmAddress,
  required String anetAddress,
}) async {
  try {
    await http
        .post(
          Uri.parse('$_piBackendBase/api/evm/activity'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'txHash': txHash,
            'activityType': activityType,
            'tokenSymbol': tokenSymbol,
            'amount': amount,
            'evmAddress': evmAddress,
            'anetAddress': anetAddress,
            'chainId': 56,
          }),
        )
        .timeout(const Duration(seconds: 10));
  } catch (_) {
    // Best-effort — do not surface errors to the user
  }
}

// ─── "Coming soon" chain list ─────────────────────────────────────────────────
const _comingSoonChains = [
  {'name': 'Ethereum', 'icon': '🔷'},
  {'name': 'Polygon', 'icon': '🟣'},
  {'name': 'Arbitrum', 'icon': '🔵'},
  {'name': 'Avalanche', 'icon': '🔺'},
  {'name': 'Solana', 'icon': '🟢'},
  {'name': 'Bitcoin', 'icon': '🟡'},
];

// ─── Token definitions shown in the Tokens tab ────────────────────────────────
const _displayTokens = [
  {'symbol': 'BNB', 'name': 'BNB', 'icon': '🟡'},
  {'symbol': 'ANET', 'name': 'ANET (BEP-20)', 'icon': '🅰'},
  {'symbol': 'USDT', 'name': 'Tether USD', 'icon': '💵'},
  {'symbol': 'USDC', 'name': 'USD Coin', 'icon': '🔵'},
  {'symbol': 'BUSD', 'name': 'Binance USD', 'icon': '🟨'},
  {'symbol': 'DAI', 'name': 'Dai Stablecoin', 'icon': '🟠'},
  {'symbol': 'TUSD', 'name': 'TrueUSD', 'icon': '🔷'},
  {'symbol': 'ETH', 'name': 'Ethereum (BSC)', 'icon': '◆'},
  {'symbol': 'BTCB', 'name': 'Bitcoin BEP-20', 'icon': '₿'},
  {'symbol': 'CAKE', 'name': 'PancakeSwap', 'icon': '🥞'},
  {'symbol': 'DOGE', 'name': 'Dogecoin (BSC)', 'icon': '🐕'},
  {'symbol': 'SHIB', 'name': 'Shiba Inu', 'icon': '🐶'},
  {'symbol': 'MATIC', 'name': 'Polygon', 'icon': '🟣'},
  {'symbol': 'ADA', 'name': 'Cardano', 'icon': '🔷'},
  {'symbol': 'XRP', 'name': 'XRP', 'icon': '✕'},
  {'symbol': 'LTC', 'name': 'Litecoin', 'icon': 'Ł'},
  {'symbol': 'LINK', 'name': 'Chainlink', 'icon': '🔗'},
  {'symbol': 'DOT', 'name': 'Polkadot', 'icon': '🔴'},
  {'symbol': 'AVAX', 'name': 'Avalanche', 'icon': '🔺'},
  {'symbol': 'SOL', 'name': 'Solana', 'icon': '🟢'},
  {'symbol': 'UNI', 'name': 'Uniswap', 'icon': '🦄'},
  {'symbol': 'TRX', 'name': 'TRON', 'icon': '🔻'},
  {'symbol': 'TWT', 'name': 'Trust Wallet', 'icon': '🛡'},
];

// ─── Storage key for user-imported custom tokens ─────────────────────────────
String _customTokensKey(String evmAddress) =>
    'evm_custom_tokens.${evmAddress.toLowerCase()}';

/// MetaMask-style EVM wallet hub — BNB Chain primary.
///
/// Shows:
///  - Token balances with live USD prices and 24h % changes
///  - Native ANET L1 NFT identity card
///  - Bridge activity history
///  - Quick actions: Swap/Bridge, Send, Receive
///  - Network selector (BNB Chain live; others "Coming Soon")
class EvmWalletPage extends StatefulWidget {
  const EvmWalletPage({
    super.key,
    required this.anetAddress,
    required this.evmAddress,
    required this.privKeyBytes,
    this.completedSessions = 0,
    this.sessionGateBypassEnabled = false,
  });

  final String anetAddress;
  final String evmAddress;
  final Uint8List privKeyBytes;
  final int completedSessions;
  final bool sessionGateBypassEnabled;

  @override
  State<EvmWalletPage> createState() => _EvmWalletPageState();
}

class _EvmWalletPageState extends State<EvmWalletPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _service = EvmWalletService();

  // Balances
  Map<String, BigInt> _rawBalances = {};
  // Custom (user-imported) ERC-20 balances, keyed by lowercase contract address
  Map<String, BigInt> _customRawBalances = {};
  bool _balancesLoading = false;

  // Prices
  Map<String, double> _prices = {
    'BNB': 0,
    'USDT': 1,
    'USDC': 1,
    'BUSD': 1,
    'ETH': 0,
    'BTCB': 0,
    'CAKE': 0,
    'ANET': 0,
  };
  Map<String, double> _changes = {
    'BNB': 0,
    'USDT': 0,
    'USDC': 0,
    'BUSD': 0,
    'ETH': 0,
    'BTCB': 0,
    'CAKE': 0,
    'ANET': 0,
  };
  bool _pricesLoading = false;

  // User-imported custom tokens
  // Each entry: {address, name, symbol, decimals, icon}
  List<Map<String, dynamic>> _customTokens = [];

  // NFT
  Map<String, dynamic>? _nftStatus;
  bool _nftLoading = false;

  // Activity (bridge history)
  List<Map<String, dynamic>> _bridgeHistory = [];
  bool _activityLoading = false;

  // UI state
  bool _balanceVisible = true;
  bool _networkDropdownOpen = false;

  // On-chain primary username (BSC AnetUsernameRegistry).
  // null = not yet loaded or none registered for this wallet.
  String? _primaryUsername;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
    _loadCustomTokens();
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) setState(() {});
    });
    _loadAll();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadBalances();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _refreshTimer?.cancel();
    _service.dispose();
    super.dispose();
  }

  // ── Data loading ────────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    await Future.wait([
      _loadBalances(),
      _loadPrices(),
      _loadNftStatus(),
      _loadActivity(),
      _loadUsername(),
    ]);
  }

  Future<void> _loadUsername() async {
    if (!mounted) return;
    try {
      final name = await usernameRegistry.reverseResolve(widget.evmAddress);
      if (mounted) setState(() => _primaryUsername = name);
    } catch (_) {
      // silent — UI falls back to address-only display
    }
  }

  Future<void> _loadBalances() async {
    if (!mounted) return;
    setState(() => _balancesLoading = true);
    try {
      final addr = EthereumAddress.fromHex(widget.evmAddress);
      final bnb = await _service.getBnbBalance(addr);

      final futures = <String, Future<BigInt>>{};
      for (final t in bscTokens.entries) {
        if (t.value['native'] == true) continue;
        futures[t.key] = _service.getErc20Balance(
          addr,
          EthereumAddress.fromHex(t.value['address'] as String),
        );
      }
      final results = <String, BigInt>{'BNB': bnb};
      for (final e in futures.entries) {
        results[e.key] = await e.value;
      }

      // Custom (user-imported) tokens
      final customResults = <String, BigInt>{};
      for (final ct in _customTokens) {
        final addrStr = (ct['address'] as String).toLowerCase();
        try {
          customResults[addrStr] = await _service.getErc20Balance(
            addr,
            EthereumAddress.fromHex(addrStr),
          );
        } catch (_) {
          customResults[addrStr] = BigInt.zero;
        }
      }

      if (mounted) {
        setState(() {
          _rawBalances = results;
          _customRawBalances = customResults;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _balancesLoading = false);
    }
  }

  Future<void> _loadPrices() async {
    if (!mounted) return;
    setState(() => _pricesLoading = true);
    try {
      // CoinGecko IDs for our default token list
      const ids =
          'binancecoin,tether,usd-coin,binance-usd,dai,true-usd,'
          'ethereum,bitcoin,pancakeswap-token,'
          'dogecoin,shiba-inu,matic-network,cardano,ripple,litecoin,'
          'chainlink,polkadot,avalanche-2,solana,uniswap,tron,trust-wallet-token';
      final res = await http
          .get(
            Uri.parse(
              'https://api.coingecko.com/api/v3/simple/price'
              '?ids=$ids&vs_currencies=usd&include_24hr_change=true',
            ),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        double price(String id) => (data[id]?['usd'] as num?)?.toDouble() ?? 0;
        double change(String id) =>
            (data[id]?['usd_24h_change'] as num?)?.toDouble() ?? 0;
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
            _changes = {
              'BNB': change('binancecoin'),
              'USDT': change('tether'),
              'USDC': change('usd-coin'),
              'BUSD': change('binance-usd'),
              'DAI': change('dai'),
              'TUSD': change('true-usd'),
              'ETH': change('ethereum'),
              'BTCB': change('bitcoin'),
              'CAKE': change('pancakeswap-token'),
              'DOGE': change('dogecoin'),
              'SHIB': change('shiba-inu'),
              'MATIC': change('matic-network'),
              'ADA': change('cardano'),
              'XRP': change('ripple'),
              'LTC': change('litecoin'),
              'LINK': change('chainlink'),
              'DOT': change('polkadot'),
              'AVAX': change('avalanche-2'),
              'SOL': change('solana'),
              'UNI': change('uniswap'),
              'TRX': change('tron'),
              'TWT': change('trust-wallet-token'),
              'ANET': 0,
            };
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _pricesLoading = false);
    }
  }

  Future<void> _loadNftStatus() async {
    if (!mounted) return;
    setState(() => _nftLoading = true);
    try {
      final status = await getWalletNftStatusAPI();
      if (mounted) setState(() => _nftStatus = status);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _nftLoading = false);
    }
  }

  Future<void> _loadActivity() async {
    if (!mounted) return;
    setState(() => _activityLoading = true);
    try {
      final history = await bridgeEvmHistoryAPI(widget.evmAddress);
      if (mounted) setState(() => _bridgeHistory = history);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _activityLoading = false);
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _shortAddr(String addr) {
    if (addr.length < 12) return addr;
    return '${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}';
  }

  String _formatBalance(String symbol) {
    final raw = _rawBalances[symbol] ?? BigInt.zero;
    final info = bscTokens[symbol];
    if (info == null) return '0.0000';
    final decimals = info['decimals'] as int? ?? 18;
    return formatUnits(raw, decimals, displayDecimals: 4);
  }

  double _balanceAsDouble(String symbol) {
    return double.tryParse(_formatBalance(symbol)) ?? 0.0;
  }

  double _usdValue(String symbol) {
    return _balanceAsDouble(symbol) * (_prices[symbol] ?? 0);
  }

  double get _totalUsdValue {
    return _displayTokens.fold(0.0, (sum, t) {
      return sum + _usdValue(t['symbol'] as String);
    });
  }

  String _fmtUsd(double v) {
    if (v >= 1000) return '\$${v.toStringAsFixed(2)}';
    if (v >= 1) return '\$${v.toStringAsFixed(2)}';
    return '\$${v.toStringAsFixed(4)}';
  }

  Color _changeColor(double pct) => pct >= 0 ? _green : _red;

  String _changeText(double pct) {
    final sign = pct >= 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(2)}%';
  }

  // ── Custom (user-imported) ERC-20 tokens ─────────────────────────────────────

  Future<void> _loadCustomTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_customTokensKey(widget.evmAddress));
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() => _customTokens = list);
      // Refresh balances so the imported tokens show numeric values
      unawaited(_loadBalances());
    } catch (_) {
      // Ignore corrupt storage — user can re-import.
    }
  }

  Future<void> _saveCustomTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _customTokensKey(widget.evmAddress),
        jsonEncode(_customTokens),
      );
    } catch (_) {}
  }

  /// Looks up an ERC-20 contract on BSC by address, verifies it via
  /// `name()`/`symbol()`/`decimals()` and adds it to the local token list.
  Future<String?> _addCustomToken(String pastedAddress) async {
    final cleaned = pastedAddress.trim();
    if (cleaned.isEmpty) return 'Address is required';
    EthereumAddress addr;
    try {
      addr = EthereumAddress.fromHex(cleaned);
    } catch (_) {
      return 'Invalid contract address';
    }

    // Reject duplicates of built-in tokens or already-imported tokens.
    final lower = addr.hexEip55.toLowerCase();
    for (final t in bscTokens.entries) {
      final builtIn = (t.value['address'] as String?)?.toLowerCase() ?? '';
      if (builtIn == lower) {
        return '${t.key} is already in your token list';
      }
    }
    for (final ct in _customTokens) {
      if ((ct['address'] as String).toLowerCase() == lower) {
        return 'Token is already imported';
      }
    }

    final meta = await _service.fetchErc20Metadata(addr);
    if (meta == null) {
      return 'Could not read token metadata. Is this a BSC ERC-20 contract?';
    }

    final entry = <String, dynamic>{
      'address': addr.hexEip55,
      'name': meta.name,
      'symbol': meta.symbol,
      'decimals': meta.decimals,
      'icon': '🪙',
    };
    if (!mounted) return null;
    setState(() => _customTokens = [..._customTokens, entry]);
    await _saveCustomTokens();
    unawaited(_loadBalances());
    return null;
  }

  Future<void> _removeCustomToken(String addressLower) async {
    setState(() {
      _customTokens = _customTokens
          .where((t) => (t['address'] as String).toLowerCase() != addressLower)
          .toList();
      _customRawBalances.remove(addressLower);
    });
    await _saveCustomTokens();
  }

  // ── Actions ──────────────────────────────────────────────────────────────────

  void _openBridge() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EvmBridgePage(
          anetAddress: widget.anetAddress,
          evmAddress: widget.evmAddress,
          privKeyBytes: widget.privKeyBytes,
        ),
      ),
    ).then((_) => _loadAll());
  }

  void _openReceive() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ReceiveSheet(evmAddress: widget.evmAddress),
    );
  }

  void _openSend() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => _SendSheet(
        evmAddress: widget.evmAddress,
        anetAddress: widget.anetAddress,
        privKeyBytes: widget.privKeyBytes,
        rawBalances: _rawBalances,
        service: _service,
      ),
    ).then((_) => _loadBalances());
  }

  void _openBuy() {
    showModalBottomSheet<String>(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => _BuySheet(evmAddress: widget.evmAddress),
    ).then((action) {
      if (action == 'bridge' && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EvmBridgePage(
              anetAddress: widget.anetAddress,
              evmAddress: widget.evmAddress,
              privKeyBytes: widget.privKeyBytes,
            ),
          ),
        ).then((_) => _loadAll());
      } else if (action == 'swap' && mounted) {
        _openSwap();
      }
    });
  }

  void _openSwap() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => _SwapSheet(
        evmAddress: widget.evmAddress,
        anetAddress: widget.anetAddress,
        privKeyBytes: widget.privKeyBytes,
        rawBalances: _rawBalances,
      ),
    ).then((_) => _loadBalances());
  }

  void _openPublicNftProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicNftProfilePage(walletAddress: widget.anetAddress),
      ),
    );
  }

  void _openNftIdentityEditor() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NftIdentityScreen(
          walletAddress: widget.anetAddress,
          completedSessions: widget.completedSessions,
          sessionGateBypassEnabled: widget.sessionGateBypassEnabled,
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'EVM Wallet',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _muted, size: 20),
            onPressed: _loadAll,
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          if (_networkDropdownOpen) {
            setState(() => _networkDropdownOpen = false);
          }
        },
        child: Column(
          children: [
            _buildWalletHeader(),
            _buildTabBar(),
            Expanded(child: _buildTabContent()),
          ],
        ),
      ),
    );
  }

  // ── Wallet header ────────────────────────────────────────────────────────────

  void _openClaimUsername() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => _ClaimUsernameSheet(
        evmAddress: widget.evmAddress,
        privKeyBytes: widget.privKeyBytes,
      ),
    ).then((claimed) {
      if (claimed is String && claimed.isNotEmpty) {
        usernameRegistry.invalidateCache(widget.evmAddress);
        _loadUsername();
      }
    });
  }

  Widget _buildUsernameBadge() {
    final hasName = (_primaryUsername ?? '').isNotEmpty;
    return GestureDetector(
      onTap: _openClaimUsername,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: hasName ? _green.withOpacity(0.12) : _blue.withOpacity(0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasName ? _green.withOpacity(0.45) : _blue.withOpacity(0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasName
                  ? Icons.verified_rounded
                  : Icons.add_circle_outline_rounded,
              color: hasName ? _green : _blue,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              hasName ? '@$_primaryUsername' : 'Claim your @username',
              style: TextStyle(
                color: hasName ? _green : _blue,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (hasName) ...[
              const SizedBox(width: 4),
              const Icon(Icons.expand_more_rounded, color: _muted, size: 14),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWalletHeader() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Network badge
          _buildNetworkBadge(),
          const SizedBox(height: 10),
          // Username badge (on-chain identity passport)
          _buildUsernameBadge(),
          const SizedBox(height: 10),
          // Address
          GestureDetector(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: widget.evmAddress));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('EVM address copied'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1677FF), Color(0xFF25C474)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _shortAddr(widget.evmAddress),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.copy_rounded, color: _muted, size: 14),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Total balance
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _balanceVisible
                    ? Text(
                        _fmtUsd(_totalUsdValue),
                        key: const ValueKey('visible'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      )
                    : const Text(
                        '••••••',
                        key: ValueKey('hidden'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _balanceVisible = !_balanceVisible),
                child: Icon(
                  _balanceVisible
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: _muted,
                  size: 18,
                ),
              ),
            ],
          ),
          if (_balancesLoading || _pricesLoading)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: SizedBox(
                height: 2,
                width: 60,
                child: LinearProgressIndicator(
                  color: _blue,
                  backgroundColor: _border,
                ),
              ),
            ),
          const SizedBox(height: 16),
          // Action row: Buy | Send | Receive | Swap
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _actionBtn(
                'Buy',
                Icons.add_shopping_cart_rounded,
                _green,
                _openBuy,
              ),
              _actionBtn('Send', Icons.north_east_rounded, _gold, _openSend),
              _actionBtn(
                'Receive',
                Icons.south_west_rounded,
                _blue,
                _openReceive,
              ),
              _actionBtn(
                'Swap',
                Icons.swap_horiz_rounded,
                const Color(0xFF9B59FF),
                _openSwap,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkBadge() {
    return Column(
      children: [
        GestureDetector(
          onTap: () =>
              setState(() => _networkDropdownOpen = !_networkDropdownOpen),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: _green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  '🟡 BNB Chain',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _networkDropdownOpen
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: _muted,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
        if (_networkDropdownOpen)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Column(
              children: [
                // Active: BNB Chain
                ListTile(
                  dense: true,
                  leading: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: _green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: const Text(
                    '🟡 BNB Chain',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(
                        color: _green,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const Divider(color: _border, height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.access_time_rounded, color: _muted, size: 12),
                      SizedBox(width: 6),
                      Text(
                        'More chains coming soon',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                ..._comingSoonChains.map(
                  (c) => ListTile(
                    dense: true,
                    leading: Text(
                      c['icon']!,
                      style: const TextStyle(fontSize: 16),
                    ),
                    title: Text(
                      c['name']!,
                      style: const TextStyle(color: _muted, fontSize: 13),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _muted.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Soon',
                        style: TextStyle(color: _muted, fontSize: 10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _actionBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: _muted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab bar ──────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      color: _surface,
      child: TabBar(
        controller: _tabCtrl,
        isScrollable: true,
        tabAlignment: TabAlignment.center,
        indicatorColor: _blue,
        indicatorWeight: 2,
        labelColor: Colors.white,
        unselectedLabelColor: _muted,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        tabs: const [
          Tab(text: 'Tokens'),
          Tab(text: 'NFTs'),
          Tab(text: 'Activity'),
          Tab(text: 'DeFi'),
          Tab(text: 'Card'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabCtrl,
      children: [
        _buildTokensTab(),
        _buildNftsTab(),
        _buildActivityTab(),
        _buildDeFiTab(),
        _buildCardTab(),
      ],
    );
  }

  // ── Tokens tab ───────────────────────────────────────────────────────────────

  Widget _buildTokensTab() {
    return RefreshIndicator(
      color: _blue,
      backgroundColor: _card,
      onRefresh: () => Future.wait([_loadBalances(), _loadPrices()]),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ..._displayTokens.map(_buildTokenRow),
          ..._customTokens.map(_buildCustomTokenRow),
          const SizedBox(height: 12),
          _buildAddTokenButton(),
          const SizedBox(height: 16),
          // "All networks" notice
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: _muted, size: 13),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Showing BNB Chain (BSC) balances. More chains coming soon.',
                    style: TextStyle(color: _muted, fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddTokenButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: _showAddTokenSheet,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: const [
              Icon(Icons.add_rounded, color: _blue, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Add custom token',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: _muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomTokenRow(Map<String, dynamic> ct) {
    final address = (ct['address'] as String);
    final symbol = (ct['symbol'] as String?) ?? '?';
    final name = (ct['name'] as String?) ?? '';
    final decimals = (ct['decimals'] as int?) ?? 18;
    final icon = (ct['icon'] as String?) ?? '🪙';
    final raw = _customRawBalances[address.toLowerCase()] ?? BigInt.zero;
    final bal = formatUnits(raw, decimals, displayDecimals: 6);

    return InkWell(
      onLongPress: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: _card,
            title: const Text(
              'Remove token?',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'Remove $symbol from your wallet? You can add it back any time.',
              style: const TextStyle(color: _muted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remove', style: TextStyle(color: _red)),
              ),
            ],
          ),
        );
        if (ok == true) {
          await _removeCustomToken(address.toLowerCase());
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: _border, width: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _card,
                shape: BoxShape.circle,
                border: Border.all(color: _border),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    symbol,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            _balanceVisible
                ? Text(
                    '$bal $symbol',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  )
                : const Text(
                    '••••',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  void _showAddTokenSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddTokenSheet(onSubmit: _addCustomToken),
    );
  }

  // ── DeFi tab ─────────────────────────────────────────────────────────────────

  Widget _buildDeFiTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _deFiCard(
          icon: Icons.swap_vert_rounded,
          color: _blue,
          title: 'Bridge to ANET L1',
          subtitle:
              'Move USDT, USDC, BNB, ETH and more from BSC into your '
              'ANET L1 wallet via the AnetSwap AMM.',
          onTap: _openBridge,
        ),
        const SizedBox(height: 12),
        _deFiCard(
          icon: Icons.swap_horiz_rounded,
          color: const Color(0xFF9B59FF),
          title: 'Swap on PancakeSwap',
          subtitle:
              'Native in-app swap routed through PancakeSwap V2. Trade any '
              'BEP-20 token directly from your EVM wallet.',
          onTap: _openSwap,
        ),
        const SizedBox(height: 12),
        _deFiCard(
          icon: Icons.account_tree_rounded,
          color: _green,
          title: 'ANET L1 DEX',
          subtitle:
              'Trade ANET / USDC on the native ANET L1 AMM. Open the DEX '
              'from the main app menu to swap with your L1 balance.',
          onTap: () {
            Navigator.pop(context);
          },
        ),
        const SizedBox(height: 12),
        _deFiCard(
          icon: Icons.open_in_new_rounded,
          color: _gold,
          title: 'PancakeSwap (Web)',
          subtitle:
              'Open the full PancakeSwap interface in your browser for '
              'advanced trading, liquidity, and farming.',
          onTap: () async {
            final uri = Uri.parse('https://pancakeswap.finance/swap');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        ),
      ],
    );
  }

  Widget _deFiCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _muted, size: 20),
          ],
        ),
      ),
    );
  }

  // ── Card tab ─────────────────────────────────────────────────────────────────

  Widget _buildCardTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Color(0xFF1677FF), Color(0xFF9B59FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.credit_card_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'A Network Card',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Spend your ANET, USDT, USDC and BNB anywhere — '
                'powered by a debit card linked directly to your EVM wallet.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Coming Soon',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'What to expect',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 10),
              _CardFeatureRow(
                icon: Icons.shopping_bag_rounded,
                text:
                    'Spend crypto in any store that accepts Visa / Mastercard',
              ),
              SizedBox(height: 8),
              _CardFeatureRow(
                icon: Icons.bolt_rounded,
                text: 'Auto-converts ANET / USDT / USDC at the point of sale',
              ),
              SizedBox(height: 8),
              _CardFeatureRow(
                icon: Icons.lock_rounded,
                text: 'Non-custodial — your wallet stays on your phone',
              ),
              SizedBox(height: 8),
              _CardFeatureRow(
                icon: Icons.public_rounded,
                text: 'Global rollout starting Q3 2026',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTokenRow(Map<String, String> token) {
    final symbol = token['symbol']!;
    final name = token['name']!;
    final icon = token['icon']!;
    final bal = _formatBalance(symbol);
    final usd = _usdValue(symbol);
    final price = _prices[symbol] ?? 0;
    final change = _changes[symbol] ?? 0;
    final hasPrice = price > 0;

    return InkWell(
      onTap: () {
        // For non-native tokens, tapping navigates to bridge
        _openBridge();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: _border, width: 0.5)),
        ),
        child: Row(
          children: [
            // Token icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _card,
                shape: BoxShape.circle,
                border: Border.all(color: _border),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 12),
            // Name + price change
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    symbol,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                      if (hasPrice) ...[
                        const SizedBox(width: 8),
                        Text(
                          _changeText(change),
                          style: TextStyle(
                            color: _changeColor(change),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Balance + USD
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _balanceVisible
                    ? Text(
                        '$bal $symbol',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      )
                    : const Text(
                        '••••',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                const SizedBox(height: 2),
                _balanceVisible
                    ? Text(
                        hasPrice ? _fmtUsd(usd) : '—',
                        style: const TextStyle(color: _muted, fontSize: 12),
                      )
                    : const Text(
                        '••••',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── NFTs tab ─────────────────────────────────────────────────────────────────

  Widget _buildNftsTab() {
    if (_nftLoading) {
      return const Center(child: CircularProgressIndicator(color: _blue));
    }

    final hasNft =
        _nftStatus != null &&
        (_nftStatus!['hasNft'] == true ||
            _nftStatus!['hasMintedNft'] == true ||
            _nftStatus!['exists'] == true);

    return RefreshIndicator(
      color: _blue,
      backgroundColor: _card,
      onRefresh: _loadNftStatus,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Row(
            children: [
              const Text(
                'ANET L1 NFTs',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _blue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Native',
                  style: TextStyle(
                    color: _blue,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Your native ANET L1 identity NFT — minted on the ANET chain, not BNB chain.',
            style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          if (hasNft) _buildNftCard() else _buildNoNftCard(),
        ],
      ),
    );
  }

  Widget _buildNftCard() {
    final nftName =
        (_nftStatus?['nftName'] ?? _nftStatus?['name'] ?? 'ANET Identity NFT')
            .toString();
    final primaryColorHex = (_nftStatus?['primaryColor'] ?? '#1677FF')
        .toString();
    Color primaryColor;
    try {
      primaryColor = Color(
        int.parse(primaryColorHex.replaceFirst('#', '0xFF')),
      );
    } catch (_) {
      primaryColor = _blue;
    }

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: primaryColor.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.12),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // NFT card header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor.withOpacity(0.25), _card],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryColor.withOpacity(0.2),
                        border: Border.all(
                          color: primaryColor.withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          nftName.isNotEmpty ? nftName[0].toUpperCase() : 'A',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nftName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'ANET L1 Identity NFT',
                            style: TextStyle(color: _muted, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _green.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Minted',
                                  style: TextStyle(
                                    color: _green,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _shortAddr(widget.anetAddress),
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openPublicNftProfile,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: _border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.public_rounded, size: 15),
                        label: const Text(
                          'Public View',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _openNftIdentityEditor,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(
                          Icons.edit_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Edit NFT',
                          style: TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Public note
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: _muted, size: 14),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Your NFT is publicly viewable. Anyone can view it by searching your ANET address.',
                  style: TextStyle(color: _muted, fontSize: 11, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoNftCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _blue.withOpacity(0.10),
              border: Border.all(color: _blue.withOpacity(0.3)),
            ),
            child: const Icon(Icons.badge_rounded, color: _blue, size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            'No ANET NFT Yet',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your native ANET L1 identity NFT. It\'s a publicly viewable profile tied to your wallet address.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _openNftIdentityEditor,
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
            label: const Text(
              'Create NFT Identity',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Activity tab ─────────────────────────────────────────────────────────────

  Widget _buildActivityTab() {
    if (_activityLoading) {
      return const Center(child: CircularProgressIndicator(color: _blue));
    }

    if (_bridgeHistory.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.receipt_long_rounded, size: 48, color: _muted),
              const SizedBox(height: 12),
              const Text(
                'No bridge activity yet',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your BSC → ANET L1 bridge transactions will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _openBridge,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(
                  Icons.swap_vert_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                label: const Text(
                  'Bridge Now',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: _blue,
      backgroundColor: _card,
      onRefresh: _loadActivity,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _bridgeHistory.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final tx = _bridgeHistory[i];
          final txHash = (tx['txHash'] ?? tx['tx_hash'] ?? '').toString();
          final symbol = (tx['tokenSymbol'] ?? tx['token_symbol'] ?? 'BNB')
              .toString();
          final amount = (tx['amount'] ?? '0').toString();
          final anetRec = (tx['anetRecipient'] ?? tx['anet_recipient'] ?? '')
              .toString();
          final status = (tx['status'] ?? 'pending').toString().toLowerCase();
          final createdAt = (tx['createdAt'] ?? tx['created_at'] ?? '')
              .toString();
          final shortDate = createdAt.length >= 16
              ? createdAt.substring(0, 16).replaceFirst('T', ' ')
              : createdAt;
          final shortHash = txHash.length > 14
              ? '${txHash.substring(0, 8)}…${txHash.substring(txHash.length - 4)}'
              : txHash;
          final shortRec = anetRec.length > 12
              ? '${anetRec.substring(0, 6)}…${anetRec.substring(anetRec.length - 4)}'
              : anetRec;

          final statusColor = status == 'processed' || status == 'completed'
              ? _green
              : status == 'failed'
              ? _red
              : _gold;

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _blue.withOpacity(0.12),
                    border: Border.all(color: _blue.withOpacity(0.3)),
                  ),
                  child: const Icon(
                    Icons.swap_vert_rounded,
                    color: _blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bridge $symbol → ANET L1',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'To: $shortRec',
                        style: const TextStyle(color: _muted, fontSize: 11),
                      ),
                      Text(
                        '$shortDate · TX: $shortHash',
                        style: const TextStyle(color: _muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '-$amount $symbol',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Receive bottom sheet
// ──────────────────────────────────────────────────────────────────────────────

class _ReceiveSheet extends StatelessWidget {
  const _ReceiveSheet({required this.evmAddress});
  final String evmAddress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _green.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: _green.withOpacity(0.3)),
              ),
              child: const Icon(
                Icons.south_west_rounded,
                color: _green,
                size: 26,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Receive on BNB Chain',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            // Network badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _gold.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _gold.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.circle, color: _green, size: 8),
                  SizedBox(width: 6),
                  Text(
                    'BNB Smart Chain (BEP-20)',
                    style: TextStyle(
                      color: _gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Send BNB, USDT, or USDC to this address.',
              style: TextStyle(color: _muted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: Column(
                children: [
                  // QR code
                  Center(
                    child: QrImageView(
                      data: evmAddress,
                      version: QrVersions.auto,
                      size: 180,
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.all(10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Address display (large, selectable)
                  SelectableText(
                    evmAddress,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: evmAddress),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Address copied!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(
                        Icons.copy_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      label: const Text(
                        'Copy Address',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: _gold, size: 14),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Only send BNB Chain (BSC) assets. Sending other chains may result in loss.',
                    style: TextStyle(color: _gold, fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Send bottom sheet — native BNB / BEP-20 P2P transfer
// ──────────────────────────────────────────────────────────────────────────────

class _SendSheet extends StatefulWidget {
  const _SendSheet({
    required this.evmAddress,
    required this.anetAddress,
    required this.privKeyBytes,
    required this.rawBalances,
    required this.service,
  });

  final String evmAddress;
  final String anetAddress;
  final Uint8List privKeyBytes;
  final Map<String, BigInt> rawBalances;
  final EvmWalletService service;

  @override
  State<_SendSheet> createState() => _SendSheetState();
}

class _SendSheetState extends State<_SendSheet> {
  final _toCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  String _selectedToken = 'BNB';
  bool _loading = false;
  String? _message;
  bool _success = false;
  String? _lastTxHash;

  // Username resolution state.
  // When the user types "@joel" or "joel" (no 0x prefix), we resolve it via
  // the on-chain registry and store the result here.
  String? _resolvedAddress; // 0x… address that ultimately receives funds
  String? _resolvedUsername; // display label e.g. "joel"
  bool _resolving = false;
  String? _resolveError;
  Timer? _resolveDebounce;

  final _sendableTokens = ['BNB', 'USDT', 'USDC', 'ANET'];

  @override
  void dispose() {
    _toCtrl.dispose();
    _amtCtrl.dispose();
    _resolveDebounce?.cancel();
    super.dispose();
  }

  void _onRecipientChanged(String raw) {
    // Reset previous resolution whenever the field changes.
    setState(() {
      _resolvedAddress = null;
      _resolvedUsername = null;
      _resolveError = null;
    });
    _resolveDebounce?.cancel();
    final stripped = raw.trim().replaceAll('@', '');
    if (stripped.isEmpty) return;
    if (RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(raw.trim())) return; // raw addr
    // Only attempt resolution if it could be a valid username.
    if (validateUsername(stripped) != null) return;
    _resolveDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _resolving = true);
      final addr = await usernameRegistry.resolve(stripped);
      if (!mounted) return;
      setState(() {
        _resolving = false;
        if (addr == null) {
          _resolveError = '@$stripped is not registered on BSC';
        } else {
          _resolvedAddress = addr;
          _resolvedUsername = stripped;
        }
      });
    });
  }

  String _feeDisplay() {
    final amountVal = double.tryParse(_amtCtrl.text.trim());
    if (amountVal == null || amountVal <= 0) {
      return '1% A-Network fee · recipient receives 99%';
    }
    final feeAmount = amountVal * _platformFeeBps / 10000;
    final netAmount = amountVal - feeAmount;
    String fmt(double v) {
      // trim trailing zeros, max 8 sig digits
      return v
          .toStringAsFixed(8)
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');
    }

    return 'Fee: ${fmt(feeAmount)} $_selectedToken (1%) · recipient gets: ${fmt(netAmount)} $_selectedToken';
  }

  String _availableBalance() {
    final raw = widget.rawBalances[_selectedToken] ?? BigInt.zero;
    final info = bscTokens[_selectedToken];
    if (info == null) return '0';
    final decimals = info['decimals'] as int? ?? 18;
    return formatUnits(raw, decimals, displayDecimals: 6);
  }

  Future<void> _send() async {
    final typed = _toCtrl.text.trim();
    // Accept either a raw 0x address or a resolved @username.
    String toAddr;
    if (RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(typed)) {
      toAddr = typed;
    } else if (_resolvedAddress != null) {
      toAddr = _resolvedAddress!;
    } else {
      setState(() {
        _message =
            'Invalid recipient. Enter a 0x… address or a registered @username.';
        _success = false;
      });
      return;
    }
    final amountStr = _amtCtrl.text.trim();
    final amountVal = double.tryParse(amountStr);
    if (amountVal == null || amountVal <= 0) {
      setState(() {
        _message = 'Invalid amount.';
        _success = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final credentials = EthPrivateKey(widget.privKeyBytes);
      final info = bscTokens[_selectedToken]!;
      final decimals = info['decimals'] as int;
      final amountUnits = parseUnits(amountStr, decimals);

      // ── 1 % platform fee split ────────────────────────────────────────────
      final feeUnits =
          amountUnits * BigInt.from(_platformFeeBps) ~/ BigInt.from(10000);
      final netUnits = amountUnits - feeUnits;
      final to = EthereumAddress.fromHex(toAddr);
      final feeAddr = EthereumAddress.fromHex(_anetFeeWallet);
      // ─────────────────────────────────────────────────────────────────────

      final client = await _pickWorkingBscClient();
      String txHash;

      try {
        // Fetch nonce + live gas price once for the whole send block.
        final senderAddr = credentials.address;
        final baseNonce = await client.getTransactionCount(
          senderAddr,
          atBlock: const BlockNum.pending(),
        );
        final gasPrice = await _liveGasPrice(client);

        if (info['native'] == true) {
          // Send net BNB to recipient (nonce = N)
          txHash = await client.sendTransaction(
            credentials,
            Transaction(
              to: to,
              value: EtherAmount.fromBigInt(EtherUnit.wei, netUnits),
              gasPrice: gasPrice,
              maxGas: 21000,
              nonce: baseNonce,
            ),
            chainId: bscChainId,
          );
          // Send 1% fee to A-Network fee wallet (nonce = N+1, best-effort)
          if (feeUnits > BigInt.zero) {
            try {
              await client.sendTransaction(
                credentials,
                Transaction(
                  to: feeAddr,
                  value: EtherAmount.fromBigInt(EtherUnit.wei, feeUnits),
                  gasPrice: gasPrice,
                  maxGas: 21000,
                  nonce: baseNonce + 1,
                ),
                chainId: bscChainId,
              );
            } catch (_) {} // fee tx failure must not block the user
          }
        } else {
          // Send BEP-20 token
          final tokenAddr = EthereumAddress.fromHex(info['address'] as String);
          final contract = DeployedContract(
            ContractAbi.fromJson(_erc20TransferAbi, 'ERC20'),
            tokenAddr,
          );
          final fn = contract.function('transfer');
          // Send net amount to recipient (nonce = N)
          txHash = await client.sendTransaction(
            credentials,
            Transaction.callContract(
              contract: contract,
              function: fn,
              parameters: [to, netUnits],
              gasPrice: gasPrice,
              maxGas: 100000,
              nonce: baseNonce,
            ),
            chainId: bscChainId,
          );
          // Send 1% fee to A-Network fee wallet (nonce = N+1, best-effort)
          if (feeUnits > BigInt.zero) {
            try {
              await client.sendTransaction(
                credentials,
                Transaction.callContract(
                  contract: contract,
                  function: fn,
                  parameters: [feeAddr, feeUnits],
                  gasPrice: gasPrice,
                  maxGas: 100000,
                  nonce: baseNonce + 1,
                ),
                chainId: bscChainId,
              );
            } catch (_) {} // fee tx failure must not block the user
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
              '✅ Sent! TX: ${txHash.length >= 10 ? txHash.substring(0, 10) : txHash}…';
        });
      }
      // Report to ANET L1 chain (best-effort, fire-and-forget)
      unawaited(
        _reportEvmActivity(
          txHash: txHash,
          activityType: 'send',
          tokenSymbol: _selectedToken,
          amount: amountStr,
          evmAddress: widget.evmAddress,
          anetAddress: widget.anetAddress,
        ),
      );
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
                  color: _border,
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
                    color: _gold.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: _gold.withOpacity(0.3)),
                  ),
                  child: const Icon(
                    Icons.north_east_rounded,
                    color: _gold,
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
              ],
            ),
            const SizedBox(height: 16),
            // Token selector
            Row(
              children: _sendableTokens.map((t) {
                final selected = t == _selectedToken;
                return GestureDetector(
                  onTap: () => setState(() => _selectedToken = t),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? _blue.withOpacity(0.15) : _card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? _blue : _border),
                    ),
                    child: Text(
                      t,
                      style: TextStyle(
                        color: selected ? _blue : _muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 4),
            Text(
              'Available: ${_availableBalance()} $_selectedToken',
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
            const SizedBox(height: 12),
            // To address (with Paste button) — accepts 0x… or @username
            TextField(
              controller: _toCtrl,
              onChanged: _onRecipientChanged,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Recipient — 0x… address or @username',
                labelStyle: const TextStyle(color: _muted, fontSize: 13),
                filled: true,
                fillColor: _card,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _blue),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                suffixIcon: TextButton.icon(
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    final txt = (data?.text ?? '').trim();
                    if (txt.isNotEmpty) {
                      setState(() => _toCtrl.text = txt);
                      _onRecipientChanged(txt);
                    }
                  },
                  icon: const Icon(
                    Icons.content_paste_rounded,
                    color: _blue,
                    size: 14,
                  ),
                  label: const Text(
                    'Paste',
                    style: TextStyle(
                      color: _blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ),
            // Username resolution preview / status
            if (_resolving)
              const Padding(
                padding: EdgeInsets.only(top: 6, left: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: _blue,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Resolving username on BSC…',
                      style: TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              )
            else if (_resolvedAddress != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: _green, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Sending to @${_resolvedUsername!} '
                        '(${_resolvedAddress!.substring(0, 6)}…${_resolvedAddress!.substring(_resolvedAddress!.length - 4)})',
                        style: const TextStyle(
                          color: _green,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (_resolveError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.orangeAccent,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _resolveError!,
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            // Amount (with MAX button)
            TextField(
              controller: _amtCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Amount ($_selectedToken)',
                labelStyle: const TextStyle(color: _muted, fontSize: 13),
                filled: true,
                fillColor: _card,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _blue),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () {
                        // Fill amount with available balance; reserve a tiny
                        // amount of BNB for gas if sending native BNB.
                        final raw =
                            widget.rawBalances[_selectedToken] ?? BigInt.zero;
                        final info = bscTokens[_selectedToken];
                        if (info == null) return;
                        final decimals = info['decimals'] as int? ?? 18;
                        var usable = raw;
                        if (info['native'] == true) {
                          // reserve 0.0005 BNB for gas
                          final gasReserve =
                              BigInt.from(5) * BigInt.from(10).pow(14);
                          usable = raw > gasReserve
                              ? raw - gasReserve
                              : BigInt.zero;
                        }
                        setState(() {
                          _amtCtrl.text = formatUnits(
                            usable,
                            decimals,
                            displayDecimals: 6,
                          );
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'MAX',
                        style: TextStyle(
                          color: _gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12, left: 4),
                      child: Text(
                        _selectedToken,
                        style: const TextStyle(color: _muted, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Fee breakdown card (MetaMask-style)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.toll_rounded, size: 13, color: _gold),
                        SizedBox(width: 6),
                        Text(
                          'Network & Platform Fees',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _feeDisplay(),
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Gas (BNB) is paid separately by you to the BSC network.',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 10,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _message!,
                  style: TextStyle(
                    color: _success ? _green : Colors.orangeAccent,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading || _success ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  disabledBackgroundColor: _gold.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
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
                    : Text(
                        _success ? 'Sent!' : 'Send $_selectedToken',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
            if (_success && _lastTxHash != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final url = Uri.parse(
                        'https://bscscan.com/tx/$_lastTxHash',
                      );
                      if (await canLaunchUrl(url)) {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _blue,
                      side: const BorderSide(color: _blue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 14),
                    label: const Text(
                      'View on BscScan',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: _gold, size: 13),
                SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Double-check the recipient address. BSC transfers are irreversible.',
                    style: TextStyle(color: _gold, fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Buy bottom sheet
// ──────────────────────────────────────────────────────────────────────────────

class _BuySheet extends StatelessWidget {
  const _BuySheet({required this.evmAddress});
  final String evmAddress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _blue.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: _blue.withOpacity(0.3)),
              ),
              child: const Icon(Icons.wallet_rounded, color: _blue, size: 26),
            ),
            const SizedBox(height: 14),
            const Text(
              'Add Funds',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Fully decentralised — no fiat on-ramp.',
              style: TextStyle(color: _muted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            // Option 1: Crypto Card (Binance Card)
            _buyOption(
              context,
              icon: Icons.credit_card_rounded,
              color: _gold,
              title: 'Crypto Card (Binance Card)',
              subtitle: 'Spend BNB / USDT anywhere Visa is accepted',
              onTap: () async {
                const url = 'https://www.binance.com/en/cards';
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                }
                if (context.mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
            // Option 2: P2P — buy BNB from other users
            _buyOption(
              context,
              icon: Icons.people_alt_rounded,
              color: _green,
              title: 'P2P — Buy BNB',
              subtitle: 'Peer-to-peer via Binance P2P, no middleman',
              onTap: () async {
                const url = 'https://p2p.binance.com/';
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                }
                if (context.mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
            // Option 3: Swap tokens (PancakeSwap V2, 23 supported tokens)
            _buyOption(
              context,
              icon: Icons.swap_horiz_rounded,
              color: const Color(0xFF9B59FF),
              title: 'Swap tokens (BNB ↔ USDT, USDC, +20 more)',
              subtitle:
                  'Instant in-app swap on PancakeSwap V2  •  1% fee  •  no bridge needed',
              onTap: () => Navigator.pop(context, 'swap'),
            ),
            const SizedBox(height: 12),
            // Option 4: Bridge BSC → ANET L1
            _buyOption(
              context,
              icon: Icons.swap_vert_rounded,
              color: _blue,
              title: 'Bridge → ANET L1',
              subtitle: 'Bridge BNB / USDT / USDC → ANET L1  •  1% fee',
              onTap: () => Navigator.pop(context, 'bridge'),
            ),
            const SizedBox(height: 16),
            Row(
              children: const [
                Icon(Icons.info_outline_rounded, color: _muted, size: 13),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'A 1% platform fee applies on all A-Network transactions.',
                    style: TextStyle(color: _muted, fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buyOption(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: _muted,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Swap bottom sheet — PancakeSwap V2 on BSC with 1% platform fee
// ──────────────────────────────────────────────────────────────────────────────

class _SwapSheet extends StatefulWidget {
  const _SwapSheet({
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
  State<_SwapSheet> createState() => _SwapSheetState();
}

class _SwapSheetState extends State<_SwapSheet> {
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

  static const _swapTokens = ['BNB', 'USDT', 'USDC', 'ANET'];

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

  // Build the token path for PancakeSwap routing
  List<EthereumAddress> _getPath(String from, String to) {
    EthereumAddress addr(String sym) => sym == 'BNB'
        ? EthereumAddress.fromHex(_wbnbAddr)
        : EthereumAddress.fromHex(bscTokens[sym]!['address'] as String);
    // Direct route when one side is BNB/WBNB; otherwise route through WBNB
    if (from == 'BNB' || to == 'BNB') return [addr(from), addr(to)];
    return [addr(from), EthereumAddress.fromHex(_wbnbAddr), addr(to)];
  }

  Future<void> _fetchQuote() async {
    final amtVal = double.tryParse(_amtCtrl.text.trim());
    if (amtVal == null || amtVal <= 0 || _fromToken == _toToken) {
      if (mounted) setState(() => _estimatedOut = '');
      return;
    }
    if (mounted) setState(() => _quoting = true);
    try {
      final client = await _pickWorkingBscClient();
      try {
        final fromDec = bscTokens[_fromToken]!['decimals'] as int;
        final toDec = bscTokens[_toToken]!['decimals'] as int;
        // Quote on net 99% (after 1% fee)
        final netAmt = parseUnits(
          (amtVal * 0.99).toStringAsFixed(fromDec),
          fromDec,
        );
        final router = DeployedContract(
          ContractAbi.fromJson(_pancakeRouterAbi, 'PancakeRouter'),
          EthereumAddress.fromHex(_pancakeRouterAddr),
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

  String _availableBalance() {
    final raw = widget.rawBalances[_fromToken] ?? BigInt.zero;
    final info = bscTokens[_fromToken];
    if (info == null) return '0';
    return formatUnits(raw, info['decimals'] as int, displayDecimals: 6);
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
          amtUnits * BigInt.from(_platformFeeBps) ~/ BigInt.from(10000);
      final netUnits = amtUnits - feeUnits;
      final feeAddr = EthereumAddress.fromHex(_anetFeeWallet);
      final client = await _pickWorkingBscClient();
      String txHash = '';

      try {
        // Fresh quote for amountOutMin (5% slippage tolerance)
        BigInt amountOutMin = BigInt.zero;
        try {
          final router0 = DeployedContract(
            ContractAbi.fromJson(_pancakeRouterAbi, 'PancakeRouter'),
            EthereumAddress.fromHex(_pancakeRouterAddr),
          );
          final qRes = await client.call(
            contract: router0,
            function: router0.function('getAmountsOut'),
            params: [netUnits, _getPath(_fromToken, _toToken)],
          );
          final outRaw = (qRes[0] as List).last as BigInt;
          amountOutMin = outRaw * BigInt.from(95) ~/ BigInt.from(100);
        } catch (_) {
          /* proceed with 0 min if quote fails */
        }

        final senderAddr = creds.address;
        var baseNonce = await client.getTransactionCount(
          senderAddr,
          atBlock: const BlockNum.pending(),
        );
        final gasPrice = await _liveGasPrice(client);
        final router = DeployedContract(
          ContractAbi.fromJson(_pancakeRouterAbi, 'PancakeRouter'),
          EthereumAddress.fromHex(_pancakeRouterAddr),
        );
        final deadline = BigInt.from(
          (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 300,
        );
        final path = _getPath(_fromToken, _toToken);

        if (fromInfo['native'] == true) {
          // ── BNB → ERC20 ────────────────────────────────────────────────────
          // Fee TX: 1% BNB to fee wallet
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
          // Swap TX: swapExactETHForTokens with net 99% BNB
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
          // ── ERC20 → BNB  or  ERC20 → ERC20 ────────────────────────────────
          final tokenAddr = EthereumAddress.fromHex(
            fromInfo['address'] as String,
          );
          final erc20 = DeployedContract(
            ContractAbi.fromJson(_erc20ApproveAbi, 'ERC20'),
            tokenAddr,
          );
          // Check router allowance; approve max if insufficient
          final allowRes = await client.call(
            contract: erc20,
            function: erc20.function('allowance'),
            params: [senderAddr, EthereumAddress.fromHex(_pancakeRouterAddr)],
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
                contract: erc20,
                function: erc20.function('approve'),
                parameters: [
                  EthereumAddress.fromHex(_pancakeRouterAddr),
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

          // Fee TX: 1% ERC20 to fee wallet
          if (feeUnits > BigInt.zero) {
            try {
              final erc20Tx = DeployedContract(
                ContractAbi.fromJson(_erc20TransferAbi, 'ERC20Transfer'),
                tokenAddr,
              );
              await client.sendTransaction(
                creds,
                Transaction.callContract(
                  contract: erc20Tx,
                  function: erc20Tx.function('transfer'),
                  parameters: [feeAddr, feeUnits],
                  gasPrice: gasPrice,
                  maxGas: 100000,
                  nonce: baseNonce,
                ),
                chainId: bscChainId,
              );
              baseNonce += 1;
            } catch (_) {}
          }

          // Swap TX
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
      // Report to ANET L1 chain (best-effort, fire-and-forget)
      if (txHash.isNotEmpty) {
        unawaited(
          _reportEvmActivity(
            txHash: txHash,
            activityType: 'swap',
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
    final toTokens = _swapTokens.where((t) => t != _fromToken).toList();
    final safeToToken = toTokens.contains(_toToken) ? _toToken : toTokens.first;

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
                  color: _border,
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
                    color: const Color(0xFF9B59FF).withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF9B59FF).withOpacity(0.3),
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
                    color: _muted.withOpacity(0.12),
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
                const Spacer(),
                Text(
                  'Available: ${_availableBalance()} $_fromToken',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _fromToken,
                      dropdownColor: _card,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      items: _swapTokens
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _fromToken = v;
                          if (_toToken == v) {
                            _toToken = _swapTokens.firstWhere((t) => t != v);
                          }
                          _estimatedOut = '';
                        });
                        _fetchQuote();
                      },
                    ),
                  ),
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
                      hintStyle: TextStyle(color: _muted.withOpacity(0.5)),
                      filled: true,
                      fillColor: _card,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF9B59FF)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Swap-direction arrow
            Center(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    final tmp = _fromToken;
                    _fromToken = _toToken;
                    _toToken = tmp;
                    _estimatedOut = '';
                  });
                  _fetchQuote();
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9B59FF).withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF9B59FF).withOpacity(0.4),
                    ),
                  ),
                  child: const Icon(
                    Icons.swap_vert_rounded,
                    color: Color(0xFF9B59FF),
                    size: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // TO row
            const Text(
              'To',
              style: TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: safeToToken,
                      dropdownColor: _card,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      items: toTokens
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _toToken = v;
                          _estimatedOut = '';
                        });
                        _fetchQuote();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: _quoting
                        ? const SizedBox(
                            height: 18,
                            child: LinearProgressIndicator(
                              color: Color(0xFF9B59FF),
                              backgroundColor: _border,
                            ),
                          )
                        : Text(
                            _estimatedOut.isEmpty
                                ? '—'
                                : '≈ $_estimatedOut $_toToken',
                            style: TextStyle(
                              color: _estimatedOut.isEmpty
                                  ? _muted
                                  : Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Fee note
            Row(
              children: [
                const Icon(Icons.toll_rounded, size: 12, color: _muted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '1% platform fee on $_fromToken → A-Network wallet  •  5% slippage tolerance',
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                ),
              ],
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _message!,
                  style: TextStyle(
                    color: _success ? _green : Colors.orangeAccent,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading || _success ? null : _executeSwap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9B59FF),
                  disabledBackgroundColor: const Color(
                    0xFF9B59FF,
                  ).withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
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
                    : Text(
                        _success ? 'Swapped!' : 'Swap $_fromToken → $_toToken',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
            if (_success && _lastTxHash != null && _lastTxHash!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final url = Uri.parse(
                        'https://bscscan.com/tx/$_lastTxHash',
                      );
                      if (await canLaunchUrl(url)) {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _blue,
                      side: const BorderSide(color: _blue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 14),
                    label: const Text(
                      'View on BscScan',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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

// ─── Add custom token bottom sheet ───────────────────────────────────────────

class _AddTokenSheet extends StatefulWidget {
  const _AddTokenSheet({required this.onSubmit});

  /// Returns null on success, or an error message string on failure.
  final Future<String?> Function(String address) onSubmit;

  @override
  State<_AddTokenSheet> createState() => _AddTokenSheetState();
}

class _AddTokenSheetState extends State<_AddTokenSheet> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await widget.onSubmit(_ctrl.text);
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Token imported')));
    } else {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      _ctrl.text = text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Add custom token',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Paste the BSC (BEP-20) contract address. We\u2019ll look up '
                'the token name, symbol and decimals on-chain.',
                style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ctrl,
                enabled: !_busy,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '0x…',
                  hintStyle: const TextStyle(color: _muted),
                  filled: true,
                  fillColor: _card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _blue),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.content_paste_rounded,
                      color: _muted,
                      size: 18,
                    ),
                    onPressed: _busy ? null : _pasteFromClipboard,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: _red, fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    disabledBackgroundColor: _blue.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Import token',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Card tab feature row ────────────────────────────────────────────────────

class _CardFeatureRow extends StatelessWidget {
  const _CardFeatureRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _blue, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: _muted, fontSize: 12, height: 1.4),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Claim @username sheet (on-chain AnetUsernameRegistry on BSC)
// ──────────────────────────────────────────────────────────────────────────────

class _ClaimUsernameSheet extends StatefulWidget {
  const _ClaimUsernameSheet({
    required this.evmAddress,
    required this.privKeyBytes,
  });

  final String evmAddress;
  final Uint8List privKeyBytes;

  @override
  State<_ClaimUsernameSheet> createState() => _ClaimUsernameSheetState();
}

class _ClaimUsernameSheetState extends State<_ClaimUsernameSheet> {
  final _nameCtrl = TextEditingController();
  Timer? _debounce;
  bool _checking = false;
  bool? _available;
  String? _validationError;
  bool _submitting = false;
  String? _resultMsg;
  bool _success = false;
  String? _txHash;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String raw) {
    final clean = raw.trim().toLowerCase().replaceAll('@', '');
    setState(() {
      _validationError = validateUsername(clean);
      _available = null;
    });
    _debounce?.cancel();
    if (_validationError != null) return;
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _checking = true);
      final ok = await usernameRegistry.isAvailable(clean);
      if (!mounted) return;
      setState(() {
        _checking = false;
        _available = ok;
      });
    });
  }

  Future<void> _submit() async {
    final clean = _nameCtrl.text.trim().toLowerCase().replaceAll('@', '');
    final err = validateUsername(clean);
    if (err != null) {
      setState(() => _validationError = err);
      return;
    }
    if (_available != true) {
      setState(() => _resultMsg = 'That name is not available.');
      return;
    }
    setState(() {
      _submitting = true;
      _resultMsg = null;
    });
    try {
      final creds = EthPrivateKey(widget.privKeyBytes);
      final hash = await usernameRegistry.register(
        name: clean,
        credentials: creds,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _success = true;
        _txHash = hash;
        _resultMsg = '✅ Claimed @$clean! Sent to BSC for confirmation.';
      });
      // Pop after a short delay so user can see the success state.
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context, clean);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _success = false;
        _resultMsg = 'Error: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final clean = _nameCtrl.text.trim().toLowerCase().replaceAll('@', '');
    final canSubmit =
        !_submitting && _available == true && _validationError == null;
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
                  color: _border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _green.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: _green.withOpacity(0.4)),
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: _green,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Claim your @username',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Your username is your decentralized identity. People can send '
              'you BNB / USDT / USDC / ANET using @yourname instead of a long '
              '0x… address.',
              style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              onChanged: _onChanged,
              autofocus: true,
              maxLength: 20,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                prefixText: '@',
                prefixStyle: const TextStyle(
                  color: _blue,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                labelText: 'Username',
                labelStyle: const TextStyle(color: _muted, fontSize: 13),
                helperText:
                    '3-20 chars · a-z · 0-9 · underscore · starts with a letter',
                helperStyle: const TextStyle(color: _muted, fontSize: 10),
                counterStyle: const TextStyle(color: _muted, fontSize: 10),
                filled: true,
                fillColor: _card,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _blue),
                ),
              ),
            ),
            if (_validationError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  _validationError!,
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 11,
                  ),
                ),
              )
            else if (_checking)
              const Padding(
                padding: EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  'Checking availability…',
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
              )
            else if (_available == true && clean.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: _green,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '@$clean is available',
                      style: const TextStyle(
                        color: _green,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else if (_available == false && clean.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Row(
                  children: [
                    const Icon(Icons.cancel_rounded, color: _red, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      '@$clean is taken',
                      style: const TextStyle(color: _red, fontSize: 11),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Row(
                    children: [
                      Icon(Icons.payments_rounded, color: _gold, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Registration fee: 0.001 BNB',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'One-time fee paid on BSC. Username is permanent and '
                    'transferable. Gas fees apply.',
                    style: TextStyle(color: _muted, fontSize: 11, height: 1.4),
                  ),
                ],
              ),
            ),
            if (_resultMsg != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _resultMsg!,
                  style: TextStyle(
                    color: _success ? _green : Colors.orangeAccent,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canSubmit ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  disabledBackgroundColor: _green.withOpacity(0.35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _success ? 'Claimed!' : 'Claim @username (0.001 BNB)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
            if (_success && _txHash != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final url = Uri.parse('https://bscscan.com/tx/$_txHash');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _blue,
                      side: const BorderSide(color: _blue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 14),
                    label: const Text(
                      'View on BscScan',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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
