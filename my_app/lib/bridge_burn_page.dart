import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';

// ─── Theme (matches dex_page.dart / evm_bridge_page.dart) ────────────────────
const _bg = Color(0xFF07111F);
const _surface = Color(0xFF0A1224);
const _card = Color(0xFF0F1C2E);
const _blue = Color(0xFF1677FF);
const _green = Color(0xFF25C474);
const _gold = Color(0xFFFFB800);
const _red = Color(0xFFFF4D4F);
const _muted = Color(0xFF7B829A);

const _historyKey = 'bridge_burn_history_v1';
const _bscScanBase = 'https://bscscan.com/tx/';
const int _antsPerAnet = 100000000; // 1 ANET = 1e8 ants

/// L1 → BSC bridge burn screen.
///
/// Burns N ANET from the user's L1 wallet and triggers the 2-of-3 vault
/// release of an equivalent amount of wANET (BEP-20) to a BSC recipient.
class BridgeBurnPage extends StatefulWidget {
  const BridgeBurnPage({
    super.key,
    required this.walletAddress,
    required this.seedPhrase,
    required this.signActionAuth,
    this.signWithKeyAuth,
    this.cachedSigningKey,
    this.defaultBscRecipient,
  });

  final String walletAddress;
  final String seedPhrase;
  final Map<String, dynamic> Function(String actionType, String seedPhrase)
  signActionAuth;
  final Map<String, dynamic> Function(
    String actionType,
    Uint8List privateKeyBytes,
  )?
  signWithKeyAuth;
  final Uint8List? cachedSigningKey;

  /// Optional pre-fill (e.g. the user's own EVM wallet address).
  final String? defaultBscRecipient;

  @override
  State<BridgeBurnPage> createState() => _BridgeBurnPageState();
}

class _BridgeBurnPageState extends State<BridgeBurnPage> {
  final _amountCtrl = TextEditingController();
  final _recipientCtrl = TextEditingController();

  bool _submitting = false;
  String? _error;

  /// One-shot legacy→secp on-chain migration flag for this session. Until
  /// this runs, the L1 will reject bridge_burn signatures from users whose
  /// wallet_address is the original RIPEMD160(SHA256(hex(pk))) derivation.
  /// The /auth/wallet/migrate-to-secp endpoint is idempotent.
  bool _walletUpgradedThisSession = false;

  /// Active burn we are tracking on this screen.
  Map<String, dynamic>? _activeBurn;
  Timer? _pollTimer;

  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    if (widget.defaultBscRecipient != null &&
        widget.defaultBscRecipient!.trim().isNotEmpty) {
      _recipientCtrl.text = widget.defaultBscRecipient!.trim();
    }
    _loadHistory();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _activePollBurnId = null;
    _amountCtrl.dispose();
    _recipientCtrl.dispose();
    super.dispose();
  }

  // ── Persistence ────────────────────────────────────────────────────────────
  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .toList();
      if (mounted) setState(() => _history = list);
    } catch (_) {}
  }

  Future<void> _saveHistory(Map<String, dynamic> entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final next = [entry, ..._history].take(50).toList();
      await prefs.setString(_historyKey, jsonEncode(next));
      if (mounted) setState(() => _history = next);
    } catch (_) {}
  }

  Future<void> _updateHistoryEntry(
    int burnId,
    Map<String, dynamic> patch,
  ) async {
    try {
      final next = _history.map((e) {
        if ((e['burn_id'] as num?)?.toInt() == burnId) {
          return {...e, ...patch};
        }
        return e;
      }).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_historyKey, jsonEncode(next));
      if (mounted) setState(() => _history = next);
    } catch (_) {}
  }

  // ── Validation ─────────────────────────────────────────────────────────────
  static final RegExp _bscAddr = RegExp(r'^0x[0-9a-fA-F]{40}$');

  String? _validate() {
    final amt = double.tryParse(_amountCtrl.text.trim());
    if (amt == null || amt <= 0) {
      return 'Enter a positive ANET amount';
    }
    // Avoid float rounding: enforce <= 8 decimal places.
    final parts = _amountCtrl.text.trim().split('.');
    if (parts.length == 2 && parts[1].length > 8) {
      return 'ANET has at most 8 decimal places';
    }
    final recipient = _recipientCtrl.text.trim();
    if (!_bscAddr.hasMatch(recipient)) {
      return 'BSC recipient must be 0x… (40 hex)';
    }
    return null;
  }

  int _toAnts(String text) {
    // Parse "1.23456789" as ants without using double (avoids precision loss).
    final clean = text.trim();
    final parts = clean.split('.');
    final whole = BigInt.parse(parts[0]);
    BigInt frac = BigInt.zero;
    if (parts.length == 2) {
      final padded = parts[1].padRight(8, '0').substring(0, 8);
      frac = BigInt.parse(padded);
    }
    return (whole * BigInt.from(_antsPerAnet) + frac).toInt();
  }

  // ── Submit burn ────────────────────────────────────────────────────────────

  /// Prompts for the wallet PIN and runs the idempotent
  /// `/auth/wallet/migrate-to-secp` server-side migration. Returns true
  /// when the wallet is on the secp scheme (already-migrated counts).
  /// On failure, sets [_error] and returns false.
  Future<bool> _ensureSecpMigration() async {
    final pinCtrl = TextEditingController();
    bool approved = false;
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
              'Authorise Bridge',
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
                  'Enter your wallet PIN to authorise the L1→BSC bridge transfer.',
                  style: TextStyle(color: _muted, fontSize: 12),
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
                          await migrateWalletToSecpAPI(p);
                          approved = true;
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
                child: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Confirm'),
              ),
            ],
          );
        },
      ),
    );

    pinCtrl.dispose();

    if (!approved || approvedPin == null) {
      setState(() => _error = 'Bridge authorisation cancelled.');
      return false;
    }

    setState(() {
      _walletUpgradedThisSession = true;
      _error = null;
    });
    return true;
  }

  Future<void> _submitBurn() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }

    // ── One-shot legacy → secp on-chain migration ─────────────────────
    // Required before the L1 will accept any bridge_burn signature for
    // users whose wallet_address is still the legacy derivation. The
    // backend endpoint is idempotent.
    if (!_walletUpgradedThisSession) {
      final upgraded = await _ensureSecpMigration();
      if (!upgraded) return; // _error already set by the helper
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    Map<String, dynamic>? auth;
    try {
      if (widget.cachedSigningKey != null && widget.signWithKeyAuth != null) {
        auth = widget.signWithKeyAuth!('bridge_burn', widget.cachedSigningKey!);
      } else {
        auth = widget.signActionAuth('bridge_burn', widget.seedPhrase);
      }
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = 'Signing failed: $e';
      });
      return;
    }

    final amountAnts = _toAnts(_amountCtrl.text);
    final recipient = _recipientCtrl.text.trim().toLowerCase();

    try {
      final resp = await http
          .post(
            Uri.parse('$l1BaseUrl/bridge/burn'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              // sender MUST equal auth.wallet (the secp address the chain
              // recovers from the signature).  widget.walletAddress may
              // still be the legacy form until on-chain migrate succeeds.
              'sender': (auth['wallet']?.toString() ?? widget.walletAddress)
                  .trim()
                  .toUpperCase(),
              'bsc_recipient': recipient,
              'amount_ants': amountAnts,
              'token_symbol': 'ANET',
              'auth': auth,
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (resp.statusCode != 200) {
        String msg = 'HTTP ${resp.statusCode}';
        try {
          final j = jsonDecode(resp.body);
          if (j is Map && j['error'] is String) {
            msg = j['error'] as String;
          } else if (j is Map && j['message'] is String)
            msg = j['message'] as String;
        } catch (_) {
          if (resp.body.isNotEmpty) msg = resp.body;
        }
        setState(() {
          _submitting = false;
          _error = msg;
        });
        return;
      }

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final burnId = (body['burn_id'] as num).toInt();

      final entry = {
        'burn_id': burnId,
        'ts': DateTime.now().toUtc().toIso8601String(),
        'sender': body['l1_sender'] ?? widget.walletAddress,
        'bsc_recipient': body['bsc_recipient'] ?? recipient,
        'amount_ants': amountAnts,
        'anet_burned':
            body['anet_burned']?.toString() ?? _formatAnet(amountAnts),
        'status': body['status'] ?? 'pending',
        'bsc_tx_hash': null,
      };
      await _saveHistory(entry);

      if (mounted) {
        setState(() {
          _submitting = false;
          _activeBurn = entry;
          _amountCtrl.clear();
        });
      }
      _startPolling(burnId);
    } on TimeoutException {
      setState(() {
        _submitting = false;
        _error = 'Request timed out. Try again.';
      });
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = 'Network error: $e';
      });
    }
  }

  // ── Polling ────────────────────────────────────────────────────────────────
  //
  // We use HTTP long-poll: the L1 holds the connection open up to 25s and
  // returns as soon as the burn transitions to a terminal status
  // (`released`/`failed`/`skipped`). This is what makes the L1→wANET swap
  // feel instant — typically a single request returns with the BSC tx hash
  // a few seconds after the relayer releases on BSC.
  //
  // The active-burn id is tracked separately so we can cancel the chain on
  // dispose or when starting a new burn.
  int? _activePollBurnId;

  void _startPolling(int burnId) {
    _pollTimer?.cancel();
    _pollTimer = null;
    _activePollBurnId = burnId;
    unawaited(_pollLoop(burnId));
  }

  Future<void> _pollLoop(int burnId) async {
    // Short-poll once immediately so the UI shows 'pending' fast even if
    // long-poll on the server is unsupported.
    await _pollOnce(burnId, waitMs: 0);
    while (mounted && _activePollBurnId == burnId) {
      final reachedTerminal = await _pollOnce(burnId, waitMs: 25000);
      if (reachedTerminal) break;
      // Small jitter so a flaky network doesn't tight-loop.
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  /// Returns true when the burn is in a terminal status and polling should
  /// stop.
  Future<bool> _pollOnce(int burnId, {int waitMs = 0}) async {
    try {
      final uri = Uri.parse(
        '$l1BaseUrl/bridge/burns/$burnId'
        '${waitMs > 0 ? '?wait_ms=$waitMs' : ''}',
      );
      // HTTP timeout is generous: long-poll budget + headroom.
      final httpTimeout = Duration(milliseconds: waitMs + 10000);
      final resp = await http.get(uri).timeout(httpTimeout);
      if (resp.statusCode != 200) return false;
      final row = jsonDecode(resp.body) as Map<String, dynamic>;
      final status = (row['status'] as String?) ?? 'pending';
      final tx = row['bsc_tx_hash'] as String?;
      final errMsg = row['error'] as String?;

      await _updateHistoryEntry(burnId, {
        'status': status,
        'bsc_tx_hash': tx,
        'error': ?errMsg,
      });

      if (mounted &&
          _activeBurn != null &&
          (_activeBurn!['burn_id'] as num).toInt() == burnId) {
        setState(() {
          _activeBurn = {
            ..._activeBurn!,
            'status': status,
            'bsc_tx_hash': tx,
            'error': ?errMsg,
          };
        });
      }

      if (status == 'released' || status == 'failed' || status == 'skipped') {
        if (_activePollBurnId == burnId) _activePollBurnId = null;
        return true;
      }
      return false;
    } catch (_) {
      // Silent — next iteration will retry.
      return false;
    }
  }

  // ── Formatting helpers ─────────────────────────────────────────────────────
  String _formatAnet(int ants) {
    if (ants <= 0) return '0';
    final big = BigInt.from(ants);
    final whole = big ~/ BigInt.from(_antsPerAnet);
    final frac = big % BigInt.from(_antsPerAnet);
    final fracStr = frac
        .toString()
        .padLeft(8, '0')
        .replaceAll(RegExp(r'0+$'), '');
    return fracStr.isEmpty ? '$whole' : '$whole.$fracStr';
  }

  String _shortAddr(String? a) {
    if (a == null || a.length < 12) return a ?? '';
    return '${a.substring(0, 6)}…${a.substring(a.length - 4)}';
  }

  Future<void> _openBscScan(String tx) async {
    final uri = Uri.parse('$_bscScanBase$tx');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _toast('Could not open BscScan');
    }
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? _red : _card,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        title: const Text(
          'Bridge ANET → BSC',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _senderCard(),
              const SizedBox(height: 12),
              _formCard(),
              const SizedBox(height: 12),
              if (_activeBurn != null) _activeBurnCard(_activeBurn!),
              if (_activeBurn != null) const SizedBox(height: 12),
              if (_history.isNotEmpty) _historySection(),
              const SizedBox(height: 24),
              _infoFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _senderCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_outlined, color: _blue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'From (L1)',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
                Text(
                  widget.walletAddress,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy, size: 18, color: _muted),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.walletAddress));
              _toast('Wallet copied');
            },
          ),
        ],
      ),
    );
  }

  Widget _formCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Amount (ANET)',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
            decoration: _inputDeco(hint: '0.00000001'),
          ),
          const SizedBox(height: 14),
          const Text(
            'BSC recipient (0x…)',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _recipientCtrl,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontSize: 14,
            ),
            decoration: _inputDeco(hint: '0xabc…'),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _red.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: _red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: _red, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submitBurn,
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                disabledBackgroundColor: _blue.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Burn & Bridge',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activeBurnCard(Map<String, dynamic> burn) {
    final status = (burn['status'] as String?) ?? 'pending';
    final tx = burn['bsc_tx_hash'] as String?;
    final err = burn['error'] as String?;
    final color = switch (status) {
      'released' => _green,
      'failed' => _red,
      'pending' || 'detected' || 'processing' => _gold,
      _ => _muted,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                status == 'released'
                    ? Icons.check_circle
                    : status == 'failed'
                    ? Icons.error
                    : Icons.hourglass_top,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                'Burn #${burn['burn_id']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _kv('Amount', '${burn['anet_burned']} ANET'),
          _kv('To (BSC)', _shortAddr(burn['bsc_recipient'] as String?)),
          if (tx != null && tx.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: InkWell(
                onTap: () => _openBscScan(tx),
                child: Row(
                  children: [
                    const Text(
                      'BSC tx',
                      style: TextStyle(color: _muted, fontSize: 13),
                    ),
                    const Spacer(),
                    Text(
                      _shortAddr(tx),
                      style: const TextStyle(
                        color: _blue,
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.open_in_new, size: 14, color: _blue),
                  ],
                ),
              ),
            ),
          if (err != null && err.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                err,
                style: const TextStyle(color: _red, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _historySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 4, 0, 8),
          child: Text(
            'History',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ..._history.take(10).map(_historyTile),
      ],
    );
  }

  Widget _historyTile(Map<String, dynamic> entry) {
    final status = (entry['status'] as String?) ?? 'pending';
    final tx = entry['bsc_tx_hash'] as String?;
    final color = switch (status) {
      'released' => _green,
      'failed' => _red,
      _ => _gold,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${entry['burn_id']} · ${entry['anet_burned']} ANET',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${status.toUpperCase()} → ${_shortAddr(entry['bsc_recipient'] as String?)}',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (tx != null && tx.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.open_in_new, color: _blue, size: 18),
              tooltip: 'View on BscScan',
              onPressed: () => _openBscScan(tx),
            ),
        ],
      ),
    );
  }

  Widget _infoFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: _muted, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Burns are released by a 2-of-3 vault signer quorum on BSC. '
              'Release typically completes within ~30s of the L1 burn. '
              'You will receive wANET (BEP-20) at the recipient address.',
              style: TextStyle(
                color: _muted.withValues(alpha: 0.9),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(k, style: const TextStyle(color: _muted, fontSize: 13)),
          const Spacer(),
          Text(
            v,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _muted),
      filled: true,
      fillColor: _surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _blue, width: 1.4),
      ),
    );
  }
}
