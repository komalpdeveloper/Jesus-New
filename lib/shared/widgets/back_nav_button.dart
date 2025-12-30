import 'package:flutter/material.dart';
import 'package:clientapp/core/theme/palette.dart';

/// Reusable back navigation button using the custom back icon asset.
/// Usage: place in AppBar.leading with optional outer padding.
class BackNavButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final double iconSize;
  final EdgeInsetsGeometry padding;
  final String tooltip;

  const BackNavButton({super.key, this.onPressed, this.iconSize = 22, this.padding = const EdgeInsets.symmetric(horizontal: 10), this.tooltip = 'Back'});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: kGold,
        padding: padding,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed ?? () => Navigator.maybePop(context),
      child: Tooltip(
        message: tooltip,
        child: Image.asset(
          'assets/icon/back_icon.png',
          width: iconSize,
          height: iconSize,
          // color: kGold,
        ),
      ),
    );
  }
}
