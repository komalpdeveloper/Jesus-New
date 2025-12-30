import 'package:flutter/material.dart';
import 'package:clientapp/shared/widgets/video_background.dart';
import 'package:clientapp/core/theme/palette.dart';

class UserChatBackground extends StatelessWidget {
  final Widget child;
  final bool isExiting;

  const UserChatBackground({
    super.key, 
    required this.child,
    this.isExiting = false,
  });

  @override
  Widget build(BuildContext context) {
    // When exiting, show solid black background instead of video
    // This prevents the video from showing during page transitions
    if (isExiting) {
      return Container(
        color: kDeepBlack,
        child: child,
      );
    }
    
    return Stack(
      children: [
        // Background video
        Positioned.fill(
          child: VideoBackground(
            assetPath: 'assets/chat/background.mov',
            placeholder: Opacity(
              opacity: 0.15,
              child: Image.asset(
                'assets/user_chat/background.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF1a1a2e),
                          Color(0xFF16213e),
                          Color(0xFF0f3460),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        // Dark overlay for better text readability
        Positioned.fill(
          child: Container(color: Colors.black.withValues(alpha: 0.4)),
        ),
        // Content
        child,
      ],
    );
  }
}
