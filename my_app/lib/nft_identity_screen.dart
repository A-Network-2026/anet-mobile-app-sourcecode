import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'username_registry_service.dart';

class NftIdentityScreen extends StatefulWidget {
  const NftIdentityScreen({
    super.key,
    required this.walletAddress,
    required this.completedSessions,
    required this.sessionGateBypassEnabled,
  });

  final String walletAddress;
  final int completedSessions;
  final bool sessionGateBypassEnabled;

  @override
  State<NftIdentityScreen> createState() => _NftIdentityScreenState();
}

class _NftIdentityScreenState extends State<NftIdentityScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _poweredByController = TextEditingController();
  final TextEditingController _primaryColorController = TextEditingController();
  final TextEditingController _secondaryColorController =
      TextEditingController();
  final TextEditingController _glowColorController = TextEditingController();
  final TextEditingController _backgroundStyleController =
      TextEditingController();
  final TextEditingController _frameStyleController = TextEditingController();
  final TextEditingController _hologramController = TextEditingController();
  final TextEditingController _taglineController = TextEditingController();
  final TextEditingController _badgeController = TextEditingController();

  late final AnimationController _pulseController;

  bool _loading = true;
  bool _saving = false;
  bool _useAsAvatar = true;
  String? _error;
  Map<String, dynamic>? _status;
  String? _primaryUsername;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _loadStatus();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _nameController.dispose();
    _poweredByController.dispose();
    _primaryColorController.dispose();
    _secondaryColorController.dispose();
    _glowColorController.dispose();
    _backgroundStyleController.dispose();
    _frameStyleController.dispose();
    _hologramController.dispose();
    _taglineController.dispose();
    _badgeController.dispose();
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

  double _doubleValue(dynamic value, [double fallback = 0.75]) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(_stringValue(value));
    if (parsed == null || parsed.isNaN || parsed.isInfinite) {
      return fallback;
    }
    return parsed.clamp(0.0, 1.0);
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

  Map<String, dynamic>? get _profile =>
      _status?['profile'] as Map<String, dynamic>?;

  bool get _eligible =>
      _boolValue(_status?['nftActivated']) ||
      _stringValue(_status?['identityState']) == 'NFT_ACTIVATED';

  String get _identityState =>
      _stringValue(_status?['identityState'], 'MINER_ONLY');

  Future<void> _loadStatus() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final status = await getWalletNftStatusAPI();
      final profile = status['profile'] as Map<String, dynamic>?;
      _status = status;
      _populateControllers(profile);
      final avatarType = _stringValue(status['avatarType']);
      _useAsAvatar = avatarType == 'nft'
          ? true
          : avatarType == 'default'
          ? false
          : _boolValue(profile?['profile_active'], true);
      // Reverse-resolve on-chain @username from the migration (EVM) wallet.
      final mw = _stringValue(status['migrationWalletAddress']);
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
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _populateControllers(Map<String, dynamic>? profile) {
    final fallbackName = _stringValue(
      profile?['nft_name'],
      'A-Network Identity',
    );
    final fallbackPoweredBy = _stringValue(profile?['powered_by'], 'A Network');
    final fallbackPrimary = _stringValue(profile?['primary_color'], '#00D2FF');
    final fallbackSecondary = _stringValue(
      profile?['secondary_color'],
      '#8A3FFC',
    );
    final fallbackGlow = _stringValue(profile?['glow_color'], '#FFFFFF');
    final fallbackBackground = _stringValue(
      profile?['background_style'],
      'cyberpunk',
    );
    final fallbackFrame = _stringValue(profile?['frame_style'], 'chrome');
    final fallbackHologram = _doubleValue(
      profile?['hologram_level'],
      0.75,
    ).toStringAsFixed(2);

    final metadataJson = profile?['metadata_json'];
    final metadataMap = metadataJson is Map
        ? Map<String, dynamic>.from(metadataJson)
        : <String, dynamic>{};

    _nameController.text = fallbackName;
    _poweredByController.text = fallbackPoweredBy;
    _primaryColorController.text = fallbackPrimary;
    _secondaryColorController.text = fallbackSecondary;
    _glowColorController.text = fallbackGlow;
    _backgroundStyleController.text = fallbackBackground;
    _frameStyleController.text = fallbackFrame;
    _hologramController.text = fallbackHologram;
    _taglineController.text = _stringValue(
      metadataMap['tagline'],
      'Protocol-gated identity',
    );
    _badgeController.text = _stringValue(metadataMap['badge'], 'Miner-Proof');
  }

  Future<void> _copyWallet() async {
    await Clipboard.setData(ClipboardData(text: widget.walletAddress));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Wallet address copied')));
  }

  Future<void> _saveProfile() async {
    if (!_eligible) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final payloadMetadata = <String, dynamic>{
        'tagline': _taglineController.text.trim(),
        'badge': _badgeController.text.trim(),
        'walletAddress': widget.walletAddress,
        'completedSessions': _status?['completedSessions'],
        'identityState': _status?['identityState'],
        'rank': _status?['rank'],
        'colonyCode': _status?['colonyCode'],
      };

      final profileExists = _profile != null;
      final result = profileExists
          ? await updateWalletNftProfileAPI(
              nftName: _nameController.text.trim(),
              poweredBy: _poweredByController.text.trim(),
              primaryColor: _primaryColorController.text.trim(),
              secondaryColor: _secondaryColorController.text.trim(),
              glowColor: _glowColorController.text.trim(),
              backgroundStyle: _backgroundStyleController.text.trim(),
              frameStyle: _frameStyleController.text.trim(),
              hologramLevel: double.parse(_hologramController.text.trim()),
              useAsAvatar: _useAsAvatar,
              metadata: payloadMetadata,
            )
          : await createWalletNftProfileAPI(
              nftName: _nameController.text.trim(),
              poweredBy: _poweredByController.text.trim(),
              primaryColor: _primaryColorController.text.trim(),
              secondaryColor: _secondaryColorController.text.trim(),
              glowColor: _glowColorController.text.trim(),
              backgroundStyle: _backgroundStyleController.text.trim(),
              frameStyle: _frameStyleController.text.trim(),
              hologramLevel: double.parse(_hologramController.text.trim()),
              useAsAvatar: _useAsAvatar,
              metadata: payloadMetadata,
            );

      _status = result['status'] as Map<String, dynamic>? ?? _status;
      final profile = result['profile'] as Map<String, dynamic>?;
      if (profile != null) {
        _status = {...?_status, 'profile': profile};
      }
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['created'] == true
                  ? 'NFT identity created'
                  : 'NFT identity updated',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _shareProfile() async {
    final walletAddress = _stringValue(
      _status?['walletAddress'],
      widget.walletAddress,
    );
    if (walletAddress.isEmpty) {
      return;
    }

    final profileUrl =
        'https://a-network.net/profile.html?wallet=$walletAddress';
    final subject = _stringValue(_status?['colonyCode'], 'ANET');
    final text = 'Check out my A-Network NFT identity: $subject\n\n$profileUrl';

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile link copied to clipboard')),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    String? hint,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: const Color(0xFF101A33),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF00D2FF), width: 1.2),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final profile = _profile;
    final primary = _parseColor(
      _primaryColorController.text,
      const Color(0xFF00D2FF),
    );
    final secondary = _parseColor(
      _secondaryColorController.text,
      const Color(0xFF8A3FFC),
    );
    final glow = _parseColor(_glowColorController.text, Colors.white);
    final rank = (_status?['rank'] as num?)?.toInt() ?? 999;
    final colonyCode = _stringValue(_status?['colonyCode'], 'ANET1');
    final avatarUrl = _stringValue(
      profile?['avatar_thumb_url'] ??
          profile?['avatar_image_url'] ??
          _status?['avatarUrl'] ??
          _status?['activationUrl'],
      '',
    );
    final wallet = _stringValue(
      _status?['walletAddress'],
      widget.walletAddress,
    );
    final completedSessions =
        (_status?['completedSessions'] as num?)?.toInt() ??
        widget.completedSessions;
    final firstSettlementAt = _stringValue(_status?['firstSettlementAt']);

    return AnimatedBuilder(
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
                  primary.withOpacity(0.95),
                  secondary.withOpacity(0.88),
                  const Color(0xFF081126),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: glow.withOpacity(0.25), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: glow.withOpacity(0.18),
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
                        color: Colors.black.withOpacity(0.22),
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
                        color: _eligible
                            ? const Color(0xFF0FD18F).withOpacity(0.18)
                            : Colors.orangeAccent.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _identityState,
                        style: TextStyle(
                          color: _eligible
                              ? const Color(0xFF9CFFDB)
                              : Colors.orangeAccent,
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
                          color: Colors.white.withOpacity(0.18),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: glow.withOpacity(0.2),
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
                                errorBuilder: (context, error, stackTrace) =>
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
                            _nameController.text.trim().isEmpty
                                ? 'A-Network Identity'
                                : _nameController.text.trim(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if ((_primaryUsername ?? '').isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF25C474,
                                    ).withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF25C474,
                                      ).withOpacity(0.45),
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
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            _poweredByController.text.trim().isEmpty
                                ? 'Powered by A Network'
                                : _poweredByController.text.trim(),
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
                                _boolValue(_status?['hasSettlement'])
                                    ? 'Settled'
                                    : 'Pending settlement',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  _taglineController.text.trim().isEmpty
                      ? 'Protocol-gated identity'
                      : _taglineController.text.trim(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Wallet $wallet',
                  style: TextStyle(color: Colors.white.withOpacity(0.84)),
                ),
                if (firstSettlementAt.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'First settlement: $firstSettlementAt',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.74),
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _buildRarityAndPerks(rank, primary, glow, wallet),
              ],
            ),
          ),
        );
      },
    );
  }

  ({String label, Color color, String icon}) _rarityFor(int rank) {
    if (rank <= 10) {
      return (label: 'LEGENDARY', color: const Color(0xFFFFB800), icon: '🏆');
    }
    if (rank <= 100) {
      return (label: 'EPIC', color: const Color(0xFF8A3FFC), icon: '💎');
    }
    if (rank <= 1000) {
      return (label: 'RARE', color: const Color(0xFF00D2FF), icon: '⭐');
    }
    return (label: 'STANDARD', color: const Color(0xFF7B829A), icon: '◆');
  }

  List<String> get _passportPerks => const [
    '0.5% swap fee discount',
    'Priority colony rewards',
    'Verified on-chain @username',
    'Bridge access (1k sessions)',
  ];

  Future<void> _sharePassport(String wallet) async {
    final handle = (_primaryUsername ?? '').isNotEmpty
        ? _primaryUsername!
        : wallet;
    final link = 'https://anetwork.app/u/$handle';
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Passport link copied: $link'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0FD18F),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _verifyOnChain(String wallet) async {
    if (wallet.isEmpty) return;
    // ANET L1 addresses are not valid on BscScan — route them to the A-Network
    // explorer. The explorer doesn't expose an /address/<wallet> route yet, so
    // we open the explorer root and copy the wallet to clipboard so the user
    // can paste it into the explorer's search.
    final isAnetL1 = wallet.toUpperCase().startsWith('ANET');
    final uri = isAnetL1
        ? Uri.parse('https://explorer.a-network.net/explorer')
        : Uri.parse('https://bscscan.com/address/$wallet');
    if (isAnetL1) {
      await Clipboard.setData(ClipboardData(text: wallet));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wallet copied — paste into the explorer search'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  /// Shows the passport QR full-screen so it scans easily from a phone held
  /// across a table. Triggered by tapping the small QR thumbnail on the card.
  void _showFullscreenQr(String qrData, String wallet, Color glow) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) {
        final shortWallet = wallet.length > 12
            ? '${wallet.substring(0, 6)}…${wallet.substring(wallet.length - 4)}'
            : wallet;
        return Dialog(
          backgroundColor: const Color(0xFF0B1424),
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if ((_primaryUsername ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '@${_primaryUsername!}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: glow.withOpacity(0.35),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 280,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF07111F),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF07111F),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  shortWallet,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close, color: Colors.white70),
                  label: const Text(
                    'Tap to close',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRarityAndPerks(
    int rank,
    Color primary,
    Color glow,
    String wallet,
  ) {
    final rarity = _rarityFor(rank);
    final qrData = wallet.isNotEmpty ? wallet : widget.walletAddress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rarity badge row
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: rarity.color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: rarity.color.withOpacity(0.6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(rarity.icon, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 5),
                  Text(
                    rarity.label,
                    style: TextStyle(
                      color: rarity.color,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => _verifyOnChain(wallet),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFF25C474).withOpacity(0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_outlined,
                      color: Color(0xFF9CFFDB),
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      wallet.toUpperCase().startsWith('ANET')
                          ? 'Verify on ANET'
                          : 'Verify on BscScan',
                      style: const TextStyle(
                        color: Color(0xFF9CFFDB),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // QR + Perks row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => _showFullscreenQr(qrData, wallet, glow),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: glow.withOpacity(0.25),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 96,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF07111F),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF07111F),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(2),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF07111F),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.zoom_in,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Passport perks',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ..._passportPerks.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF9CFFDB),
                            size: 13,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              p,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.88),
                                fontSize: 11,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _sharePassport(wallet),
            icon: const Icon(Icons.ios_share_rounded, size: 16),
            label: const Text('Share Passport'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.14),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
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

  @override
  Widget build(BuildContext context) {
    final profileExists = _profile != null;
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? _errorView()
        : _eligible
        ? _editorView(profileExists)
        : _lockedView();

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
            onRefresh: _loadStatus,
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
          title: 'Status unavailable',
          child: Text(
            _error ?? 'Unknown error',
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _loadStatus,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ),
      ],
    );
  }

  Widget _lockedView() {
    final requiredSessions =
        (_status?['requiredSessions'] as num?)?.toInt() ?? 1000;
    final completedSessions =
        (_status?['completedSessions'] as num?)?.toInt() ??
        widget.completedSessions;
    final hasSettlement = _boolValue(_status?['hasSettlement']);
    final settlementCopy = hasSettlement
        ? 'Your first settlement event is recorded and the NFT identity is ready.'
        : 'Complete at least one successful settlement event after your mining lifecycle to unlock identity creation.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Protocol locked',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NFT identity unlocks after $requiredSessions completed sessions and the first successful settlement event.',
                style: const TextStyle(color: Colors.white70, height: 1.45),
              ),
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: math.min(1.0, completedSessions / requiredSessions),
                backgroundColor: Colors.white.withOpacity(0.08),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF00D2FF),
                ),
                minHeight: 10,
              ),
              const SizedBox(height: 10),
              Text(
                '$completedSessions / $requiredSessions sessions',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                settlementCopy,
                style: const TextStyle(color: Colors.white60, height: 1.35),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _miniStat('State', _identityState)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _miniStat(
                      'Settlement',
                      hasSettlement ? 'Ready' : 'Pending',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildPreview(),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'What to do next',
          child: const Text(
            'Return here after your first completed settlement event. The identity profile, avatar, and public NFT fields will unlock automatically.',
            style: TextStyle(color: Colors.white70, height: 1.45),
          ),
        ),
      ],
    );
  }

  Widget _miniStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF101A33),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _editorView(bool profileExists) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _buildPreview(),
          const SizedBox(height: 16),
          _sectionCard(
            title: profileExists ? 'Update identity' : 'Create identity',
            child: Column(
              children: [
                _buildField(
                  'Identity name',
                  _nameController,
                  hint: 'ANET1 Prime',
                  validator: (value) {
                    if (value == null || value.trim().length < 3) {
                      return 'Enter at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _buildField(
                  'Powered by',
                  _poweredByController,
                  hint: 'A Network',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Powered by text is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        'Primary color',
                        _primaryColorController,
                        hint: '#00D2FF',
                        validator: (value) {
                          if (!RegExp(
                            r'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$',
                          ).hasMatch((value ?? '').trim())) {
                            return 'Use hex color';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildField(
                        'Secondary color',
                        _secondaryColorController,
                        hint: '#8A3FFC',
                        validator: (value) {
                          if (!RegExp(
                            r'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$',
                          ).hasMatch((value ?? '').trim())) {
                            return 'Use hex color';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        'Glow color',
                        _glowColorController,
                        hint: '#FFFFFF',
                        validator: (value) {
                          if (!RegExp(
                            r'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$',
                          ).hasMatch((value ?? '').trim())) {
                            return 'Use hex color';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildField(
                        'Hologram level',
                        _hologramController,
                        hint: '0.75',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          final parsed = double.tryParse((value ?? '').trim());
                          if (parsed == null || parsed < 0 || parsed > 1) {
                            return '0.0 - 1.0';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        'Background style',
                        _backgroundStyleController,
                        hint: 'cyberpunk',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildField(
                        'Frame style',
                        _frameStyleController,
                        hint: 'chrome',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildField(
                  'Tagline',
                  _taglineController,
                  hint: 'Protocol-gated identity',
                ),
                const SizedBox(height: 12),
                _buildField('Badge', _badgeController, hint: 'Miner-Proof'),
                const SizedBox(height: 4),
                SwitchListTile.adaptive(
                  value: _useAsAvatar,
                  onChanged: (value) {
                    setState(() {
                      _useAsAvatar = value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Use as global avatar',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Propagate this NFT identity avatar across the wallet and profile surfaces.',
                    style: TextStyle(color: Colors.white60),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _saveProfile,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          profileExists
                              ? Icons.save_rounded
                              : Icons.auto_fix_high_rounded,
                        ),
                  label: Text(
                    profileExists
                        ? 'Update NFT identity'
                        : 'Create NFT identity',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (_eligible && _profile != null)
                ElevatedButton.icon(
                  onPressed: _shareProfile,
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.1),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D162B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
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
