import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_chat_model.dart';
import '../models/user_chat_user.dart';
import '../services/user_chat_service.dart';
import '../../../core/theme/palette.dart';

class UserChatListTile extends StatelessWidget {
  final UserChat chat;
  final String currentUserId;
  final VoidCallback onTap;

  const UserChatListTile({
    super.key,
    required this.chat,
    required this.currentUserId,
    required this.onTap,
  });

  String? _getOtherUserId() {
    try {
      return chat.participants.firstWhere((id) => id != currentUserId);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final otherUserId = _getOtherUserId();

    // If no other user found, show error state
    if (otherUserId == null || otherUserId.isEmpty) {
      return ListTile(
        leading: const CircleAvatar(child: Icon(Icons.error_outline)),
        title: const Text('Invalid Chat'),
        subtitle: const Text('Unable to load chat participant'),
      );
    }

    return StreamBuilder<UserChatUser?>(
      stream: UserChatService().streamUser(otherUserId),
      builder: (context, snapshot) {
        final otherUser = snapshot.data;
        final displayName = otherUser?.displayName ?? 'Unknown User';
        final photoUrl = otherUser?.photoUrl;
        final isOnline = otherUser?.isOnline ?? false;

        return FutureBuilder<String?>(
          future: UserChatService().getUsername(otherUserId),
          builder: (context, usernameSnapshot) {
            final username = usernameSnapshot.data;
            // final displayText = username != null ? '@$username' : displayName; // OLD logic
            final truncatedName = displayName.length > 12
                ? '${displayName.substring(0, 12)}...'
                : displayName;

            return ListTile(
              onTap: onTap,
              leading: Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: photoUrl != null
                        ? NetworkImage(photoUrl)
                        : null,
                    backgroundColor: kPurple.withOpacity(0.3),
                    child: photoUrl == null
                        ? Text(
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : '?',
                            style: GoogleFonts.lora(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
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
                          border: Border.all(color: kDeepBlack, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              title: Row(
                children: [
                  Text(
                    truncatedName,
                    style: GoogleFonts.lora(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (username != null) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '@$username',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lora(
                          fontWeight: FontWeight.normal,
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                chat.lastMessage ?? 'No messages yet',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.lora(color: Colors.white60, fontSize: 14),
              ),
              trailing: StreamBuilder<int>(
                stream: UserChatService().getUnreadMessageCount(chat.chatId),
                builder: (context, unreadSnapshot) {
                  final unreadCount = unreadSnapshot.data ?? 0;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (chat.lastMessageTime != null)
                        Text(
                          _formatTime(chat.lastMessageTime!),
                          style: GoogleFonts.lora(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                        ),
                      const SizedBox(height: 4),
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: kPurple,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: kPurple.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: GoogleFonts.lora(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays > 0) {
      return '${time.day}/${time.month}';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
