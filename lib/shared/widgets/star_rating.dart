import 'package:flutter/material.dart';

class StarRating extends StatelessWidget {
  final double rating; // 0.0 - 5.0
  final int? reviewCount;
  final bool compact;
  final Color color;
  final Color emptyColor;

  const StarRating({
    super.key,
    required this.rating,
    this.reviewCount,
    this.compact = false,
    this.color = const Color(0xFFFFD700), // gold-ish
    this.emptyColor = const Color(0x55FFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    final double size = compact ? 12 : 16;
    final double r = rating.clamp(0.0, 5.0);
    final double rounded = (r * 2).round() / 2.0; // nearest 0.5
    final int full = rounded.floor();
    final bool half = (rounded - full) >= 0.5 - 1e-9;
    final int empty = 5 - full - (half ? 1 : 0);

    final stars = <Widget>[
      for (int i = 0; i < full; i++) Icon(Icons.star_rounded, size: size, color: color),
      if (half) Icon(Icons.star_half_rounded, size: size, color: color),
      for (int i = 0; i < empty; i++) Icon(Icons.star_border_rounded, size: size, color: emptyColor),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: stars),
        if (reviewCount != null) ...[
          SizedBox(width: compact ? 4 : 6),
          Text(
            '(${reviewCount})',
            style: TextStyle(
              color: Colors.white70,
              fontSize: compact ? 11 : 12,
            ),
          ),
        ]
      ],
    );
  }
}
