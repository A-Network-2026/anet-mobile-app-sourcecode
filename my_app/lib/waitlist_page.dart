// Phase 1 Swap Waitlist viewer.
//
// Lets users see their pending / ready / executed / cancelled / expired
// swap intents (the queue we use while their wallet is still mining
// toward the activation threshold or waiting for a bridge credit).
//
// Cancellation is currently free everywhere on the server (Phase 1).
// Once DEX_FEE_WALLET_BNB is configured server-side, the server begins
// returning HTTP 402 for non-expired cancels and the UI here will be
// extended with a BNB fee payment step before completing the call.

import 'dart:async';

import 'package:flutter/material.dart';

import 'api.dart';

class WaitlistPage extends StatefulWidget {
  const WaitlistPage({super.key});

  @override
  State<WaitlistPage> createState() => _WaitlistPageState();
}

class _WaitlistPageState extends State<WaitlistPage> {
  static const _bg = Color(0xFF0A0E1A);
  static const _surface = Color(0xFF111827);
  static const _muted = Color(0xFF6B7280);
  static const _blue = Color(0xFF3B82F6);
  static const _green = Color(0xFF10B981);
  static const _red = Color(0xFFEF4444);
  static const _amber = Color(0xFFF59E0B);

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _intents = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await listMyWaitlistIntentsAPI();
      final raw = (res['intents'] as List?) ?? const [];
      setState(() {
        _intents = raw
            .whereType<Map>()
            .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _cancel(Map<String, dynamic> intent) async {
    final id = (intent['id'] as num).toInt();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        title: const Text(
          'Cancel waitlist intent?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This removes the intent from the queue.\n\n'
          'Phase 1: cancellation is currently free.\n'
          'Once the BNB fee wallet is enabled, future cancellations '
          'before expiry will require a small BNB fee.',
          style: TextStyle(color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel intent', style: TextStyle(color: _red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await cancelWaitlistIntentAPI(id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Intent cancelled')));
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _red,
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ready':
        return _green;
      case 'executed':
        return _blue;
      case 'cancelled':
        return _muted;
      case 'expired':
        return _amber;
      case 'pending':
      default:
        return _muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        title: const Text(
          'Swap Waitlist',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _muted),
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: _red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              )
            : _intents.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No waitlist intents.\n\n'
                        'When you try a swap but your wallet is not '
                        'activated yet, you can join the waitlist '
                        'and we will mark your intent as ready as '
                        'soon as activation lands.',
                        style: TextStyle(color: _muted),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _intents.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final it = _intents[i];
                  final status = (it['status'] ?? 'pending').toString();
                  final canCancel = status == 'pending' || status == 'ready';
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _statusColor(status).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${it['fromToken']} → ${it['toToken']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(
                                  status,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: _statusColor(status),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Amount: ${it['fromAmount']} (raw units)',
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                        if (it['expiresAt'] != null)
                          Text(
                            'Expires: ${it['expiresAt']}',
                            style: const TextStyle(color: _muted, fontSize: 11),
                          ),
                        if (it['lastError'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Last error: ${it['lastError']}',
                              style: const TextStyle(color: _red, fontSize: 11),
                            ),
                          ),
                        if (canCancel)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _cancel(it),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: _red),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
