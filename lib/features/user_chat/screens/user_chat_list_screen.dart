import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/user_chat_service.dart';
import '../models/user_chat_model.dart';
import '../models/user_chat_user.dart';
import '../widgets/user_chat_list_tile.dart';
import '../widgets/user_chat_background.dart';
import '../widgets/user_chat_shimmer_loading.dart';
import 'user_chat_screen.dart';
import 'user_chat_search_screen.dart';
import 'user_chat_archived_screen.dart';
import '../../../core/theme/palette.dart';

class UserChatListScreen extends StatefulWidget {
  const UserChatListScreen({super.key});

  @override
  State<UserChatListScreen> createState() => _UserChatListScreenState();
}

class _UserChatListScreenState extends State<UserChatListScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final UserChatService _chatService = UserChatService();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _isFirstLoad = true;
  bool _isExiting = false; // Track exit state for shimmer overlay

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chatService.updateUserPresence(isOnline: true);

    // Initialize fade animation for smooth content appearance
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _chatService.updateUserPresence(isOnline: false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _chatService.updateUserPresence(isOnline: true);
    } else if (state == AppLifecycleState.paused) {
      _chatService.updateUserPresence(isOnline: false);
    }
  }

  void _showRecentChatUsers() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _RecentChatUsersSheet(chatService: _chatService),
    );
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

  @override
  Widget build(BuildContext context) {
    final currentUserId = _chatService.currentUserId;

    if (currentUserId == null) {
      return Scaffold(
        backgroundColor: kDeepBlack,
        appBar: AppBar(
          title: Text('Chats', style: GoogleFonts.lora()),
          backgroundColor: Colors.transparent,
        ),
        body: const Center(child: Text('Please sign in to use chat')),
      );
    }

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
              title: Text(
                'Chats',
                style: GoogleFonts.lora(fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: _handleBack,
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.archive, size: 20),
                          onPressed: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        const UserChatArchivedScreen(),
                                transitionsBuilder:
                                    (
                                      context,
                                      animation,
                                      secondaryAnimation,
                                      child,
                                    ) {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: SlideTransition(
                                          position:
                                              Tween<Offset>(
                                                begin: const Offset(0.05, 0),
                                                end: Offset.zero,
                                              ).animate(
                                                CurvedAnimation(
                                                  parent: animation,
                                                  curve: Curves.easeOutCubic,
                                                ),
                                              ),
                                          child: child,
                                        ),
                                      );
                                    },
                                transitionDuration: const Duration(
                                  milliseconds: 300,
                                ),
                                reverseTransitionDuration: const Duration(
                                  milliseconds: 250,
                                ),
                              ),
                            );
                          },
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: kPurple.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.search, size: 20),
                          onPressed: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        const UserChatSearchScreen(),
                                transitionsBuilder:
                                    (
                                      context,
                                      animation,
                                      secondaryAnimation,
                                      child,
                                    ) {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: SlideTransition(
                                          position:
                                              Tween<Offset>(
                                                begin: const Offset(0.05, 0),
                                                end: Offset.zero,
                                              ).animate(
                                                CurvedAnimation(
                                                  parent: animation,
                                                  curve: Curves.easeOutCubic,
                                                ),
                                              ),
                                          child: child,
                                        ),
                                      );
                                    },
                                transitionDuration: const Duration(
                                  milliseconds: 300,
                                ),
                                reverseTransitionDuration: const Duration(
                                  milliseconds: 250,
                                ),
                              ),
                            );
                          },
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            body: UserChatBackground(
              isExiting: _isExiting,
              child: StreamBuilder<List<UserChat>>(
                stream: _chatService.getUserChats(),
                builder: (context, snapshot) {
                  // Show shimmer loading on initial load
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      _isFirstLoad) {
                    return const ChatListShimmer();
                  }

                  // Start fade animation when data arrives
                  if (snapshot.hasData && _isFirstLoad) {
                    _isFirstLoad = false;
                    _fadeController.forward();
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  final chats = snapshot.data ?? [];

                  if (chats.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No chats yet',
                            style: GoogleFonts.lora(
                              fontSize: 18,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start a conversation by searching for users',
                            style: GoogleFonts.lora(color: Colors.white54),
                          ),
                        ],
                      ),
                    );
                  }

                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: ListView.separated(
                      padding: const EdgeInsets.only(top: 100),
                      itemCount: chats.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      itemBuilder: (context, index) {
                        final chat = chats[index];
                        return Dismissible(
                          key: Key(chat.chatId),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.green,
                            child: const Icon(
                              Icons.archive,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          onDismissed: (direction) {
                            _chatService.archiveChat(chat.chatId);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Chat archived'),
                                action: SnackBarAction(
                                  label: 'Undo',
                                  onPressed: () =>
                                      _chatService.unarchiveChat(chat.chatId),
                                ),
                              ),
                            );
                          },
                          child: UserChatListTile(
                            chat: chat,
                            currentUserId: currentUserId,
                            onTap: () {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                      ) => UserChatScreen(chatId: chat.chatId),
                                  transitionsBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                        child,
                                      ) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: SlideTransition(
                                            position:
                                                Tween<Offset>(
                                                  begin: const Offset(0.05, 0),
                                                  end: Offset.zero,
                                                ).animate(
                                                  CurvedAnimation(
                                                    parent: animation,
                                                    curve: Curves.easeOutCubic,
                                                  ),
                                                ),
                                            child: child,
                                          ),
                                        );
                                      },
                                  transitionDuration: const Duration(
                                    milliseconds: 300,
                                  ),
                                  reverseTransitionDuration: const Duration(
                                    milliseconds: 250,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            floatingActionButton: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: kPurple.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: kPurple.withValues(alpha: 0.5),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add, color: Colors.white, size: 28),
                    onPressed: _showRecentChatUsers,
                    padding: EdgeInsets.zero,
                  ),
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
                  child: const ChatListShimmer(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecentChatUsersSheet extends StatelessWidget {
  final UserChatService chatService;

  const _RecentChatUsersSheet({required this.chatService});

  Future<void> _startChat(BuildContext context, String userId) async {
    try {
      final chatId = await chatService.getOrCreatePrivateChat(userId);
      if (context.mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                UserChatScreen(chatId: chatId),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(0.05, 0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                      child: child,
                    ),
                  );
                },
            transitionDuration: const Duration(milliseconds: 300),
            reverseTransitionDuration: const Duration(milliseconds: 250),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to start chat: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: kDeepBlack.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Chat Users',
                  style: GoogleFonts.lora(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<UserChat>>(
              stream: chatService.getUserChats(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const UserSearchShimmer(itemCount: 5);
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: GoogleFonts.lora(color: Colors.white70),
                    ),
                  );
                }

                final chats = snapshot.data ?? [];

                if (chats.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No recent chats',
                          style: GoogleFonts.lora(
                            fontSize: 16,
                            color: Colors.white60,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Search for users to start chatting',
                          style: GoogleFonts.lora(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Extract unique users from chats
                final currentUserId = chatService.currentUserId;
                final userIds = chats
                    .expand((chat) => chat.participants)
                    .where((id) => id != currentUserId)
                    .toSet()
                    .toList();

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: userIds.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  itemBuilder: (context, index) {
                    final userId = userIds[index];
                    return StreamBuilder<UserChatUser?>(
                      stream: chatService.streamUser(userId),
                      builder: (context, userSnapshot) {
                        final user = userSnapshot.data;
                        final displayName = user?.displayName ?? 'Unknown User';
                        final photoUrl = user?.photoUrl;
                        final isOnline = user?.isOnline ?? false;

                        return FutureBuilder<String?>(
                          future: chatService.getUsername(userId),
                          builder: (context, usernameSnapshot) {
                            final username = usernameSnapshot.data;
                            final displayText = username != null
                                ? '@$username'
                                : displayName;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 10,
                                    sigmaY: 10,
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: ListTile(
                                      onTap: () => _startChat(context, userId),
                                      leading: Stack(
                                        children: [
                                          CircleAvatar(
                                            radius: 24,
                                            backgroundImage: photoUrl != null
                                                ? NetworkImage(photoUrl)
                                                : null,
                                            backgroundColor: kPurple.withValues(
                                              alpha: 0.3,
                                            ),
                                            child: photoUrl == null
                                                ? Text(
                                                    displayText.isNotEmpty
                                                        ? displayText[0]
                                                              .toUpperCase()
                                                        : '?',
                                                    style: GoogleFonts.lora(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          if (isOnline)
                                            Positioned(
                                              right: 0,
                                              bottom: 0,
                                              child: Container(
                                                width: 14,
                                                height: 14,
                                                decoration: BoxDecoration(
                                                  color: Colors.greenAccent,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: kDeepBlack,
                                                    width: 2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      title: Text(
                                        displayText,
                                        style: GoogleFonts.lora(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      subtitle: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isOnline) ...[
                                            Container(
                                              width: 8,
                                              height: 8,
                                              margin: const EdgeInsets.only(
                                                right: 6,
                                              ),
                                              decoration: const BoxDecoration(
                                                color: Colors.greenAccent,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            Text(
                                              'Online',
                                              style: GoogleFonts.lora(
                                                color: Colors.greenAccent,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ] else
                                            Text(
                                              'Offline',
                                              style: GoogleFonts.lora(
                                                color: Colors.white54,
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                      trailing: Icon(
                                        Icons.chat_bubble_outline,
                                        color: kPurple.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
