import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/user_chat_service.dart';
import '../models/user_chat_message.dart';
import '../models/user_chat_user.dart';
import '../models/user_chat_model.dart';
import '../widgets/user_chat_message_bubble.dart';
import '../widgets/user_chat_typing_indicator.dart';
import '../widgets/user_chat_background.dart';
import '../widgets/user_chat_shimmer_loading.dart';
import '../widgets/haptic_recorder_widget.dart';
import '../utils/link_preview_helper.dart';
import '../../../core/theme/palette.dart';
import '../../../../shared/widgets/royal_ring.dart';

class UserChatScreen extends StatefulWidget {
  final String chatId;

  const UserChatScreen({super.key, required this.chatId});

  @override
  State<UserChatScreen> createState() => _UserChatScreenState();
}

class _UserChatScreenState extends State<UserChatScreen>
    with SingleTickerProviderStateMixin {
  final UserChatService _chatService = UserChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _typingTimer;
  bool _isTyping = false;
  String? _currentVisibleDate;

  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _isFirstLoad = true;
  bool _isExiting = false; // Track exit state for shimmer overlay

  // Pagination
  final List<UserChatMessage> _allMessages = [];
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  StreamSubscription<List<UserChatMessage>>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _chatService.markMessagesAsDelivered(widget.chatId);
    _chatService.markMessagesAsSeen(widget.chatId);
    _scrollController.addListener(_onScroll);

    // Initialize fade animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _loadInitialMessages();
  }

  void _loadInitialMessages() {
    _messageSubscription = _chatService
        .getChatMessages(widget.chatId, limit: 30)
        .listen((messages) {
          if (mounted) {
            final wasFirstLoad = _isFirstLoad;
            setState(() {
              _allMessages.clear();
              _allMessages.addAll(messages);
              _hasMoreMessages = messages.length >= 30;
              if (_isFirstLoad) _isFirstLoad = false;
            });

            // Start fade animation after first load
            if (wasFirstLoad) {
              _fadeController.forward();
            }
          }
        });
  }

  void _onScroll() {
    // Load more messages when scrolling near the top (oldest messages)
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreMessages && _allMessages.isNotEmpty) {
        _loadMoreMessages();
      }
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final oldestMessage = _allMessages.last;
      final olderMessages = await _chatService.loadMoreMessages(
        widget.chatId,
        oldestMessage.timestamp,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          _allMessages.addAll(olderMessages);
          _hasMoreMessages = olderMessages.length >= 20;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading more messages: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _messageSubscription?.cancel();
    if (_isTyping) {
      _chatService.updateTypingStatus(widget.chatId, false);
    }
    super.dispose();
  }

  /// Handle back navigation with smooth exit animation
  Future<void> _handleBack() async {
    if (_isExiting) return;

    setState(() {
      _isExiting = true;
    });

    // Brief delay to show shimmer before popping
    await Future.delayed(const Duration(milliseconds: 150));

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _handleTyping() {
    if (!_isTyping) {
      _isTyping = true;
      _chatService.updateTypingStatus(widget.chatId, true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _isTyping = false;
      _chatService.updateTypingStatus(widget.chatId, false);
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    debugPrint('🚀 Sending message: $text to chat: ${widget.chatId}');

    _messageController.clear();

    // Show visual/audio feedback
    RoyalRing.show(
      context,
      glowColor: Colors.amber.withValues(alpha: 0.3), // Faint yellow
      size: 30,
      behavior: RoyalRingBehavior.chat,
    );

    if (_isTyping) {
      _isTyping = false;
      _chatService.updateTypingStatus(widget.chatId, false);
    }

    try {
      // Check if message contains a link
      LinkPreview? linkPreview;
      final url = LinkPreviewHelper.extractUrl(text);
      if (url != null) {
        debugPrint('🔗 Detected URL: $url');
        // Fetch link preview metadata
        linkPreview = await LinkPreviewHelper.fetchLinkPreview(url);
        if (linkPreview != null) {
          debugPrint('✅ Link preview fetched: ${linkPreview.title}');
        } else {
          // If fetch fails, still include basic URL
          linkPreview = LinkPreview(url: url);
        }
      }

      await _chatService.sendMessage(
        chatId: widget.chatId,
        text: text,
        linkPreview: linkPreview,
      );
      debugPrint('✅ Message sent successfully');
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
    }
  }

  void _showHapticRecorder() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => HapticRecorderWidget(
        onPatternRecorded: (pattern) async {
          Navigator.pop(modalContext);

          try {
            final hapticMessage = UserChatMessage(
              messageId: '',
              senderId: _chatService.currentUserId!,
              text: '',
              hapticPattern: pattern,
              timestamp: DateTime.now(),
              status: 'sent',
              seenBy: [_chatService.currentUserId!],
            );

            await _chatService.sendMessage(
              chatId: widget.chatId,
              text: '',
              hapticPattern: hapticMessage,
            );

            debugPrint('✅ Haptic pattern sent successfully');
          } catch (e) {
            debugPrint('❌ Error sending haptic pattern: $e');
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to send haptic: $e')),
            );
          }
        },
        onCancel: () {
          Navigator.pop(modalContext);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _chatService.currentUserId;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: kDeepBlack,
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: _handleBack,
              ),
              title: StreamBuilder<UserChat?>(
                stream: _chatService.streamChat(widget.chatId),
                builder: (context, chatSnapshot) {
                  if (!chatSnapshot.hasData) {
                    return const Text('Chat');
                  }

                  final chat = chatSnapshot.data!;
                  final otherUserId = chat.participants.firstWhere(
                    (id) => id != currentUserId,
                    orElse: () => '',
                  );

                  return StreamBuilder<UserChatUser?>(
                    stream: _chatService.streamUser(otherUserId),
                    builder: (context, userSnapshot) {
                      final user = userSnapshot.data;
                      final displayName = user?.displayName ?? 'Unknown User';
                      final isOnline = user?.isOnline ?? false;
                      final lastSeen = user?.lastSeen;

                      return FutureBuilder<String?>(
                        future: _chatService.getUsername(otherUserId),
                        builder: (context, usernameSnapshot) {
                          final username = usernameSnapshot.data;
                          final displayText = username != null
                              ? '@$username'
                              : displayName;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                displayText,
                                style: GoogleFonts.lora(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Row(
                                children: [
                                  if (isOnline)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(right: 6),
                                      decoration: const BoxDecoration(
                                        color: Colors.greenAccent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  Text(
                                    isOnline
                                        ? 'Online'
                                        : lastSeen != null
                                        ? 'Last seen ${_formatLastSeen(lastSeen)}'
                                        : 'Offline',
                                    style: GoogleFonts.lora(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            body: UserChatBackground(
              isExiting: _isExiting,
              child: SafeArea(
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: _isFirstLoad
                              ? const ChatMessagesShimmer()
                              : _allMessages.isEmpty
                              ? FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: Center(
                                    child: Text(
                                      'No messages yet. Start the conversation!',
                                      style: GoogleFonts.lora(
                                        color: Colors.white70,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                )
                              : FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: ListView.builder(
                                    controller: _scrollController,
                                    reverse: true,
                                    physics: const ClampingScrollPhysics(),
                                    padding: const EdgeInsets.only(
                                      top: 16,
                                      left: 8,
                                      right: 8,
                                      bottom: 16,
                                    ),
                                    itemCount:
                                        _allMessages.length +
                                        (_isLoadingMore ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      // Show loading indicator at the end (top when reversed)
                                      if (index == _allMessages.length) {
                                        return const Center(
                                          child: Padding(
                                            padding: EdgeInsets.all(16.0),
                                            child: CircularProgressIndicator(
                                              color: kPurple,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        );
                                      }

                                      final message = _allMessages[index];
                                      final isMe =
                                          message.senderId == currentUserId;

                                      // Convert to local time
                                      final localTime = message.timestamp
                                          .toLocal();

                                      // Check if we need to show date separator BEFORE this message
                                      bool showDateSeparator = false;
                                      if (index == _allMessages.length - 1) {
                                        // Always show date for the oldest message
                                        showDateSeparator = true;
                                      } else {
                                        final nextMessage =
                                            _allMessages[index + 1];
                                        final nextLocalTime = nextMessage
                                            .timestamp
                                            .toLocal();

                                        final currentDate = DateTime(
                                          localTime.year,
                                          localTime.month,
                                          localTime.day,
                                        );
                                        final nextDate = DateTime(
                                          nextLocalTime.year,
                                          nextLocalTime.month,
                                          nextLocalTime.day,
                                        );
                                        showDateSeparator = !currentDate
                                            .isAtSameMomentAs(nextDate);
                                      }

                                      return Column(
                                        children: [
                                          // Show date separator BEFORE the message
                                          if (showDateSeparator)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8,
                                                bottom: 16,
                                              ),
                                              child: _buildDateSeparator(
                                                localTime,
                                              ),
                                            ),
                                          UserChatMessageBubble(
                                            message: message,
                                            isMe: isMe,
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                        ),
                        IgnorePointer(
                          child: StreamBuilder<UserChat?>(
                            stream: _chatService.streamChat(widget.chatId),
                            builder: (context, snapshot) {
                              final chat = snapshot.data;
                              final otherUserId = chat?.participants.firstWhere(
                                (id) => id != currentUserId,
                                orElse: () => '',
                              );
                              final isOtherTyping =
                                  otherUserId != null &&
                                  (chat?.typing[otherUserId] ?? false);

                              if (isOtherTyping) {
                                return const Padding(
                                  padding: EdgeInsets.only(left: 8, bottom: 4),
                                  child: UserChatTypingIndicator(),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        _buildMessageInput(),
                      ],
                    ),
                    // Sticky date header at top
                    if (_currentVisibleDate != null)
                      Positioned(
                        top: 8,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: kPurple.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                _currentVisibleDate!,
                                style: GoogleFonts.lora(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Exit shimmer overlay
          if (_isExiting)
            Positioned.fill(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _isExiting ? 1.0 : 0.0,
                child: Container(
                  color: kDeepBlack,
                  child: const ChatMessagesShimmer(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Haptic button
          ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: kGold.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.fingerprint,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: _showHapticRecorder,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 48, maxHeight: 120),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _messageController,
                      onChanged: (_) => _handleTyping(),
                      style: GoogleFonts.lora(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: GoogleFonts.lora(color: Colors.white54),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: kPurple.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: _sendMessage,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(DateTime localDate) {
    // Use device's local time
    final now = DateTime.now(); // This is already in local time
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(
      localDate.year,
      localDate.month,
      localDate.day,
    );

    String dateText;
    if (messageDate.isAtSameMomentAs(today)) {
      dateText = 'Today';
    } else if (messageDate.isAtSameMomentAs(yesterday)) {
      dateText = 'Yesterday';
    } else if (now.difference(messageDate).inDays < 7) {
      final weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      dateText = weekdays[localDate.weekday - 1];
    } else {
      dateText = '${localDate.day}/${localDate.month}/${localDate.year}';
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Text(
          dateText,
          style: GoogleFonts.lora(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final diff = now.difference(lastSeen);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${lastSeen.day}/${lastSeen.month}/${lastSeen.year}';
  }
}
