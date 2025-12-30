import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cosmic_background.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final Color accent;
  const MessageBubble({
    super.key,
    required this.text,
    required this.isUser,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        bottom: 12,
        left: isUser ? 48 : 0,
        right: isUser ? 0 : 48,
      ),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Message bubble
          Sheen(
            period: const Duration(seconds: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isUser
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [accent, Color.lerp(accent, Colors.white, 0.1)!, accent.withValues(alpha: 0.9)],
                      )
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0F1520), Color(0xFF101826)],
                      ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: Border.all(
                  color: isUser ? Colors.transparent : const Color(0xFF162031),
                  width: 1,
                ),
                boxShadow: [
                  if (isUser)
                    BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 18, spreadRadius: 0.5, offset: const Offset(0, 6))
                  else
                    const BoxShadow(color: Colors.black54, blurRadius: 12, spreadRadius: 0.2, offset: Offset(0, 4)),
                ],
              ),
              child: SelectableText(
                text,
                style: TextStyle(
                  color: isUser ? Colors.black : const Color(0xFFE6E6E9),
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          
          // Copy button for AI messages
          if (!isUser) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied to clipboard'),
                    backgroundColor: Color(0xFF1C2533),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              child: Sheen(
                period: const Duration(seconds: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1520),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF162031)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.copy,
                        size: 12,
                        color: Color(0xFF8B8B92),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Copy',
                        style: TextStyle(
                          color: Color(0xFF8B8B92),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}