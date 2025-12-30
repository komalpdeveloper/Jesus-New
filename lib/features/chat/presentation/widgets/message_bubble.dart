import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:clientapp/shared/widgets/cosmic_background.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final Color accent;
  final bool isTyping;
  const MessageBubble({
    super.key,
    required this.text,
    required this.isUser,
    required this.accent,
    this.isTyping = false,
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
              child: isUser
                  ? SelectableText(
                      text,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                      ),
                    )
                  : isTyping
                      ? _TypingIndicator(color: accent)
                      : MarkdownBody(
                      data: text,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                          color: Color(0xFFE6E6E9),
                          fontSize: 15,
                          height: 1.4,
                          fontWeight: FontWeight.w400,
                        ),
                        strong: const TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontWeight: FontWeight.w700,
                        ),
                        em: const TextStyle(
                          color: Color(0xFFE6E6E9),
                          fontStyle: FontStyle.italic,
                        ),
                        code: const TextStyle(
                          color: Color(0xFFDBEAFE),
                          backgroundColor: Color(0x33162A40),
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: const Color(0x22162A40),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0x33162A40)),
                        ),
                        blockquote: const TextStyle(
                          color: Color(0xFFB3C1D1),
                          fontStyle: FontStyle.italic,
                        ),
                        blockquoteDecoration: const BoxDecoration(
                          border: Border(left: BorderSide(color: Color(0xFF2A3A55), width: 3)),
                        ),
                        listBullet: const TextStyle(color: Color(0xFFE6E6E9), fontSize: 15),
                        h1: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                        h2: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                        h3: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                        a: TextStyle(color: accent.withValues(alpha: 0.9), decoration: TextDecoration.underline),
                      ),
                      selectable: true,
                      onTapLink: (text, href, title) {
                        // Could add url_launcher here if needed later
                      },
                    ),
            ),
          ),
          
          // Copy button for AI messages
          if (!isUser && !isTyping && text.trim().isNotEmpty) ...[
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

class _TypingIndicator extends StatefulWidget {
  final Color color;
  const _TypingIndicator({required this.color});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final Animation<double> _a1;
  late final Animation<double> _a2;
  late final Animation<double> _a3;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _a1 = CurvedAnimation(parent: _ctl, curve: const Interval(0.0, 0.6, curve: Curves.easeInOut));
    _a2 = CurvedAnimation(parent: _ctl, curve: const Interval(0.2, 0.8, curve: Curves.easeInOut));
    _a3 = CurvedAnimation(parent: _ctl, curve: const Interval(0.4, 1.0, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Widget _dot(Animation<double> a) {
    final c = widget.color;
    return ScaleTransition(
      scale: Tween(begin: 0.6, end: 1.0).animate(a),
      child: Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: c.withValues(alpha: 0.35), blurRadius: 10, spreadRadius: 0.5),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(_a1),
        _dot(_a2),
        _dot(_a3),
      ],
    );
  }
}
