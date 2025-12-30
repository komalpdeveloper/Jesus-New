import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/user_chat_service.dart';
import '../models/user_chat_user.dart';
import '../widgets/user_chat_background.dart';
import '../widgets/user_chat_shimmer_loading.dart';
import 'user_chat_screen.dart';
import '../../../core/theme/palette.dart';

class UserChatSearchScreen extends StatefulWidget {
  const UserChatSearchScreen({super.key});

  @override
  State<UserChatSearchScreen> createState() => _UserChatSearchScreenState();
}

class _UserChatSearchScreenState extends State<UserChatSearchScreen>
    with SingleTickerProviderStateMixin {
  final UserChatService _chatService = UserChatService();
  final TextEditingController _searchController = TextEditingController();
  List<UserChatUser> _searchResults = [];
  bool _isSearching = false;
  bool _isExiting = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
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
    _searchController.dispose();
    super.dispose();
  }

  void _handleBack() {
    setState(() => _isExiting = true);
    Navigator.of(context).pop();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      _fadeController.reset();
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await _chatService.searchUsers(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
      _fadeController.forward(from: 0.0);
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Search failed: $e')));
      }
    }
  }

  Future<void> _startChat(UserChatUser user) async {
    try {
      final chatId = await _chatService.getOrCreatePrivateChat(user.id);
      if (mounted) {
        Navigator.pushReplacement(
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to start chat: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: _handleBack,
          ),
          title: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: GoogleFonts.lora(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by username...',
                    border: InputBorder.none,
                    hintStyle: GoogleFonts.lora(color: Colors.white54),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  ),
                  onChanged: _performSearch,
                ),
              ),
            ),
          ),
        ),
        body: UserChatBackground(isExiting: _isExiting, child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_isSearching) {
      return const SafeArea(child: UserSearchShimmer(itemCount: 6));
    }

    if (_searchController.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Search for users to start chatting',
              style: GoogleFonts.lora(fontSize: 16, color: Colors.white60),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: GoogleFonts.lora(fontSize: 16, color: Colors.white60),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 100),
        itemCount: _searchResults.length,
        separatorBuilder: (context, index) =>
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),
        itemBuilder: (context, index) {
          final user = _searchResults[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage: user.photoUrl != null
                              ? NetworkImage(user.photoUrl!)
                              : null,
                          child: user.photoUrl == null
                              ? Text(
                                  user.displayName?.isNotEmpty == true
                                      ? user.displayName![0].toUpperCase()
                                      : '?',
                                  style: GoogleFonts.lora(color: Colors.white),
                                )
                              : null,
                        ),
                        if (user.isOnline)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.greenAccent,
                                shape: BoxShape.circle,
                                border: Border.all(color: kDeepBlack, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: FutureBuilder<String?>(
                      future: _chatService.getUsername(user.id),
                      builder: (context, snapshot) {
                        final username = snapshot.data;
                        return Text(
                          username != null
                              ? '@$username'
                              : user.displayName ?? 'Unknown User',
                          style: GoogleFonts.lora(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                    subtitle: user.isOnline
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
                                'Online',
                                style: GoogleFonts.lora(
                                  color: Colors.greenAccent,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            'Offline',
                            style: GoogleFonts.lora(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                    onTap: () => _startChat(user),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
