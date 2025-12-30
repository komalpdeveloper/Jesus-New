import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/user_chat_service.dart';
import '../models/user_chat_model.dart';
import '../widgets/user_chat_list_tile.dart';
import '../widgets/user_chat_background.dart';
import '../widgets/user_chat_shimmer_loading.dart';
import 'user_chat_screen.dart';
import '../../../core/theme/palette.dart';

class UserChatArchivedScreen extends StatefulWidget {
  const UserChatArchivedScreen({super.key});

  @override
  State<UserChatArchivedScreen> createState() => _UserChatArchivedScreenState();
}

class _UserChatArchivedScreenState extends State<UserChatArchivedScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _isFirstLoad = true;
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  /// Handle back navigation with smooth exit
  Future<void> _handleBack() async {
    if (_isExiting) return;

    setState(() {
      _isExiting = true;
    });

    await Future.delayed(const Duration(milliseconds: 100));

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatService = UserChatService();
    final currentUserId = chatService.currentUserId;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Scaffold(
        backgroundColor: kDeepBlack,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(
            'Archived Chats',
            style: GoogleFonts.lora(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: _handleBack,
          ),
        ),
        body: UserChatBackground(
          isExiting: _isExiting,
          child: SafeArea(
            child: StreamBuilder<List<UserChat>>(
              stream: chatService.getArchivedChats(),
              builder: (context, snapshot) {
                // Show shimmer on initial load
                if (snapshot.connectionState == ConnectionState.waiting &&
                    _isFirstLoad) {
                  return const ChatListShimmer(itemCount: 5);
                }

                // Trigger fade animation when data arrives
                if (snapshot.hasData && _isFirstLoad) {
                  _isFirstLoad = false;
                  _fadeController.forward();
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: GoogleFonts.lora(color: Colors.white70),
                    ),
                  );
                }

                final archivedChats = snapshot.data ?? [];

                if (archivedChats.isEmpty) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.archive_outlined,
                            size: 64,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No archived chats',
                            style: GoogleFonts.lora(
                              fontSize: 18,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Swipe left on any chat to archive it',
                            style: GoogleFonts.lora(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: archivedChats.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final chat = archivedChats[index];

                      return Dismissible(
                        key: Key('archived_${chat.chatId}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: kPurple,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.unarchive,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        onDismissed: (direction) {
                          chatService.unarchiveChat(chat.chatId);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Chat unarchived')),
                          );
                        },
                        child: UserChatListTile(
                          chat: chat,
                          currentUserId: currentUserId!,
                          onTap: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        UserChatScreen(chatId: chat.chatId),
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
        ),
      ),
    );
  }
}
