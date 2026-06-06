import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'username_registry_service.dart';

class PublicNftProfilePage extends StatefulWidget {
  const PublicNftProfilePage({super.key, required this.walletAddress});

  final String walletAddress;

  @override
  State<PublicNftProfilePage> createState() => _PublicNftProfilePageState();
}

class _PublicNftProfilePageState extends State<PublicNftProfilePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _profile;
  String? _primaryUsername;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _loadProfile();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _stringValue(dynamic value, [String fallback = '']) {
    final raw = value == null ? '' : value.toString().trim();
    return raw.isEmpty ? fallback : raw;
  }

  bool _boolValue(dynamic value, [bool fallback = false]) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return fallback;
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _profile = null;
    });

    try {
      final profile = await getPublicNftProfileAPI(widget.walletAddress);
      if (mounted) {
        setState(() {
          _profile = profile;
          _loading = false;
        });
        // Reverse-resolve on-chain @username from migration (EVM) wallet.
        final mw = (profile['migrationWalletAddress'] ?? '').toString().trim();
        if (mw.isNotEmpty && RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(mw)) {
          usernameRegistry
              .reverseResolve(mw)
              .then((name) {
                if (mounted && name != null && name.isNotEmpty) {
                  setState(() => _primaryUsername = name);
                }
              })
              .catchError((_) {});
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _copyWallet() async {
    await Clipboard.setData(ClipboardData(text: widget.walletAddress));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Wallet address copied')));
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? _errorView()
        : _profileView();

    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF07111F),
        elevation: 0,
        title: const Text('NFT Identity'),
        actions: [
          IconButton(
            tooltip: 'Copy wallet',
            onPressed: _copyWallet,
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF091224), Color(0xFF050A14)],
            ),
          ),
          child: RefreshIndicator(
            onRefresh: _loadProfile,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: body,
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _sectionCard(
          title: 'Profile not available',
          child: Text(
            _error ?? 'Unknown error',
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _loadProfile,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ),
      ],
    );
  }

  Widget _profileView() {
    final profile = _profile;
    if (profile == null) {
      return const Center(child: Text('No profile data'));
    }

    final status = _stringValue(profile['status']);
    if (status == 'locked') {
      return _lockedView(profile);
    }

    final colonyCode = _stringValue(profile['colonyCode']);
    final profileData = profile['profile'] as Map<String, dynamic>?;
    final stats = profile['stats'] as Map<String, dynamic>?;
    final verification = profile['verification'] as Map<String, dynamic>?;

    final name = _stringValue(profileData?['name'], 'A-Network Identity');
    final poweredBy = _stringValue(profileData?['poweredBy'], 'A Network');
    final avatarUrl = _stringValue(profileData?['avatarUrl']);
    final styling = profileData?['styling'] as Map<String, dynamic>? ?? {};
    final primaryColor = _parseColor(
      _stringValue(styling['primaryColor'], '#00D2FF'),
      const Color(0xFF00D2FF),
    );
    final secondaryColor = _parseColor(
      _stringValue(styling['secondaryColor'], '#8A3FFC'),
      const Color(0xFF8A3FFC),
    );
    final glowColor = _parseColor(
      _stringValue(styling['glowColor'], '#FFFFFF'),
      Colors.white,
    );
    const backgroundColor = Color(0xFF081126);

    final completedSessions =
        (stats?['completedSessions'] as num?)?.toInt() ?? 0;
    final requiredSessions =
        (stats?['requiredSessions'] as num?)?.toInt() ?? 1000;
    final settlementCount = (stats?['settlementCount'] as num?)?.toInt() ?? 0;
    final rank = (stats?['rank'] as num?)?.toInt() ?? 999;

    final profileId = verification?['profileId'];
    final createdAt = _stringValue(verification?['createdAt']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final pulse = 0.96 + (_pulseController.value * 0.04);
            return Transform.scale(
              scale: pulse,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primaryColor.withValues(alpha: 0.95),
                      secondaryColor.withValues(alpha: 0.88),
                      backgroundColor,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: glowColor.withValues(alpha: 0.25),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withValues(alpha: 0.18),
                      blurRadius: 32,
                      spreadRadius: 2,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            colonyCode,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF0FD18F,
                            ).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'VERIFIED',
                            style: TextStyle(
                              color: Color(0xFF9CFFDB),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: glowColor.withValues(alpha: 0.2),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: avatarUrl.isNotEmpty
                                ? Image.network(
                                    avatarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                              Icons.person_rounded,
                                              color: Colors.white,
                                              size: 36,
                                            ),
                                  )
                                : const Icon(
                                    Icons.person_rounded,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if ((_primaryUsername ?? '').isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF25C474,
                                    ).withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF25C474,
                                      ).withValues(alpha: 0.45),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '@$_primaryUsername',
                                        style: const TextStyle(
                                          color: Color(0xFF9CFFDB),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.verified_rounded,
                                        color: Color(0xFF9CFFDB),
                                        size: 12,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                poweredBy,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _chip('Rank #$rank'),
                                  _chip('$completedSessions sessions'),
                                  _chip(
                                    settlementCount > 0 ? 'Settled' : 'Pending',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Primary',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _stringValue(styling['primaryColor']),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Secondary',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _stringValue(styling['secondaryColor']),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'On-Chain Stats',
          child: Column(
            children: [
              _statRow(
                'Completed Sessions',
                '$completedSessions / $requiredSessions',
              ),
              const SizedBox(height: 10),
              _statRow('Settlement Events', '$settlementCount'),
              const SizedBox(height: 10),
              _statRow('Rank', '#$rank'),
              if (createdAt.isNotEmpty) ...[
                const SizedBox(height: 10),
                _statRow('Profile Created', createdAt),
              ],
              if (profileId != null) ...[
                const SizedBox(height: 10),
                _statRow('Profile ID', profileId.toString()),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Verification',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF9CFFDB),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'On-chain identity verified',
                    style: TextStyle(
                      color: Color(0xFF9CFFDB),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'This NFT identity is linked to settlement history and publicly verifiable on the A-Network L1 explorer.',
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _lockedView(Map<String, dynamic> profile) {
    final refCode = _stringValue(profile['refCode']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _sectionCard(
          title: 'Identity Locked',
          child: Text(
            'This miner has not yet unlocked NFT identity. They must complete 1,000 mining sessions and record their first settlement event to unlock.',
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Referral Code',
          child: Column(
            children: [
              SelectableText(
                refCode,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Share this code to invite others to join the colony.',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _parseColor(String input, Color fallback) {
    final raw = input.trim();
    if (raw.isEmpty) return fallback;
    final normalized = raw.startsWith('#') ? raw.substring(1) : raw;
    if (normalized.length == 6) {
      final value = int.tryParse('FF$normalized', radix: 16);
      if (value != null) return Color(value);
    }
    if (normalized.length == 8) {
      final value = int.tryParse(normalized, radix: 16);
      if (value != null) return Color(value);
    }
    return fallback;
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        SelectableText(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D162B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
