import 'package:flutter/material.dart';

/// A tiny, AppBar-friendly Apple Pay style button.
///
/// This is a visual-only pill button that reads "Apple Pay" with a
/// credit-card icon. It does not integrate real Apple Pay.
/// Use [onPressed] to navigate to your top-up/purchase flow.
class ApplePayMiniButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool compact;

  const ApplePayMiniButton({super.key, required this.onPressed, this.compact = true});

  @override
  Widget build(BuildContext context) {
  final double height = compact ? 26 : 30;
  final EdgeInsets padding = EdgeInsets.symmetric(horizontal: compact ? 3 : 6,vertical: compact ? 2 : 2);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(height / 2),
        child: Container(
          height: height,
          constraints: const BoxConstraints(minWidth: 35),
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(color: Colors.white.withOpacity(0.22), width: 0.8),
          ),
          child: Image.asset(
            'assets/icon/apple_pay.png',
            height: compact ? 14 : 16,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
