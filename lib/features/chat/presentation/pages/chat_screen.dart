import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:clientapp/core/services/biblical_chat_api.dart';
import 'package:clientapp/core/models/chat_models.dart';
import 'package:clientapp/features/chat/presentation/widgets/message_bubble.dart';
import 'package:clientapp/shared/widgets/cosmic_background.dart';
import 'package:clientapp/core/theme/palette.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:clientapp/features/journal/presentation/pages/secret_journal.dart';
import 'package:clientapp/features/user_chat/screens/user_chat_list_screen.dart';
import 'package:clientapp/core/services/global_radio_service.dart';
import 'dart:ui';
import 'package:clientapp/core/reward/chat/chat_reward_service.dart';
import 'package:clientapp/core/reward/journal/journal_reward_service.dart';
import 'package:clientapp/shared/widgets/ring_feedback.dart';
import 'package:clientapp/services/subscription_manager.dart';
import 'package:clientapp/features/paywall/paywall_screen.dart';
import 'package:clientapp/features/chat/presentation/widgets/animated_world_logo.dart';

class ChatScreen extends StatefulWidget {
  final String title;
  final Color accent;
  final String endpoint;
  final String? backgroundImage;
  const ChatScreen({
    super.key,
    required this.title,
    required this.accent,
    required this.endpoint,
    this.backgroundImage,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _textFieldFocus = FocusNode();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<Map<String, dynamic>> _messages =
      []; // {'text':..., 'isUser':bool, 'typing':bool?}
  final ScrollController _scrollCtl = ScrollController();

  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _sending = false;
  bool _isLoading = true;
  int _characterCount = 0;
  int _speechSession =
      0; // increments each time we start listening to ignore stale results

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();

    // Listen to text field focus - mute radio when user is typing
    _textFieldFocus.addListener(_onFocusChange);

    // Load persisted messages for this chat
    _loadMessages();
  }

  void _onFocusChange() {
    if (_textFieldFocus.hasFocus) {
      GlobalRadioService.instance.mute();
    } else {
      // Delay unmute to prevent lag during navigation transitions or keyboard dismissal
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_textFieldFocus.hasFocus) {
          GlobalRadioService.instance.unmute();
        }
      });
    }
  }

  // Get a unique storage key for this chat endpoint
  String get _storageKey => 'chat_messages_${widget.endpoint}';

  // Load messages from SharedPreferences
  Future<void> _loadMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson = prefs.getString(_storageKey);

      if (messagesJson != null) {
        final List<dynamic> decoded = json.decode(messagesJson);
        final loadedMessages = decoded
            .map((m) => Map<String, dynamic>.from(m))
            .toList();

        if (mounted) {
          setState(() {
            _messages.clear();
            _messages.addAll(loadedMessages);
          });

          // Rebuild the AnimatedList with loaded messages
          for (int i = 0; i < _messages.length; i++) {
            _listKey.currentState?.insertItem(i, duration: Duration.zero);
          }

          // Scroll to bottom after loading
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom(animated: false);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading messages: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Save messages to SharedPreferences
  Future<void> _saveMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson = json.encode(_messages);
      await prefs.setString(_storageKey, messagesJson);
    } catch (e) {
      debugPrint('Error saving messages: $e');
    }
  }

  void _insertMessage(String text, bool isUser) {
    _messages.add({'text': text, 'isUser': isUser});
    _listKey.currentState?.insertItem(
      _messages.length - 1,
      duration: const Duration(milliseconds: 240),
    );
    _scrollToBottom();
    _saveMessages(); // Persist messages
  }

  void _insertTyping() {
    _messages.add({'text': '', 'isUser': false, 'typing': true});
    _listKey.currentState?.insertItem(
      _messages.length - 1,
      duration: const Duration(milliseconds: 240),
    );
    _scrollToBottom();
  }

  void _replaceTypingWith(String text) {
    final idx = _messages.lastIndexWhere((m) => (m['typing'] ?? false) == true);
    if (idx != -1) {
      _messages[idx]['text'] = text;
      _messages[idx]['typing'] = false;
      if (mounted) {
        setState(() {});
        _scrollToBottom();
        _saveMessages(); // Persist messages
      }
    } else {
      _insertMessage(text, false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    // Check subscription status
    final status = await SubscriptionManager.canChat();
    if (status != ChatAccessStatus.allowed) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaywallScreen(
              isTopUpMode: status == ChatAccessStatus.proLimitReached,
            ),
          ),
        );
      }
      return;
    }

    setState(() => _sending = true);
    _controller.clear();
    setState(() => _characterCount = 0);
    _insertMessage(text, true);

    try {
      _insertTyping();

      // Get the persona from the endpoint
      final persona = BiblicalPersona.fromEndpoint(widget.endpoint);

      // Award rings for sending a message
      ChatRewardService.instance.rewardMessageSent(persona);

      // Show visual/audio feedback
      RingFeedback.show(context);

      // Check for rate limiting before making the request
      final waitTime = BiblicalChatApiService.getWaitTime(widget.endpoint);
      if (waitTime != null && waitTime.inMilliseconds > 0) {
        _replaceTypingWith(
          'Please wait ${waitTime.inSeconds} seconds before sending another message.',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Rate limit: Please wait ${waitTime.inSeconds} seconds',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final response = await BiblicalChatApiService.sendMessage(
        persona: persona,
        message: text,
      );

      _replaceTypingWith(response.response);
    } on ApiError catch (e) {
      String userMessage;
      Color snackBarColor;

      switch (e.statusCode) {
        case 401:
          userMessage =
              'Authentication failed. Please check API configuration.';
          snackBarColor = Colors.red;
          break;
        case 422:
          userMessage = e.detail;
          snackBarColor = Colors.orange;
          break;
        case 429:
          userMessage = e.detail;
          snackBarColor = Colors.orange;
          break;
        case 500:
          userMessage = 'Server error. Please try again in a moment.';
          snackBarColor = Colors.red;
          break;
        default:
          userMessage = e.detail;
          snackBarColor = Colors.red;
      }

      _replaceTypingWith('Sorry, I encountered an issue. Please try again.');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
            backgroundColor: snackBarColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      _replaceTypingWith(
        'I\'m having trouble connecting right now. Please try again.',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Connection error. Please check your internet connection.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtl.hasClients) return;
      final pos = _scrollCtl.position.maxScrollExtent;
      if (animated) {
        _scrollCtl.animateTo(
          pos,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollCtl.jumpTo(pos);
      }
    });
  }

  void _listen() async {
    if (!_isListening) {
      // Ensure any previous session is fully reset to avoid old results resurfacing
      try {
        await _speech.cancel();
      } catch (_) {}
      final ok = await _speech.initialize();
      if (ok) {
        // New listening session id to guard callbacks
        _speechSession++;
        final int sessionId = _speechSession;
        setState(() {
          _isListening = true;
          _controller.clear(); // start fresh for this session
        });
        _speech.listen(
          onResult: (r) {
            // Ignore any late callbacks from previous sessions
            if (sessionId != _speechSession) return;
            setState(() => _controller.text = r.recognizedWords);
          },
          // keep partial results so users see live text; plugin defaults are fine otherwise
          partialResults: true,
        );
      }
    } else {
      setState(() => _isListening = false);
      // Stop current session and keep session id as-is so late callbacks are ignored
      try {
        await _speech.stop();
      } catch (_) {}
    }
  }

  Future<void> _clearConversation() async {
    if (_messages.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F1520),
        title: const Text(
          'New Conversation',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Start a new conversation? This will clear the current chat.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start New', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);

      if (mounted) {
        setState(() {
          // Remove all items from the AnimatedList
          for (int i = _messages.length - 1; i >= 0; i--) {
            final item = _messages[i];
            _listKey.currentState?.removeItem(
              i,
              (context, animation) => SizeTransition(
                sizeFactor: animation,
                child: FadeTransition(
                  opacity: animation,
                  child: MessageBubble(
                    text: item['text'],
                    isUser: item['isUser'],
                    accent: widget.accent,
                    isTyping: false,
                  ),
                ),
              ),
              duration: const Duration(milliseconds: 300),
            );
          }
          _messages.clear();
        });
      }
    } catch (e) {
      debugPrint('Error clearing conversation: $e');
    }
  }

  Future<void> _saveConversationToJournal() async {
    if (_messages.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nothing to save. Start a conversation first.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList('journal') ?? <String>[];

      final now = DateTime.now();
      final ts =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final buf = StringBuffer();
      buf.writeln('[$ts] — ${widget.title}');
      buf.writeln('Conversation');
      buf.writeln('────────────────────────────');

      String personaLabel() {
        switch (widget.title) {
          case 'Living Jesus':
            return 'Jesus (Not AI)';
          case 'Living Word':
            return 'Word (Not AI)';
          case 'Living God':
            return 'God (Not AI)';
          default:
            // Fall back to screen title without the 'Living ' prefix if present
            final t = widget.title.startsWith('Living ')
                ? widget.title.substring(7)
                : widget.title;
            return '$t (Not AI)';
        }
      }

      for (final m in _messages) {
        final isTyping = (m['typing'] ?? false) as bool;
        if (isTyping) continue; // skip transient typing indicator
        final isUser = (m['isUser'] ?? false) as bool;
        final text = (m['text'] ?? '').toString();
        if (text.trim().isEmpty) continue;
        // Chat-like transcript lines with a blank line between turns
        if (isUser) {
          buf.writeln('You > $text');
        } else {
          buf.writeln('${personaLabel()} > $text');
        }
        buf.writeln(''); // blank line between dialogs
      }
      buf.writeln('— End —');

      final entry = buf.toString().trimRight();
      if (entry.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No content to save')));
        }
        return;
      }

      existing.add(entry);
      await prefs.setStringList('journal', existing);

      // Award rings for saving chat
      await JournalRewardService.instance.rewardChatSaved();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Conversation saved to Secret Journal'),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SecretJournal()),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save conversation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _textFieldFocus.removeListener(_onFocusChange);
    // Unmute when leaving the screen, but schedule it to avoid jank during transition
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GlobalRadioService.instance.unmute();
    });

    _scrollCtl.dispose();
    _controller.dispose();
    _textFieldFocus.dispose();
    if (_isListening) {
      _speech.stop();
    }
    super.dispose();
  }

  Widget _buildEmptyState() {
    return Center(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UserChatListScreen()),
          );
        },
        child: const AnimatedWorldLogo(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Force brand red for Living Word screen regardless of passed accent background areas
    final bool isLivingWord = widget.title == "Living Word";
    final Color accent = isLivingWord ? kRed : widget.accent;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background
          if (widget.backgroundImage != null)
            Positioned.fill(
              child: Image.asset(widget.backgroundImage!, fit: BoxFit.cover),
            )
          else
            Positioned.fill(child: CosmicBackground(accent: accent)),
          // Dark overlay for better text readability
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.4)),
          ),
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: Column(
              children: [
                // Clean minimal header
                // Premium Glass Header
                ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
                      decoration: BoxDecoration(
                        color: kRoyalBlue.withValues(
                          alpha: 0.2,
                        ), // More transparent for glass effect
                        border: Border(
                          bottom: BorderSide(
                            color: kRoyalBlue.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Row(
                          children: [
                            // Status indicator with glow
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: _BreathingDot(color: accent),
                            ),

                            const SizedBox(width: 16),

                            // Title and subtitle
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20, // Slightly larger
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.5,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black45,
                                          offset: Offset(0, 2),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4ADE80),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF4ADE80,
                                              ).withValues(alpha: 0.5),
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Online",
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.7,
                                          ),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Save button
                            Opacity(
                              opacity: _messages.isEmpty ? 0.5 : 1,
                              child: InkWell(
                                onTap: _messages.isEmpty
                                    ? null
                                    : _saveConversationToJournal,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.1,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons
                                            .bookmark_border_rounded, // Rounded icon
                                        size: 16,
                                        color: accent,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            // New Conversation button
                            Opacity(
                              opacity: _messages.isEmpty ? 0.5 : 1,
                              child: InkWell(
                                onTap: _messages.isEmpty
                                    ? null
                                    : _clearConversation,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.1,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.add_circle_outline_rounded,
                                        size: 16,
                                        color: accent,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Messages
                Expanded(
                  child: _isLoading
                      ? const SizedBox.shrink()
                      : _messages.isEmpty
                      ? _buildEmptyState()
                      : NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            // Dismiss keyboard when user scrolls the chat
                            FocusScope.of(context).unfocus();
                            return false;
                          },
                          child: PrimaryScrollController(
                            controller: _scrollCtl,
                            child: AnimatedList(
                              key: _listKey,
                              primary: true,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              initialItemCount: _messages.length,
                              itemBuilder: (context, index, animation) {
                                final m = _messages[index];
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: animation.drive(
                                      Tween(
                                        begin: const Offset(0, 0.1),
                                        end: Offset.zero,
                                      ).chain(
                                        CurveTween(curve: Curves.easeOut),
                                      ),
                                    ),
                                    child: MessageBubble(
                                      text: m['text'],
                                      isUser: m['isUser'],
                                      accent: accent,
                                      isTyping: (m['typing'] ?? false) as bool,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                ),

                // Modern input
                // Premium Glass Input
                ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: kRoyalBlue.withValues(alpha: 0.3),
                        border: Border(
                          top: BorderSide(
                            color: kRoyalBlue.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Sheen(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF131B2C).withValues(
                                    alpha: 0.6,
                                  ), // Darker inner container
                                  borderRadius: BorderRadius.circular(
                                    24,
                                  ), // More rounded
                                  border: Border.all(
                                    color: kRoyalBlue.withValues(alpha: 0.4),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accent.withValues(alpha: 0.08),
                                      blurRadius: 20,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // Voice button
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _listen,
                                        borderRadius: BorderRadius.circular(20),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          margin: const EdgeInsets.all(4),
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: _isListening
                                                ? accent.withValues(alpha: 0.2)
                                                : Colors.transparent,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            _isListening
                                                ? Icons.mic
                                                : Icons.mic_none_rounded,
                                            size: 22,
                                            color: _isListening
                                                ? accent
                                                : const Color(0xFF8B8B92),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Input field
                                    Expanded(
                                      child: TextField(
                                        controller: _controller,
                                        focusNode: _textFieldFocus,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          height: 1.4,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        cursorColor: accent,
                                        decoration: InputDecoration(
                                          hintText: _messages.isEmpty
                                              ? "Ask ${widget.title}..."
                                              : "Type a message...",
                                          hintStyle: TextStyle(
                                            color: const Color(
                                              0xFF6B6B73,
                                            ).withValues(alpha: 0.8),
                                            fontSize: 16,
                                          ),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 14,
                                              ),
                                        ),
                                        maxLines: null,
                                        textCapitalization:
                                            TextCapitalization.sentences,
                                        onTapOutside: (_) =>
                                            FocusScope.of(context).unfocus(),
                                        onSubmitted: (_) => _send(),
                                        onChanged: (text) {
                                          setState(() {
                                            _characterCount = text.length;
                                          });
                                        },
                                      ),
                                    ),

                                    // Send button
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      margin: const EdgeInsets.all(4),
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: _sending
                                            ? Colors.transparent
                                            : accent,
                                        shape: BoxShape
                                            .circle, // Circular send button
                                        boxShadow: _sending
                                            ? null
                                            : [
                                                BoxShadow(
                                                  color: accent.withValues(
                                                    alpha: 0.4,
                                                  ),
                                                  blurRadius: 12,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                      ),
                                      child: IconButton(
                                        onPressed: _sending ? null : _send,
                                        icon: _sending
                                            ? SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: accent,
                                                    ),
                                              )
                                            : Icon(
                                                Icons
                                                    .arrow_upward_rounded, // Modern arrow
                                                size: 22,
                                                color: Colors.black,
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Character counter
                            if (_characterCount > 0)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  right: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      '$_characterCount/4000',
                                      style: TextStyle(
                                        color: _characterCount > 4000
                                            ? kRed
                                            : _characterCount > 3500
                                            ? Colors.orange
                                            : const Color(0xFF6B6B73),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BreathingDot extends StatefulWidget {
  final Color color;
  const _BreathingDot({required this.color});
  @override
  State<_BreathingDot> createState() => _BreathingDotState();
}

class _BreathingDotState extends State<_BreathingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, __) {
        final t = _ctl.value;
        return Container(
          width: 10 + 2 * t,
          height: 10 + 2 * t,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.6),
                blurRadius: 8 + 6 * t,
                spreadRadius: 0.5 + t,
              ),
            ],
          ),
        );
      },
    );
  }
}
