import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/palette.dart';

/// Shimmer loading for chat list items
class ChatListShimmer extends StatelessWidget {
  final int itemCount;
  const ChatListShimmer({super.key, this.itemCount = 8});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 100, left: 0, right: 0, bottom: 16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),
      itemBuilder: (_, index) => _ChatListItemShimmer(delay: index * 100),
    );
  }
}

class _ChatListItemShimmer extends StatelessWidget {
  final int delay;

  const _ChatListItemShimmer({this.delay = 0});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.white.withValues(alpha: 0.05),
      highlightColor: kPurple.withValues(alpha: 0.15),
      period: Duration(milliseconds: 1500 + delay),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar shimmer
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            // Content shimmer
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 200,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            // Trailing shimmer
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  height: 10,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 20,
                  width: 20,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer loading for messages in chat screen
class ChatMessagesShimmer extends StatelessWidget {
  final int itemCount;
  const ChatMessagesShimmer({super.key, this.itemCount = 10});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      reverse: true,
      itemBuilder: (_, index) => _MessageBubbleShimmer(
        isMe: index % 3 != 0, // Alternate between sent and received
        delay: index * 80,
      ),
    );
  }
}

class _MessageBubbleShimmer extends StatelessWidget {
  final bool isMe;
  final int delay;

  const _MessageBubbleShimmer({required this.isMe, this.delay = 0});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.white.withValues(alpha: 0.05),
      highlightColor: (isMe ? kPurple : Colors.white).withValues(alpha: 0.15),
      period: Duration(milliseconds: 1500 + delay),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(
            left: isMe ? 60 : 8,
            right: isMe ? 8 : 60,
            bottom: 8,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 12,
                width: isMe ? 100 : 150,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              if (!isMe) ...[
                const SizedBox(height: 6),
                Container(
                  height: 12,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shimmer loading for search results
class UserSearchShimmer extends StatelessWidget {
  final int itemCount;
  const UserSearchShimmer({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) => _UserSearchItemShimmer(delay: index * 100),
    );
  }
}

class _UserSearchItemShimmer extends StatelessWidget {
  final int delay;

  const _UserSearchItemShimmer({this.delay = 0});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.white.withValues(alpha: 0.05),
      highlightColor: kPurple.withValues(alpha: 0.15),
      period: Duration(milliseconds: 1500 + delay),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Avatar shimmer
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            // Content shimmer
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 10,
                    width: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            // Trailing icon shimmer
            Container(
              height: 24,
              width: 24,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full screen shimmer overlay for smooth transitions
class ChatScreenTransitionShimmer extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  final Duration fadeInDuration;
  final Duration fadeOutDuration;

  const ChatScreenTransitionShimmer({
    super.key,
    required this.child,
    required this.isLoading,
    this.fadeInDuration = const Duration(milliseconds: 200),
    this.fadeOutDuration = const Duration(milliseconds: 300),
  });

  @override
  State<ChatScreenTransitionShimmer> createState() =>
      _ChatScreenTransitionShimmerState();
}

class _ChatScreenTransitionShimmerState
    extends State<ChatScreenTransitionShimmer> {
  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      firstChild: widget.child,
      secondChild: _buildShimmerOverlay(),
      crossFadeState: widget.isLoading
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      duration: widget.isLoading
          ? widget.fadeInDuration
          : widget.fadeOutDuration,
      firstCurve: Curves.easeOut,
      secondCurve: Curves.easeIn,
    );
  }

  Widget _buildShimmerOverlay() {
    return Container(
      color: kDeepBlack.withValues(alpha: 0.95),
      child: const ChatListShimmer(),
    );
  }
}
