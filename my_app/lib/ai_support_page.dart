import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';
import 'l10n/app_localizations.dart';

import 'ads_service.dart';
import 'api.dart';

class AiSupportPage extends StatefulWidget {
  const AiSupportPage({
    super.key,
    this.migrationWallet,
    this.loginWithAds = false,
  });

  final String? migrationWallet;
  final bool loginWithAds;

  @override
  State<AiSupportPage> createState() => _AiSupportPageState();
}

class _AiSupportPageState extends State<AiSupportPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_AiBubble> _messages = <_AiBubble>[];
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _booting = true;
  bool _sending = false;
  bool _deepResearchMode = false;
  bool _listening = false;
  bool _speaking = false;
  bool _voiceConfigured = false;
  bool _aiEnabled = true;
  String? _error;
  String? _notice;
  String? _conversationId;

  static const int _maxAiTokensBase = 20;
  static const int _messageCostTokens = 1;
  static const int _adRewardTokens = 8;
  static const int _scheduledRefillTokens = 1;
  static const Duration _tokenRefillInterval = Duration(minutes: 5);
  static const String _tokenBalanceKey = 'ai.token.balance';
  static const String _tokenNextRefillMsKey = 'ai.token.next_refill_ms';
  static const String _chatHistoryKey = 'ai.chat.history';
  static const int _chatHistoryMaxMessages = 100;

  int _aiTokens = _maxAiTokensBase;
  DateTime? _nextTokenRefillAt;

  Future<void> _showComingSoon(String feature) async {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature coming soon')));
  }

  Future<void> _showTrainDialog() async {
    final knowledgeCtrl = TextEditingController();
    final promptCtrl = TextEditingController();
    final idealCtrl = TextEditingController();
    bool saving = false;
    String error = '';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          backgroundColor: const Color(0xFF0A1224),
          title: Text(
            AppLocalizations.of(context).trainAITitle,
            style: TextStyle(color: Colors.cyanAccent),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: knowledgeCtrl,
                  style: const TextStyle(color: Colors.white),
                  minLines: 2,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).knowledgeHint,
                    hintStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: promptCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(
                      context,
                    ).optionalTrainingPrompt,
                    hintStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: idealCtrl,
                  style: const TextStyle(color: Colors.white),
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(
                      context,
                    ).optionalIdealResponse,
                    hintStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                if (error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      error,
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: Text(
                AppLocalizations.of(context).cancelButton,
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: saving
                  ? null
                  : () async {
                      final l10n = AppLocalizations.of(this.context);
                      final knowledge = knowledgeCtrl.text.trim();
                      final prompt = promptCtrl.text.trim();
                      final ideal = idealCtrl.text.trim();

                      if (knowledge.isEmpty &&
                          (prompt.isEmpty || ideal.isEmpty)) {
                        setLocalState(() {
                          error = AppLocalizations.of(context).addMemoryOrBoth;
                        });
                        return;
                      }

                      setLocalState(() {
                        saving = true;
                        error = '';
                      });

                      try {
                        if (knowledge.isNotEmpty) {
                          await addAiMemoryText(
                            knowledge,
                            sourceType: 'user_training',
                          );
                        }
                        if (prompt.isNotEmpty && ideal.isNotEmpty) {
                          await addAiTrainingExample(prompt, ideal);
                        }
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(content: Text(l10n.aiTrainingSaved)),
                          );
                        }
                      } catch (e) {
                        setLocalState(() {
                          saving = false;
                          error = e.toString().replaceFirst('Exception: ', '');
                        });
                      }
                    },
              child: Text(
                saving
                    ? '${AppLocalizations.of(context).saveButton}...'
                    : AppLocalizations.of(context).saveButton,
                style: const TextStyle(color: Colors.cyanAccent),
              ),
            ),
          ],
        ),
      ),
    );

    knowledgeCtrl.dispose();
    promptCtrl.dispose();
    idealCtrl.dispose();
  }

  @override
  void initState() {
    super.initState();
    _boot();
    // Initialize TTS in background after 3 seconds to prevent ANR
    // DO NOT await this on main thread
    unawaited(_initializeTtsInBackground());
  }

  Future<void> _initializeTtsInBackground() async {
    try {
      // Defer TTS init 5+ seconds to keep main thread free for UI rendering.
      // Play Console ANR: FlutterTtsPlugin.isLanguageAvailable -> Slow Binder call.
      // On low-end devices the system TTS service binder can stall for several
      // seconds on first contact, so we keep TTS off the cold-start path and
      // run each native hop sequentially with a short timeout.
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;

      // Set TTS parameters with timeout safety - never block on these.
      // Sequential, not Future.wait, so a stuck Binder on one call cannot
      // hold the platform thread queue for the other.
      await _tts
          .setSpeechRate(0.46)
          .timeout(const Duration(milliseconds: 800), onTimeout: () {});
      if (!mounted) return;
      await _tts
          .setPitch(1.0)
          .timeout(const Duration(milliseconds: 800), onTimeout: () {});

      if (!mounted) return;
      _voiceConfigured = true;

      // Register TTS handlers safely
      _tts.setCompletionHandler(() {
        if (mounted) {
          setState(() {
            _speaking = false;
          });
        }
      });

      _tts.setCancelHandler(() {
        if (mounted) {
          setState(() {
            _speaking = false;
          });
        }
      });
    } catch (_) {
      // Silent fail: TTS is best-effort only
      // Do not propagate errors or block voice chat
      if (mounted) {
        _voiceConfigured = true; // Mark as attempted to avoid repeated tries
      }
    }
  }

  Future<void> _ensureVoiceConfigured() async {
    // TTS is now deferred to background; this is a no-op safety check
    // Voice will be ready after ~3 seconds from page load
    if (_voiceConfigured) {
      return;
    }
    // Give background initialization a chance to complete
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _boot() async {
    try {
      await loadSession();
      final hasAiSupport = await ensureAiSession(
        migrationWallet: widget.migrationWallet,
      );
      if (!hasAiSupport) {
        _aiEnabled = false;
        _notice =
            'AI support is not enabled in this build yet. Build with AI_SUPPORT_TOKEN to activate chat.';
      }
      if (hasAiSupport) {
        await getAiOwnerProfile();
        await ensureAiLanguageDefaults();
      }
      await _loadAndRefreshTokens();
      if (hasAiSupport) {
        await _syncAiTokensFromServer();
      }
      if (!AdsService.adsEnabled) {
        await AdsService.enableRuntime();
      }
      unawaited(AdsService.loadAiTokenRewardedAd());
      await _loadChatHistory();
      if (!mounted) {
        return;
      }
      setState(() {
        _booting = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _booting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadAndRefreshTokens() async {
    final prefs = await SharedPreferences.getInstance();
    var balance = prefs.getInt(_tokenBalanceKey) ?? _maxAiTokensBase;
    final nextMs = prefs.getInt(_tokenNextRefillMsKey);
    DateTime? refillAt = nextMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(nextMs);
    final now = DateTime.now();

    refillAt ??= now.add(_tokenRefillInterval);

    while (!refillAt!.isAfter(now) && balance < _maxAiTokensBase) {
      balance = (balance + _scheduledRefillTokens).clamp(0, _maxAiTokensBase);
      refillAt = refillAt.add(_tokenRefillInterval);
    }

    if (balance >= _maxAiTokensBase) {
      refillAt = now.add(_tokenRefillInterval);
    }

    balance = balance < 0 ? 0 : balance;
    _aiTokens = balance;
    _nextTokenRefillAt = refillAt;
    await _saveTokenState();
  }

  Future<void> _saveTokenState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_tokenBalanceKey, _aiTokens);
    await prefs.setInt(
      _tokenNextRefillMsKey,
      (_nextTokenRefillAt ?? DateTime.now().add(_tokenRefillInterval))
          .millisecondsSinceEpoch,
    );
  }

  // ── Chat history persistence ─────────────────────────────────────────────

  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_chatHistoryKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final loaded = list
          .map(
            (m) => _AiBubble(
              role: m['role'] as String,
              text: m['text'] as String,
              citations: (m['citations'] as List? ?? []).cast<String>(),
              isResearch: m['isResearch'] as bool? ?? false,
            ),
          )
          .toList();
      if (mounted) {
        setState(() {
          _messages.addAll(loaded);
        });
      }
    } catch (_) {
      // Corrupted history — silently ignore and start fresh.
    }
  }

  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final capped = _messages.length > _chatHistoryMaxMessages
        ? _messages.sublist(_messages.length - _chatHistoryMaxMessages)
        : _messages;
    final encoded = jsonEncode(
      capped
          .map(
            (m) => {
              'role': m.role,
              'text': m.text,
              'citations': m.citations,
              'isResearch': m.isResearch,
            },
          )
          .toList(),
    );
    await prefs.setString(_chatHistoryKey, encoded);
  }

  // ── Safety helpers ────────────────────────────────────────────────────────

  /// Returns true if the text appears to mention a person's name
  /// (two or more consecutive capitalized words mid-sentence).
  bool _containsPersonName(String text) {
    final namePattern = RegExp(r'\b[A-Z][a-z]{1,}(?:\s[A-Z][a-z]{1,})+\b');
    return namePattern.hasMatch(text);
  }

  /// Returns true if the text contains keywords associated with harmful intent.
  bool _containsHarmfulIntent(String text) {
    final lower = text.toLowerCase();
    const triggers = [
      'kill',
      'murder',
      'bomb',
      'attack',
      'weapon',
      'gun',
      'shoot',
      'hack',
      'exploit',
      'steal',
      'fraud',
      'scam',
      'phish',
      'abuse',
      'threaten',
      'harass',
      'suicide',
      'self-harm',
    ];
    return triggers.any(lower.contains);
  }

  Future<void> _claimAdTokens() async {
    await loadSession();

    if (!AdsService.adsEnabled) {
      await AdsService.enableRuntime();
    }

    await AdsService.loadAiTokenRewardedAd();
    var earned = await AdsService.showAiTokenRewardedBestEffort(
      userId: currentUserId,
    );

    // One graceful retry when the SDK returns transient internal errors.
    if (!earned) {
      final loadError = (AdsService.lastAiTokenRewardedLoadError ?? '')
          .toLowerCase();
      if (loadError.contains('internal error')) {
        await Future.delayed(const Duration(milliseconds: 600));
        await AdsService.loadAiTokenRewardedAd();
        earned = await AdsService.showAiTokenRewardedBestEffort(
          userId: currentUserId,
        );
      }
    }

    if (!mounted) {
      return;
    }

    if (!earned) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context).adNotCompleted} Please try again.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _aiTokens += _adRewardTokens;
      _nextTokenRefillAt ??= DateTime.now().add(_tokenRefillInterval);
    });
    await _saveTokenState();
    unawaited(_syncAiTokensFromServerWithRetry());

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(
            context,
          ).aiTokensAdded(_adRewardTokens.toString(), _aiTokens.toString()),
        ),
      ),
    );
  }

  Future<void> _syncAiTokensFromServer({bool hardSync = false}) async {
    try {
      final profile = await getAiProfile();
      final serverBalance = int.tryParse(
        (profile['ai_token_balance'] ?? '').toString(),
      );
      if (serverBalance == null || serverBalance < 0) {
        return;
      }

      if (!mounted) {
        _aiTokens = serverBalance;
        await _saveTokenState();
        return;
      }

      final nextBalance = hardSync
          ? serverBalance
          : (_aiTokens > serverBalance ? _aiTokens : serverBalance);
      if (nextBalance == _aiTokens) {
        return;
      }

      setState(() {
        _aiTokens = nextBalance;
      });
      await _saveTokenState();
    } catch (_) {
      // Best effort only; UI can continue using local balance temporarily.
    }
  }

  Future<void> _syncAiTokensFromServerWithRetry() async {
    for (var i = 0; i < 6; i++) {
      await _syncAiTokensFromServer();
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) {
      return;
    }

    if (!_aiEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _notice ??
                  'AI session is not ready yet. Please try again shortly.',
            ),
          ),
        );
      }
      return;
    }

    try {
      await loadSession();
      final sessionReady = await ensureAiSession(
        migrationWallet: widget.migrationWallet,
      );
      if (!sessionReady) {
        if (!mounted) {
          return;
        }
        setState(() {
          _error =
              _notice ??
              'AI session is not ready yet. Please try again shortly.';
        });
        return;
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'AI session is not ready yet. Please try again shortly.';
      });
      return;
    }

    if (!mounted) {
      return;
    }

    // ── Name mention warning ────────────────────────────────────────────────
    if (_containsPersonName(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ Privacy reminder: You appear to be mentioning a person\'s name. '
            'Please respect others\' privacy and avoid sharing personal information.',
          ),
          duration: Duration(seconds: 5),
          backgroundColor: Color(0xFF7B4F00),
        ),
      );
    }

    // ── Harmful intent warning (warn, never block) ──────────────────────────
    if (_containsHarmfulIntent(text)) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0A1224),
          title: const Text(
            '⚠️ Content Warning',
            style: TextStyle(color: Colors.orangeAccent),
          ),
          content: const Text(
            'Your message may involve sensitive or harmful topics.\n\n'
            'A-Network AI will always respond with care and may include safety resources. '
            'Remember: your actions affect real people — please choose good.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Send anyway',
                style: TextStyle(color: Colors.orangeAccent),
              ),
            ),
          ],
        ),
      );
      if (!mounted || proceed != true) return;
    }

    await _loadAndRefreshTokens();
    if (!mounted) {
      return;
    }

    if (_aiTokens < _messageCostTokens) {
      setState(() {
        _error = AppLocalizations.of(context).noAITokensLeft;
      });
      return;
    }

    setState(() {
      _aiTokens -= _messageCostTokens;
      _nextTokenRefillAt ??= DateTime.now().add(_tokenRefillInterval);
    });
    await _saveTokenState();

    setState(() {
      _sending = true;
      _error = null;
      _messages.add(_AiBubble(role: 'user', text: text));
    });
    _messageController.clear();
    _scrollSoon();
    unawaited(_saveChatHistory());

    try {
      final data = _deepResearchMode
          ? await sendAiDeepResearchMessage(
              text,
              conversationId: _conversationId,
            )
          : await sendAiChatMessage(text, conversationId: _conversationId);
      if (!mounted) {
        return;
      }

      final rawCitations = data['citations'];
      final citations = <String>[];
      if (rawCitations is List) {
        for (final item in rawCitations) {
          if (item is Map && item['snippet'] != null) {
            final snippet = item['snippet'].toString().trim();
            if (snippet.isNotEmpty) {
              citations.add(snippet);
            }
          }
        }
      }

      final reply =
          data['assistant_message']?.toString().trim().isNotEmpty == true
          ? data['assistant_message'].toString().trim()
          : 'No response received.';

      setState(() {
        _conversationId =
            data['conversation_id']?.toString() ?? _conversationId;
        _messages.add(
          _AiBubble(
            role: 'assistant',
            text: reply,
            citations: citations,
            isResearch: _deepResearchMode,
          ),
        );
        _sending = false;
      });
      _scrollSoon();
      unawaited(_saveChatHistory());
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sending = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pickAndUploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const [
          'txt',
          'md',
          'pdf',
          'jpg',
          'jpeg',
          'png',
          'webp',
          'gif',
        ],
      );
      if (result == null || result.files.isEmpty) {
        return;
      }

      final picked = result.files.first;
      final filename = (picked.name).trim().isEmpty
          ? 'upload.txt'
          : picked.name;

      if ((picked.path == null || picked.path!.isEmpty) &&
          picked.bytes == null) {
        throw Exception('Selected file has no readable content');
      }

      await uploadAiMemoryFile(
        filename: filename,
        filePath: picked.path,
        bytes: picked.bytes,
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uploaded $filename to AI memory')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _speech.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _listening = false;
      });
      return;
    }

    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) {
          return;
        }
        if (status == 'notListening' || status == 'done') {
          setState(() {
            _listening = false;
          });
        }
      },
      onError: (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _listening = false;
        });
      },
    );

    if (!available) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).voiceRecognitionUnavailable,
          ),
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _listening = true;
    });

    await _speech.listen(
      onResult: (result) {
        _messageController.text = result.recognizedWords;
        _messageController.selection = TextSelection.fromPosition(
          TextPosition(offset: _messageController.text.length),
        );
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
        partialResults: true,
        cancelOnError: true,
      ),
    );
  }

  Future<void> _speakLastAssistantReply() async {
    _AiBubble? lastAssistant;
    for (var i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].role == 'assistant' &&
          _messages[i].text.trim().isNotEmpty) {
        lastAssistant = _messages[i];
        break;
      }
    }

    if (lastAssistant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).noAssistantResponse),
        ),
      );
      return;
    }

    if (_speaking) {
      await _tts.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _speaking = false;
      });
      return;
    }

    setState(() {
      _speaking = true;
    });
    try {
      await _ensureVoiceConfigured();
      await _tts.speak(lastAssistant.text).timeout(const Duration(seconds: 8));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _speaking = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice playback is temporarily unavailable.'),
        ),
      );
    }
  }

  void _scrollSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Re-asks the last user prompt and drops the previous assistant reply so
  /// the model has a chance to produce a better answer. Costs one token, same
  /// as a normal send — keeps the economics simple.
  Future<void> _regenerateLastReply() async {
    if (_sending || _messages.isEmpty) return;
    String? lastUser;
    for (var i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].role == 'user') {
        lastUser = _messages[i].text;
        break;
      }
    }
    if (lastUser == null || lastUser.trim().isEmpty) return;
    setState(() {
      while (_messages.isNotEmpty && _messages.last.role != 'user') {
        _messages.removeLast();
      }
      if (_messages.isNotEmpty && _messages.last.role == 'user') {
        _messages.removeLast();
      }
    });
    unawaited(_saveChatHistory());
    _messageController.text = lastUser;
    await _send();
  }

  Future<void> _confirmClearChat() async {
    if (_messages.isEmpty) {
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1224),
        title: const Text('Clear chat?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This removes the conversation from this device. AI tokens are not refunded.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.orangeAccent),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() {
      _messages.clear();
      _error = null;
      _conversationId = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_chatHistoryKey);
    } catch (_) {}
  }

  /// Pretty empty-state shown the first time a user opens AI Support (and
  /// whenever they clear the chat). Three tappable starter prompts beat a
  /// blank screen and immediately demonstrate what the assistant is good at.
  Widget _buildEmptyState() {
    final starters = <(String, IconData, String)>[
      (
        'How do I migrate from Web4 to A-Network?',
        Icons.swap_horiz,
        'Migration help',
      ),
      (
        'What is the difference between ANET and ANTS?',
        Icons.compare_arrows,
        'Token basics',
      ),
      (
        'How do I keep my wallet secure?',
        Icons.shield_outlined,
        'Wallet safety',
      ),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1224),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x3340E0FF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.smart_toy, color: Colors.cyanAccent, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'A-Network AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ask anything about A-Network — migrations, tokens, your wallet, '
                  'or general crypto questions. Each reply costs $_messageCostTokens token; '
                  'watch a short ad for more.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Try asking',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
          ...starters.map((s) {
            final prompt = s.$1;
            final icon = s.$2;
            final label = s.$3;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: (_booting || _sending || !_aiEnabled)
                    ? null
                    : () {
                        _messageController.text = prompt;
                        _send();
                      },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13233A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x3340E0FF)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Color(0xFF0A1224),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: Colors.cyanAccent, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              prompt,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white38,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1224),
        title: Row(
          children: [
            const Icon(Icons.smart_toy, color: Colors.cyanAccent, size: 24),
            const SizedBox(width: 12),
            Text(
              AppLocalizations.of(context).aiSupportTitle,
              style: const TextStyle(
                color: Colors.cyanAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _showTrainDialog,
            icon: const Icon(Icons.school, color: Colors.cyanAccent, size: 18),
            label: Text(
              AppLocalizations.of(context).trainButton,
              style: const TextStyle(color: Colors.cyanAccent),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.cyanAccent),
            color: const Color(0xFF0A1224),
            onSelected: (value) async {
              if (value == 'clear') {
                await _confirmClearChat();
              } else if (value == 'refresh') {
                await _syncAiTokensFromServer(hardSync: true);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tokens refreshed')),
                  );
                }
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem<String>(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.white70, size: 18),
                    SizedBox(width: 10),
                    Text('Clear chat', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.white70, size: 18),
                    SizedBox(width: 10),
                    Text(
                      'Refresh tokens',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            color: const Color(0xFF0A1224),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _quickChip(AppLocalizations.of(context).web4MigrationPolicy),
                _quickChip(AppLocalizations.of(context).anetVsAnts),
                _quickChip(AppLocalizations.of(context).securityWalletSafety),
              ],
            ),
          ),
          if (_notice != null && _notice!.trim().isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              color: const Color(0xFF0A1224),
              child: Text(
                _notice!,
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 12,
                ),
              ),
            ),
          Expanded(
            child: _booting
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.cyanAccent),
                  )
                : (_messages.isEmpty && _error == null)
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount:
                        _messages.length +
                        (_error == null ? 0 : 1) +
                        (_sending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_sending && index == _messages.length) {
                        return const _TypingBubble();
                      }
                      if (_error != null &&
                          index == _messages.length + (_sending ? 1 : 0)) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.orangeAccent),
                          ),
                        );
                      }

                      final item = _messages[index];
                      final isUser = item.role == 'user';
                      final isLastAssistant =
                          !isUser && index == _messages.length - 1 && !_sending;
                      final citationWidgets = item.citations
                          .map(
                            (citation) => Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Source: $citation',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          )
                          .toList();

                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          constraints: const BoxConstraints(maxWidth: 320),
                          decoration: BoxDecoration(
                            color: isUser
                                ? const Color(0xFF0F6D6D)
                                : const Color(0xFF13233A),
                            borderRadius: BorderRadius.circular(16),
                            border: item.isResearch && !isUser
                                ? Border.all(
                                    color: const Color(0x6640E0FF),
                                    width: 1,
                                  )
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildRichText(item.text),
                              if (!isUser)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isLastAssistant)
                                        TextButton.icon(
                                          onPressed: _aiEnabled
                                              ? _regenerateLastReply
                                              : null,
                                          icon: const Icon(
                                            Icons.refresh,
                                            size: 14,
                                            color: Colors.white60,
                                          ),
                                          label: const Text(
                                            'Regenerate',
                                            style: TextStyle(
                                              color: Colors.white60,
                                              fontSize: 12,
                                            ),
                                          ),
                                          style: TextButton.styleFrom(
                                            visualDensity:
                                                VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                          ),
                                        ),
                                      TextButton.icon(
                                        onPressed: () async {
                                          final l10n = AppLocalizations.of(
                                            this.context,
                                          );
                                          await Clipboard.setData(
                                            ClipboardData(text: item.text),
                                          );
                                          if (!mounted) {
                                            return;
                                          }
                                          ScaffoldMessenger.of(
                                            this.context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                l10n.copiedResponse,
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.copy,
                                          size: 14,
                                          color: Colors.white60,
                                        ),
                                        label: Text(
                                          AppLocalizations.of(
                                            context,
                                          ).copyButton,
                                          style: TextStyle(
                                            color: Colors.white60,
                                            fontSize: 12,
                                          ),
                                        ),
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ...citationWidgets,
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF13233A),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0x3340E0FF)),
                        ),
                        child: Text(
                          AppLocalizations.of(
                            context,
                          ).tokenBalance(_aiTokens.toString()),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _claimAdTokens,
                        child: Text(
                          AppLocalizations.of(
                            context,
                          ).watchAdTokens(_adRewardTokens.toString()),
                          style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _booting || !_aiEnabled
                            ? null
                            : _pickAndUploadFile,
                        icon: const Icon(Icons.add, color: Colors.white70),
                        tooltip: AppLocalizations.of(context).uploadTxtTooltip,
                      ),
                      IconButton(
                        onPressed: _booting || !_aiEnabled
                            ? null
                            : _toggleListening,
                        icon: Icon(
                          _listening ? Icons.mic : Icons.mic_none,
                          color: _listening
                              ? Colors.cyanAccent
                              : Colors.white70,
                        ),
                        tooltip: _listening
                            ? AppLocalizations.of(context).stopListeningTooltip
                            : AppLocalizations.of(
                                context,
                              ).startVoiceInputTooltip,
                      ),
                      IconButton(
                        onPressed: _messages.isEmpty
                            ? () => _showComingSoon('Read aloud')
                            : _speakLastAssistantReply,
                        icon: Icon(
                          _speaking ? Icons.volume_off : Icons.volume_up,
                          color: _speaking ? Colors.cyanAccent : Colors.white70,
                        ),
                        tooltip: _speaking
                            ? AppLocalizations.of(context).stopReadAloudTooltip
                            : AppLocalizations.of(
                                context,
                              ).readLatestResponseTooltip,
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _deepResearchMode = !_deepResearchMode;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _deepResearchMode
                                    ? AppLocalizations.of(
                                        context,
                                      ).deepResearchEnabled
                                    : AppLocalizations.of(
                                        context,
                                      ).deepResearchDisabled,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        label: const Text('Deep research'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _deepResearchMode
                              ? Colors.cyanAccent
                              : Colors.white70,
                          side: BorderSide(
                            color: _deepResearchMode
                                ? const Color(0xAA40E0FF)
                                : const Color(0x3340E0FF),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          enabled: _aiEnabled,
                          style: const TextStyle(color: Colors.white),
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: _listening
                                ? AppLocalizations.of(context).listeningSpeak
                                : AppLocalizations.of(context).askAIAnything,
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: const Color(0xFF0A1224),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: _aiEnabled ? (_) => _send() : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed: _booting || _sending || !_aiEnabled
                            ? null
                            : _send,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          foregroundColor: Colors.black,
                        ),
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickChip(String text) {
    return ActionChip(
      label: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
      backgroundColor: const Color(0xFF13233A),
      side: const BorderSide(color: Color(0x3340E0FF)),
      onPressed: (_booting || _sending || !_aiEnabled)
          ? null
          : () {
              _messageController.text = text;
              _send();
            },
    );
  }
}

class _AiBubble {
  const _AiBubble({
    required this.role,
    required this.text,
    this.citations = const <String>[],
    this.isResearch = false,
  });

  final String role;
  final String text;
  final List<String> citations;
  final bool isResearch;
}

/// Renders [text] with any https:// or http:// URLs as tappable coloured links.
Widget _buildRichText(String text, {TextStyle? baseStyle}) {
  final urlPattern = RegExp(r'https?://[^\s\]\)>]+', caseSensitive: false);
  final matches = urlPattern.allMatches(text);
  if (matches.isEmpty) {
    return Text(
      text,
      style: baseStyle ?? const TextStyle(color: Colors.white, height: 1.35),
    );
  }

  final spans = <InlineSpan>[];
  int cursor = 0;
  final effective =
      baseStyle ?? const TextStyle(color: Colors.white, height: 1.35);

  for (final match in matches) {
    if (match.start > cursor) {
      spans.add(
        TextSpan(text: text.substring(cursor, match.start), style: effective),
      );
    }
    final url = match.group(0)!;
    spans.add(
      TextSpan(
        text: url,
        style: effective.copyWith(
          color: const Color(0xFF40E0FF),
          decoration: TextDecoration.underline,
          decorationColor: const Color(0xFF40E0FF),
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            final uri = Uri.tryParse(url);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
      ),
    );
    cursor = match.end;
  }
  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor), style: effective));
  }

  return RichText(text: TextSpan(children: spans));
}

/// Bouncing-dots "AI is thinking" bubble shown while a reply is in flight.
/// Kept inside the same file so the AI support page is fully self-contained.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: const BoxConstraints(maxWidth: 120),
        decoration: BoxDecoration(
          color: const Color(0xFF13233A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final phase = (_ctrl.value + i * 0.2) % 1.0;
                final opacity = (0.3 + 0.7 * (1 - (phase * 2 - 1).abs())).clamp(
                  0.3,
                  1.0,
                );
                return Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withValues(alpha: opacity),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
