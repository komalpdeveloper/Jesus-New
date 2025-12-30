import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/bible_data.dart';
import '../../../shared/widgets/back_nav_button.dart';
import '../../notes/presentation/notes_list_screen.dart';
import '../../notes/models/note.dart';
import 'package:clientapp/services/subscription_manager.dart';
import 'package:clientapp/features/paywall/paywall_screen.dart';

class ChatBibleScreen extends StatefulWidget {
  final String book;
  final int chapter;
  final int selectedVerse;

  const ChatBibleScreen({
    super.key,
    required this.book,
    required this.chapter,
    required this.selectedVerse,
  });

  @override
  State<ChatBibleScreen> createState() => _ChatBibleScreenState();
}

class _ChatBibleScreenState extends State<ChatBibleScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final List<Map<String, String>> _chatMessages = [];
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _chapterBubbleKey = GlobalKey();
  bool _isLoading = false;
  bool _isRevealing = false;

  static const String _apiKey =
      'sk-chat-api-2025-Zx9Kp7Qm4Rt8Wv3Yh6Bf1Ng5Lc2Sd9Ae7Xu0Iy4';
  static const String _chatUrl =
      'https://fastapi-chat-service-1-8.onrender.com/chat-bible';
  static const String _revealUrl =
      'https://fastapi-chat-service-1-8.onrender.com/reveal-verse';

  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _checkPremium();
  }

  Future<void> _checkPremium() async {
    final status = await SubscriptionManager.isPremium();
    if (mounted) setState(() => _isPremium = status);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendChatMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // Check Chat Limit
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

    setState(() {
      _chatMessages.add({'role': 'user', 'text': message});
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom(); // Scroll for user message

    try {
      final response = await http.post(
        Uri.parse(_chatUrl),
        headers: {'Content-Type': 'application/json', 'x-api-key': _apiKey},
        body: jsonEncode({'user_message': message}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _chatMessages.add({
            'role': 'assistant',
            'text': data['response'] ?? 'No response',
          });
        });
      } else {
        setState(() {
          _chatMessages.add({
            'role': 'error',
            'text': 'Error ${response.statusCode}',
          });
        });
      }
    } catch (e) {
      setState(() {
        _chatMessages.add({'role': 'error', 'text': 'Error: $e'});
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom(); // Scroll for assistant response
    }
  }

  Future<void> _revealVerse(int verseNumber) async {
    final verseText = BibleData.getVerseText(
      widget.book,
      widget.chapter,
      verseNumber,
    );
    if (verseText.isEmpty) return;

    setState(() {
      _isRevealing = true;
    });

    try {
      final response = await http.post(
        Uri.parse(_revealUrl),
        headers: {'Content-Type': 'application/json', 'x-api-key': _apiKey},
        body: jsonEncode({'verse_text': verseText}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final revealed =
            data['revealed_verse'] ??
            data['response'] ??
            data['result'] ??
            data.toString();

        setState(() {
          _chatMessages.add({
            'role': 'reveal',
            'text':
                'Revelation for ${widget.book} ${widget.chapter}:$verseNumber\n\n$revealed',
          });
        });
        // Scroll to show the reveal message (just after chapter bubble)
        _scrollToRevealMessage();
      }
    } catch (e) {
      setState(() {
        _chatMessages.add({'role': 'error', 'text': 'Reveal error: $e'});
      });
    } finally {
      setState(() {
        _isRevealing = false;
      });
    }
  }

  void _scrollToRevealMessage() {
    // Multiple attempts to ensure scroll happens after layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attemptScrollToReveal(0);
    });
  }

  void _attemptScrollToReveal(int attempt) {
    if (!mounted || !_scrollController.hasClients || attempt > 5) return;

    Future.delayed(Duration(milliseconds: 100 + (attempt * 50)), () {
      if (!mounted || !_scrollController.hasClients) return;

      final RenderBox? renderBox =
          _chapterBubbleKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        // Get the height of the chapter bubble
        final bubbleHeight = renderBox.size.height;
        // Scroll to just after the chapter bubble (with padding)
        final targetPosition =
            bubbleHeight + 32.0; // 16 padding top + 16 spacing

        _scrollController.animateTo(
          targetPosition,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      } else if (attempt < 5) {
        // If render box not ready, try again
        _attemptScrollToReveal(attempt + 1);
      }
    });
  }

  void _handleAskAI(String selectedText) {
    if (selectedText.isEmpty) return;

    setState(() {
      _messageController.text = 'Context: "$selectedText"\nQuestion: ';
    });

    _messageFocusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _messageController.selection = TextSelection.fromPosition(
          TextPosition(offset: _messageController.text.length),
        );
      }
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: const Color(0xFF16213E).withOpacity(0.5)),
          ),
        ),
        leading: const BackNavButton(),
        title: Text(
          '${widget.book} ${widget.chapter}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.note_alt_outlined,
                color: Colors.amber,
                size: 20,
              ),
            ),
            tooltip: 'Notes',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const NotesListScreen(noteType: NoteType.bible),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          ),
        ),
        child: Column(
          children: [
            // Chapter text bubble with highlighted verse
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 0,
                ),
                children: [
                  SizedBox(
                    height:
                        MediaQuery.of(context).padding.top +
                        kToolbarHeight +
                        20,
                  ),
                  Container(
                    key: _chapterBubbleKey,
                    child: _buildChapterBubble(),
                  ),
                  const SizedBox(height: 20),
                  ..._chatMessages.map((msg) => _buildChatMessage(msg)),
                ],
              ),
            ),

            // Chat input bar
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E).withOpacity(0.95),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: TextField(
                        controller: _messageController,
                        focusNode: _messageFocusNode,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Ask about this verse...',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _sendChatMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _isLoading ? null : _sendChatMessage,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.amber, Colors.orange],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF1A1A2E),
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Color(0xFF1A1A2E),
                              size: 24,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterBubble() {
    final verses = BibleData.getVerses(widget.book, widget.chapter);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Text(
              '${widget.book} Chapter ${widget.chapter}',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SelectableText.rich(
            TextSpan(
              children: verses.expand((verseNum) {
                final isSelected = verseNum == widget.selectedVerse;
                final verseText = BibleData.getVerseText(
                  widget.book,
                  widget.chapter,
                  verseNum,
                );

                return [
                  TextSpan(
                    text: '$verseNum ',
                    style: TextStyle(
                      color: isSelected ? Colors.amber : Colors.grey[500],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: verseText,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      height: 1.6,
                      fontFamily:
                          'Roboto', // Consider a serif font if available
                      fontWeight: FontWeight.w400,
                      backgroundColor: isSelected
                          ? Colors.amber.withOpacity(0.15)
                          : null,
                    ),
                  ),
                  if (isSelected)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: GestureDetector(
                          onTap: _isRevealing
                              ? null
                              : () {
                                  if (!_isPremium) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const PaywallScreen(),
                                      ),
                                    );
                                    return;
                                  }
                                  _revealVerse(verseNum);
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: _isRevealing
                                  ? LinearGradient(
                                      colors: [
                                        Colors.purple[900]!,
                                        Colors.purple[700]!,
                                      ],
                                    )
                                  : (_isPremium
                                        ? const LinearGradient(
                                            colors: [
                                              Colors.purple,
                                              Colors.deepPurple,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : LinearGradient(
                                            colors: [
                                              Colors.grey[800]!,
                                              Colors.grey[700]!,
                                            ],
                                          )),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: _isPremium && !_isRevealing
                                  ? [
                                      BoxShadow(
                                        color: Colors.purple.withOpacity(0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: _isRevealing
                                ? _AnimatedDots()
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.auto_awesome,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Reveal',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (!_isPremium) ...[
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.lock_rounded,
                                          size: 12,
                                          color: Colors.white70,
                                        ),
                                      ],
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  const TextSpan(text: ' '),
                ];
              }).toList(),
            ),
            contextMenuBuilder: (context, editableTextState) {
              return AdaptiveTextSelectionToolbar.buttonItems(
                anchors: editableTextState.contextMenuAnchors,
                buttonItems: [
                  ...editableTextState.contextMenuButtonItems,
                  ContextMenuButtonItem(
                    onPressed: () {
                      final text = editableTextState.textEditingValue.selection
                          .textInside(editableTextState.textEditingValue.text);
                      if (text.isNotEmpty) {
                        _handleAskAI(text);
                        editableTextState.hideToolbar();
                      }
                    },
                    label: 'Ask AI',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessage(Map<String, String> msg) {
    final isUser = msg['role'] == 'user';
    final isError = msg['role'] == 'error';
    final isReveal = msg['role'] == 'reveal';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          gradient: isUser
              ? const LinearGradient(
                  colors: [Color(0xFF0F3460), Color(0xFF16213E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : isReveal
              ? const LinearGradient(
                  colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : isError
              ? LinearGradient(colors: [Colors.red[900]!, Colors.red[800]!])
              : LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isUser
                ? const Radius.circular(20)
                : const Radius.circular(4),
            bottomRight: isUser
                ? const Radius.circular(4)
                : const Radius.circular(20),
          ),
          border: Border.all(
            color: isReveal
                ? Colors.purple.withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isReveal) ...[
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.amber, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'REVELATION',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Text(
              msg['text'] ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedDots extends StatefulWidget {
  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _dotCount = 1;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          duration: const Duration(milliseconds: 600),
          vsync: this,
        )..addListener(() {
          if (_controller.isCompleted) {
            setState(() {
              _dotCount = (_dotCount % 3) + 1;
            });
            _controller.reset();
            _controller.forward();
          }
        });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      'Revealing${'.' * _dotCount}',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
