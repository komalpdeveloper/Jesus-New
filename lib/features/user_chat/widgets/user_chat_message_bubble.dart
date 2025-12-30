import 'package:flutter/material.dart';
import '../models/user_chat_message.dart';
import '../../../core/theme/palette.dart';
import 'haptic_playback_widget.dart';
import 'link_preview_card.dart';

class UserChatMessageBubble extends StatelessWidget {
  final UserChatMessage message;
  final bool isMe;

  const UserChatMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  Widget _buildStatusIcon() {
    switch (message.status) {
      case 'sent':
        return const Icon(Icons.check, size: 14, color: Colors.grey);
      case 'delivered':
        return const Icon(Icons.done_all, size: 14, color: Colors.grey);
      case 'seen':
        return const Icon(Icons.done_all, size: 14, color: Colors.blue);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🎨 Building bubble: ${message.text}, isMe: $isMe');
    
    // If message has haptic pattern, show haptic playback widget
    if (message.hapticPattern != null) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: HapticPlaybackWidget(
            pattern: message.hapticPattern!,
            isMe: isMe,
          ),
        ),
      );
    }
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
          minHeight: 40,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isMe ? kPurple.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.2),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.imageUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    message.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.broken_image, color: Colors.white54),
                  ),
                ),
              ),
            if (message.text.isNotEmpty)
              Text(
                message.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            if (message.linkPreview != null)
              LinkPreviewCard(
                linkPreview: message.linkPreview!,
                isMe: isMe,
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  _buildStatusIcon(),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    // Convert to local time
    final localTime = time.toLocal();
    final now = DateTime.now();
    final diff = now.difference(localTime);

    if (diff.inDays > 0) {
      return '${localTime.day}/${localTime.month}/${localTime.year}';
    } else {
      return '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
    }
  }
}
