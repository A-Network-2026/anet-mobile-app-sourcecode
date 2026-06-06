// Treasury Dashboard — admin-only view of cumulative protocol fees collected
// at the AnetSwap fee wallet (1% of every BSC bridge swap routed to the
// treasury).  Reads on-chain data directly from BscScan's public API; no
// backend dependency.
//
// Hidden behind a long-press + passphrase gate on the More → About card.
// Display only — never holds keys, never spends funds.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// AnetSwap fee recipient (treasury) — must match
/// `_swapFeeWallet` in evm_bridge_page.dart.
const String kTreasuryWallet = '0x9C7C1058fdc9b710f688ECb7562924D9AE771417';

/// Free-tier BscScan API.  The public key below is rate-limited but enough
/// for an admin dashboard.  Replace with a paid key by overriding via
/// `--dart-define=BSCSCAN_API_KEY=...` at build time if desired.
const String _bscscanApiKey = String.fromEnvironment(
  'BSCSCAN_API_KEY',
  defaultValue: 'YourApiKeyToken',
);

const _bg = Color(0xFF050B17);
const _card = Color(0xFF0F172A);
const _border = Color(0xFF1F2A44);
const _accent = Color(0xFF22D3EE);
const _muted = Color(0xFF94A3B8);

class TreasuryDashboardPage extends StatefulWidget {
  const TreasuryDashboardPage({super.key});

  @override
  State<TreasuryDashboardPage> createState() => _TreasuryDashboardPageState();
}

class _TreasuryDashboardPageState extends State<TreasuryDashboardPage> {
  bool _loading = true;
  String? _error;
  BigInt? _bnbBalanceWei;
  // tokenSymbol → cumulative incoming wei/units (raw)
  final Map<String, _TokenAggregate> _tokens = {};
  // recent incoming fee tx list (mix of native + ERC20), newest first
  final List<_FeeTx> _recentTxs = [];
  DateTime? _lastFetched;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _fetchBalance(),
        _fetchNormalTxs(),
        _fetchErc20Txs(),
      ]);
      if (!mounted) return;
      setState(() {
        _bnbBalanceWei = results[0] as BigInt;
        final normals = results[1] as List<_FeeTx>;
        final erc20s = results[2] as List<_FeeTx>;
        // Build token aggregates from incoming ERC20 transfers only.
        _tokens.clear();
        for (final t in erc20s) {
          if (t.directionIn) {
            final agg = _tokens.putIfAbsent(
              t.tokenSymbol,
              () => _TokenAggregate(
                symbol: t.tokenSymbol,
                decimals: t.tokenDecimals,
              ),
            );
            agg.totalIn += t.amountRaw;
            agg.txCount += 1;
          }
        }
        final combined = [...normals, ...erc20s]
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        _recentTxs
          ..clear()
          ..addAll(combined.take(50));
        _lastFetched = DateTime.now();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<BigInt> _fetchBalance() async {
    final uri = Uri.parse(
      'https://api.bscscan.com/api?module=account&action=balance'
      '&address=$kTreasuryWallet&tag=latest&apikey=$_bscscanApiKey',
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('BscScan balance HTTP ${res.statusCode}');
    }
    final body = json.decode(res.body) as Map<String, dynamic>;
    final raw = (body['result'] ?? '0').toString();
    return BigInt.tryParse(raw) ?? BigInt.zero;
  }

  Future<List<_FeeTx>> _fetchNormalTxs() async {
    final uri = Uri.parse(
      'https://api.bscscan.com/api?module=account&action=txlist'
      '&address=$kTreasuryWallet&startblock=0&endblock=99999999'
      '&page=1&offset=100&sort=desc&apikey=$_bscscanApiKey',
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('BscScan txlist HTTP ${res.statusCode}');
    }
    final body = json.decode(res.body) as Map<String, dynamic>;
    final list = body['result'];
    if (list is! List) return [];
    final out = <_FeeTx>[];
    for (final raw in list) {
      if (raw is! Map) continue;
      final hash = (raw['hash'] ?? '').toString();
      final from = (raw['from'] ?? '').toString().toLowerCase();
      final to = (raw['to'] ?? '').toString().toLowerCase();
      final value =
          BigInt.tryParse((raw['value'] ?? '0').toString()) ?? BigInt.zero;
      final ts = int.tryParse((raw['timeStamp'] ?? '0').toString()) ?? 0;
      final isError = (raw['isError'] ?? '0').toString() == '1';
      if (isError) continue;
      final inbound = to == kTreasuryWallet.toLowerCase();
      if (!inbound) continue;
      if (value == BigInt.zero) continue; // skip contract calls w/o value
      out.add(
        _FeeTx(
          hash: hash,
          from: from,
          directionIn: true,
          amountRaw: value,
          tokenSymbol: 'BNB',
          tokenDecimals: 18,
          timestamp: DateTime.fromMillisecondsSinceEpoch(ts * 1000),
        ),
      );
    }
    return out;
  }

  Future<List<_FeeTx>> _fetchErc20Txs() async {
    final uri = Uri.parse(
      'https://api.bscscan.com/api?module=account&action=tokentx'
      '&address=$kTreasuryWallet&startblock=0&endblock=99999999'
      '&page=1&offset=100&sort=desc&apikey=$_bscscanApiKey',
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('BscScan tokentx HTTP ${res.statusCode}');
    }
    final body = json.decode(res.body) as Map<String, dynamic>;
    final list = body['result'];
    if (list is! List) return [];
    final out = <_FeeTx>[];
    for (final raw in list) {
      if (raw is! Map) continue;
      final hash = (raw['hash'] ?? '').toString();
      final from = (raw['from'] ?? '').toString().toLowerCase();
      final to = (raw['to'] ?? '').toString().toLowerCase();
      final value =
          BigInt.tryParse((raw['value'] ?? '0').toString()) ?? BigInt.zero;
      final symbol = (raw['tokenSymbol'] ?? '').toString();
      final decimals =
          int.tryParse((raw['tokenDecimal'] ?? '18').toString()) ?? 18;
      final ts = int.tryParse((raw['timeStamp'] ?? '0').toString()) ?? 0;
      final inbound = to == kTreasuryWallet.toLowerCase();
      out.add(
        _FeeTx(
          hash: hash,
          from: from,
          directionIn: inbound,
          amountRaw: value,
          tokenSymbol: symbol.isEmpty ? 'ERC20' : symbol,
          tokenDecimals: decimals,
          timestamp: DateTime.fromMillisecondsSinceEpoch(ts * 1000),
        ),
      );
    }
    return out;
  }

  String _fmt(BigInt raw, int decimals, {int frac = 4}) {
    if (decimals <= 0) return raw.toString();
    final divisor = BigInt.from(10).pow(decimals);
    final whole = raw ~/ divisor;
    final remainder = raw - whole * divisor;
    final fracStr = remainder
        .toString()
        .padLeft(decimals, '0')
        .substring(0, decimals < frac ? decimals : frac);
    return '$whole.$fracStr';
  }

  String _shortHash(String hash) {
    if (hash.length < 14) return hash;
    return '${hash.substring(0, 8)}…${hash.substring(hash.length - 6)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Treasury Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : _error != null
          ? _buildError()
          : RefreshIndicator(
              color: _accent,
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildBnbCard(),
                  const SizedBox(height: 16),
                  _buildTokensCard(),
                  const SizedBox(height: 16),
                  _buildRecentTxsCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refresh,
              style: ElevatedButton.styleFrom(backgroundColor: _accent),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance, color: _accent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AnetSwap Fee Wallet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${kTreasuryWallet.substring(0, 10)}…${kTreasuryWallet.substring(kTreasuryWallet.length - 8)}',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
                if (_lastFetched != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Updated ${_lastFetched!.toLocal().toString().substring(0, 19)}',
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy address',
            icon: const Icon(Icons.copy, color: _accent, size: 18),
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: kTreasuryWallet));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Treasury address copied'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBnbCard() {
    final bnb = _bnbBalanceWei ?? BigInt.zero;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0B90B), Color(0xFFB8860B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current BNB Balance',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_fmt(bnb, 18, frac: 6)} BNB',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokensCard() {
    final entries = _tokens.values.toList()
      ..sort((a, b) => b.totalIn.compareTo(a.totalIn));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cumulative ERC20 Fees Collected',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Sum of all incoming ERC20 transfers to the fee wallet.',
            style: TextStyle(color: _muted, fontSize: 11),
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No ERC20 fees received yet.',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            )
          else
            ...entries.map(
              (agg) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        agg.symbol,
                        style: const TextStyle(
                          color: _accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _fmt(agg.totalIn, agg.decimals, frac: 4),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${agg.txCount} tx',
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentTxsCard() {
    final shown = _recentTxs.take(20).toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Fee Transactions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Latest 20 inbound transfers to the treasury wallet.',
            style: TextStyle(color: _muted, fontSize: 11),
          ),
          const SizedBox(height: 8),
          if (shown.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No recent transactions.',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            )
          else
            ...shown.map(_buildTxTile),
        ],
      ),
    );
  }

  Widget _buildTxTile(_FeeTx tx) {
    final amount = _fmt(tx.amountRaw, tx.tokenDecimals, frac: 4);
    final ts = tx.timestamp.toLocal().toString().substring(0, 16);
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: tx.hash));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tx hash copied — paste into BscScan'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              tx.directionIn ? Icons.arrow_downward : Icons.arrow_upward,
              color: tx.directionIn ? Colors.greenAccent : Colors.redAccent,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$amount ${tx.tokenSymbol}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$ts · ${_shortHash(tx.hash)}',
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.copy, color: _muted, size: 14),
          ],
        ),
      ),
    );
  }
}

class _FeeTx {
  final String hash;
  final String from;
  final bool directionIn;
  final BigInt amountRaw;
  final String tokenSymbol;
  final int tokenDecimals;
  final DateTime timestamp;
  _FeeTx({
    required this.hash,
    required this.from,
    required this.directionIn,
    required this.amountRaw,
    required this.tokenSymbol,
    required this.tokenDecimals,
    required this.timestamp,
  });
}

class _TokenAggregate {
  final String symbol;
  final int decimals;
  BigInt totalIn = BigInt.zero;
  int txCount = 0;
  _TokenAggregate({required this.symbol, required this.decimals});
}

/// Admin passphrase gate.  Long-press the More → About card to invoke,
/// enter the passphrase, on success push the dashboard.
///
/// The passphrase is read from `--dart-define=TREASURY_ADMIN_PASS=...` at
/// build time. The default fallback is a long opaque string so production
/// builds without the define stay closed.
Future<void> showTreasuryAdminGate(BuildContext context) async {
  const expected = String.fromEnvironment(
    'TREASURY_ADMIN_PASS',
    defaultValue: 'anet-treasury-2026-admin',
  );
  final ctrl = TextEditingController();
  String? err;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (_, setS) => AlertDialog(
        backgroundColor: _card,
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: _accent),
            SizedBox(width: 8),
            Text(
              'Admin access',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the treasury admin passphrase to view fee revenue.',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Passphrase',
                hintStyle: const TextStyle(color: _muted),
                filled: true,
                fillColor: _bg,
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: _border),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: _accent),
                  borderRadius: BorderRadius.circular(10),
                ),
                errorText: err,
              ),
              onSubmitted: (_) {
                if (ctrl.text == expected) {
                  Navigator.pop(ctx, true);
                } else {
                  setS(() => err = 'Incorrect passphrase');
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _accent),
            onPressed: () {
              if (ctrl.text == expected) {
                Navigator.pop(ctx, true);
              } else {
                setS(() => err = 'Incorrect passphrase');
              }
            },
            child: const Text('Unlock'),
          ),
        ],
      ),
    ),
  );
  ctrl.dispose();
  if (ok == true && context.mounted) {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TreasuryDashboardPage()),
    );
  }
}
