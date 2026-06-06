import 'dart:async';

import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';

import 'api.dart';

class ReferralCommunityChatSection extends StatefulWidget {
  const ReferralCommunityChatSection({super.key});

  @override
  State<ReferralCommunityChatSection> createState() =>
      _ReferralCommunityChatSectionState();
}

class _ReferralCommunityChatSectionState
    extends State<ReferralCommunityChatSection> {
  final TextEditingController _antCodeController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _pollTimer;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isSavingRoomName = false;
  bool _isClaimingAntCode = false;
  String? _error;
  String _roomName = 'Worker Ants';
  String _roomOwnerLabel = 'Your room';
  String _roomScope = 'my-colony';
  String _accessRole = 'owner';
  String _myAntCode = '';
  int _directReferralCount = 0;
  int _myDirectReferralCount = 0;
  bool _hasUpline = false;
  bool _canClaimAntCode = false;
  List<Map<String, String>> _availableScopes = const [];
  List<String> _roomNameOptions = const [
    'Swarm Ants',
    'Queen Ant',
    'Nurse Ants',
    'Farmer Ants',
    'Builder Ants',
    'Scout Ants',
    'Soldier Ants',
    'Worker Ants',
  ];
  List<Map<String, dynamic>> _messages = const [];

  bool get _isOwner => _accessRole == 'owner';

  @override
  void initState() {
    super.initState();
    // Ads removed (Google AdSense/AdMob ban). Axon ads will be wired in later.
    unawaited(_loadChat(showLoading: true));
    _pollTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _loadChat(),
    );
  }

  Future<void> _loadChat({bool showLoading = false, String? scope}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final requestedScope = scope ?? _roomScope;
      final data = await getReferralCommunityChat(scope: requestedScope);
      final rawMessages = (data['messages'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(item.cast<String, dynamic>()),
          )
          .toList();
      final options = (data['roomNameOptions'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList();
      final availableScopes =
          (data['availableScopes'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map(
                (item) => {
                  'key': item['key']?.toString() ?? '',
                  'label': item['label']?.toString() ?? '',
                },
              )
              .where(
                (item) => item['key']!.isNotEmpty && item['label']!.isNotEmpty,
              )
              .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _roomName = data['roomName']?.toString().trim().isNotEmpty == true
            ? data['roomName'].toString().trim()
            : 'Worker Ants';
        _roomOwnerLabel =
            data['roomOwnerLabel']?.toString().trim().isNotEmpty == true
            ? data['roomOwnerLabel'].toString().trim()
            : 'Your room';
        _roomScope = data['currentScope']?.toString() == 'upline-colony'
            ? 'upline-colony'
            : 'my-colony';
        _accessRole = data['accessRole']?.toString() ?? 'owner';
        _myAntCode = data['myAntCode']?.toString().trim() ?? '';
        _hasUpline = data['hasUpline'] == true;
        _canClaimAntCode = data['canClaimAntCode'] == true;
        _directReferralCount =
            int.tryParse((data['directReferralCount'] ?? 0).toString()) ?? 0;
        _myDirectReferralCount =
            int.tryParse((data['myDirectReferralCount'] ?? 0).toString()) ?? 0;
        if (options.isNotEmpty) {
          _roomNameOptions = options;
        }
        _availableScopes = availableScopes;
        _messages = rawMessages;
        _error = null;
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToBottom();
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) {
      return;
    }

    setState(() {
      _isSending = true;
      _error = null;
    });

    try {
      final data = await sendReferralCommunityMessage(
        message,
        scope: _roomScope,
      );
      final newMessage = Map<String, dynamic>.from(
        (data['message'] as Map).cast<String, dynamic>(),
      );

      if (!mounted) {
        return;
      }

      _messageController.clear();
      setState(() {
        _roomName = data['roomName']?.toString().trim().isNotEmpty == true
            ? data['roomName'].toString().trim()
            : _roomName;
        _roomOwnerLabel =
            data['roomOwnerLabel']?.toString().trim().isNotEmpty == true
            ? data['roomOwnerLabel'].toString().trim()
            : _roomOwnerLabel;
        _roomScope = data['currentScope']?.toString() == 'upline-colony'
            ? 'upline-colony'
            : _roomScope;
        _accessRole = data['accessRole']?.toString() ?? _accessRole;
        _myAntCode = data['myAntCode']?.toString().trim() ?? _myAntCode;
        _hasUpline = data['hasUpline'] == true;
        _canClaimAntCode = data['canClaimAntCode'] == true;
        _directReferralCount =
            int.tryParse((data['directReferralCount'] ?? 0).toString()) ??
            _directReferralCount;
        _myDirectReferralCount =
            int.tryParse((data['myDirectReferralCount'] ?? 0).toString()) ??
            _myDirectReferralCount;
        final availableScopes =
            (data['availableScopes'] as List<dynamic>? ?? const [])
                .whereType<Map>()
                .map(
                  (item) => {
                    'key': item['key']?.toString() ?? '',
                    'label': item['label']?.toString() ?? '',
                  },
                )
                .where(
                  (item) =>
                      item['key']!.isNotEmpty && item['label']!.isNotEmpty,
                )
                .toList();
        if (availableScopes.isNotEmpty) {
          _availableScopes = availableScopes;
        }
        _messages = [..._messages, newMessage];
        _isSending = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToBottom();
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSending = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pickRoomName() async {
    if (!_isOwner || _isSavingRoomName) {
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF0A1220),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context).pickGroupName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ..._roomNameOptions.map(
                (option) => ListTile(
                  leading: Icon(
                    option == _roomName
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: option == _roomName
                        ? const Color(0xFF68D2FF)
                        : Colors.white38,
                  ),
                  title: Text(
                    option,
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () => Navigator.pop(context, option),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );

    if (selected == null || selected == _roomName) {
      return;
    }

    setState(() {
      _isSavingRoomName = true;
      _error = null;
    });

    try {
      final data = await updateReferralCommunityRoomName(
        selected,
        scope: _roomScope,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _roomName = data['roomName']?.toString() ?? selected;
        _roomScope = data['currentScope']?.toString() == 'upline-colony'
            ? 'upline-colony'
            : _roomScope;
        final options = (data['roomNameOptions'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toList();
        if (options.isNotEmpty) {
          _roomNameOptions = options;
        }
        final availableScopes =
            (data['availableScopes'] as List<dynamic>? ?? const [])
                .whereType<Map>()
                .map(
                  (item) => {
                    'key': item['key']?.toString() ?? '',
                    'label': item['label']?.toString() ?? '',
                  },
                )
                .where(
                  (item) =>
                      item['key']!.isNotEmpty && item['label']!.isNotEmpty,
                )
                .toList();
        if (availableScopes.isNotEmpty) {
          _availableScopes = availableScopes;
        }
        _isSavingRoomName = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSavingRoomName = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _claimAntCode() async {
    final antCode = _antCodeController.text.trim().toUpperCase();
    if (antCode.isEmpty || _isClaimingAntCode) {
      return;
    }

    setState(() {
      _isClaimingAntCode = true;
      _error = null;
    });

    try {
      final data = await claimAntCode(antCode, scope: _roomScope);
      final rawMessages = (data['messages'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(item.cast<String, dynamic>()),
          )
          .toList();
      final availableScopes =
          (data['availableScopes'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map(
                (item) => {
                  'key': item['key']?.toString() ?? '',
                  'label': item['label']?.toString() ?? '',
                },
              )
              .where(
                (item) => item['key']!.isNotEmpty && item['label']!.isNotEmpty,
              )
              .toList();

      if (!mounted) {
        return;
      }

      _antCodeController.clear();
      setState(() {
        _roomName = data['roomName']?.toString().trim().isNotEmpty == true
            ? data['roomName'].toString().trim()
            : _roomName;
        _roomOwnerLabel =
            data['roomOwnerLabel']?.toString().trim().isNotEmpty == true
            ? data['roomOwnerLabel'].toString().trim()
            : _roomOwnerLabel;
        _roomScope = data['currentScope']?.toString() == 'upline-colony'
            ? 'upline-colony'
            : _roomScope;
        _accessRole = data['accessRole']?.toString() ?? _accessRole;
        _myAntCode = data['myAntCode']?.toString().trim() ?? _myAntCode;
        _hasUpline = data['hasUpline'] == true;
        _canClaimAntCode = data['canClaimAntCode'] == true;
        _directReferralCount =
            int.tryParse((data['directReferralCount'] ?? 0).toString()) ??
            _directReferralCount;
        _myDirectReferralCount =
            int.tryParse((data['myDirectReferralCount'] ?? 0).toString()) ??
            _myDirectReferralCount;
        if (availableScopes.isNotEmpty) {
          _availableScopes = availableScopes;
        }
        _messages = rawMessages;
        _isClaimingAntCode = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).antCodeLinked)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isClaimingAntCode = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  String _formatTimestamp(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) {
      return 'now';
    }

    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) {
      return 'now';
    }

    final diff = DateTime.now().difference(parsed);
    if (diff.inMinutes < 1) {
      return 'now';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isUplineRoom = _roomScope == 'upline-colony';
    final subtitle = _isOwner
        ? 'You lead this colony with your own Ant Code. No upline is needed. Ants who join with your code enter the colony name you choose.'
        : isUplineRoom
        ? 'You are inside your upline\'s colony and work under the owner\'s selected group name.'
        : 'You are viewing your own colony room even though your permanent upline is already assigned.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0D1D31).withOpacity(0.96),
            const Color(0xFF08111D).withOpacity(0.96),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF55C8FF).withOpacity(0.24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFF55C8FF).withOpacity(0.12),
                ),
                child: const Icon(
                  Icons.forum_rounded,
                  color: Color(0xFF6EDBFF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _roomName,
                      style: const TextStyle(
                        color: Color(0xFFEAF7FF),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF92A9BE),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isOwner)
                IconButton(
                  onPressed: _isSavingRoomName ? null : _pickRoomName,
                  icon: _isSavingRoomName
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF6EDBFF),
                          ),
                        )
                      : const Icon(Icons.edit_rounded),
                  color: const Color(0xFF6EDBFF),
                  tooltip: AppLocalizations.of(context).pickGroupNameTooltip,
                ),
              IconButton(
                onPressed: _isLoading ? null : _loadChat,
                icon: const Icon(Icons.refresh_rounded),
                color: const Color(0xFF6EDBFF),
                tooltip: AppLocalizations.of(context).refreshChatTooltip,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_availableScopes.length > 1) ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _availableScopes.map((scope) {
                final key = scope['key'] ?? '';
                final label = scope['label'] ?? key;
                final selected = key == _roomScope;
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: _isLoading || selected
                      ? null
                      : (_) => _loadChat(showLoading: true, scope: key),
                  labelStyle: TextStyle(
                    color: selected
                        ? const Color(0xFF08111D)
                        : const Color(0xFFEAF7FF),
                    fontWeight: FontWeight.w700,
                  ),
                  selectedColor: const Color(0xFF6EDBFF),
                  backgroundColor: const Color(0xFF0F1A29),
                  side: BorderSide(
                    color: selected
                        ? const Color(0xFF6EDBFF)
                        : Colors.white.withOpacity(0.10),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
          ],
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _statusChip(
                label: 'View',
                value: isUplineRoom ? 'Upline Colony' : 'My Colony',
                color: isUplineRoom
                    ? const Color(0xFFFFC46B)
                    : const Color(0xFF7CFFB3),
              ),
              _statusChip(label: 'Owner', value: _roomOwnerLabel),
              _statusChip(
                label: 'Role',
                value: _isOwner ? 'Queen' : 'Colony Ant',
                color: _isOwner
                    ? const Color(0xFF7CFFB3)
                    : const Color(0xFFFFC46B),
              ),
              _statusChip(
                label: 'Colony ants',
                value: _directReferralCount.toString(),
              ),
              if (_hasUpline && _myDirectReferralCount > 0)
                _statusChip(
                  label: 'My referrals',
                  value: _myDirectReferralCount.toString(),
                ),
              if (_myAntCode.isNotEmpty)
                _statusChip(
                  label: 'My Ant Code',
                  value: _myAntCode,
                  color: const Color(0xFFD3FF78),
                ),
              _statusChip(
                label: 'Messages',
                value: _messages.length.toString(),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (_isLoading)
            const SizedBox(
              height: 220,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF6EDBFF)),
              ),
            )
          else
            _buildChatBody(),
        ],
      ),
    );
  }

  Widget _buildChatBody() {
    return Column(
      children: [
        if (_canClaimAntCode) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFF0F1A29),
              border: Border.all(
                color: const Color(0xFFD3FF78).withOpacity(0.28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).claimPermanentUpline,
                  style: TextStyle(
                    color: Color(0xFFD3FF78),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppLocalizations.of(context).claimUplineInstructions,
                  style: TextStyle(color: Color(0xFF92A9BE), height: 1.35),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _antCodeController,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context).enterAntCode,
                          hintStyle: const TextStyle(color: Color(0xFF6F8396)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.10),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.10),
                            ),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(14)),
                            borderSide: BorderSide(color: Color(0xFFD3FF78)),
                          ),
                        ),
                        onSubmitted: (_) => _claimAntCode(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _isClaimingAntCode ? null : _claimAntCode,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFD3FF78),
                          foregroundColor: const Color(0xFF08111D),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isClaimingAntCode
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF08111D),
                                ),
                              )
                            : Text(AppLocalizations.of(context).claimButton),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        Container(
          height: 300,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.black.withOpacity(0.16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: _messages.isEmpty
              ? Center(
                  child: Text(
                    _isOwner
                        ? AppLocalizations.of(context).noColonyMessage
                        : AppLocalizations.of(context).noColonyMessagesYet,
                    style: const TextStyle(color: Color(0xFF92A9BE)),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  controller: _scrollController,
                  itemCount: _messages.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isMine = message['isMine'] == true;
                    return Align(
                      alignment: isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: isMine
                                ? const Color(0xFF113F5D)
                                : const Color(0xFF111927),
                            border: Border.all(
                              color: isMine
                                  ? const Color(0xFF53C7FF).withOpacity(0.24)
                                  : Colors.white.withOpacity(0.08),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      isMine
                                          ? 'You'
                                          : (message['senderLabel']
                                                    ?.toString() ??
                                                'Member'),
                                      style: TextStyle(
                                        color: isMine
                                            ? const Color(0xFF8CE7FF)
                                            : const Color(0xFFFFC46B),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _formatTimestamp(message['createdAt']),
                                    style: const TextStyle(
                                      color: Color(0xFF7E91A5),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                message['text']?.toString() ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        // Banner ad block removed (Google AdSense/AdMob ban).
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: _isOwner
                      ? AppLocalizations.of(context).writeToColony
                      : AppLocalizations.of(context).writeToUplines,
                  hintStyle: const TextStyle(color: Color(0xFF6F8396)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.10),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.10),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF53C7FF)),
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _isSending ? null : _sendMessage,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1792D0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statusChip({
    required String label,
    required String value,
    Color color = const Color(0xFF6EDBFF),
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withOpacity(0.10),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontFamily: 'Roboto'),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: Color(0xFF92A9BE), fontSize: 12),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _antCodeController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
