import 'package:flutter/material.dart';
import 'package:clientapp/core/theme/palette.dart';

/// A serene, classic background using deep neutrals with a subtle gold tint.
/// Minimal or no motion for a calm feel.
class CalmBackground extends StatelessWidget {
  final Widget? child;
  final Color accent;
  const CalmBackground({super.key, this.child, required this.accent});

  @override
  Widget build(BuildContext context) {
    // Blend the tab's accent into a deep charcoal/royal base.
    // Slightly increase the contribution so tabs look clearly different.
    final softTint = Color.lerp(kRoyalBlue, accent, 0.16)!;
    return Stack(
      children: [
        // Base gradient: deep to slightly tinted
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                kDeepBlack,
                Color.lerp(kDeepBlack, softTint, 0.5)!,
              ],
            ),
          ),
        ),
        // Gentle radial glow (very subtle) near top center
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, -0.5),
                radius: 1.1,
                colors: [
                  accent.withValues(alpha: 0.09),
                  Colors.transparent,
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        ),
        // Soft vignette to keep focus center
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, -0.1),
                radius: 1.25,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.4),
                ],
                stops: const [0.65, 1.0],
              ),
            ),
          ),
        ),
        if (child != null) child!,
      ],
    );
  }
}
