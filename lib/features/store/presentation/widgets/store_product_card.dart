import 'package:flutter/material.dart';
import 'dart:ui' show lerpDouble;
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:clientapp/core/theme/palette.dart';
import 'package:clientapp/shared/widgets/star_rating.dart';
import 'package:clientapp/features/store/services/cart_service.dart';
import 'package:clientapp/features/store/presentation/widgets/store_bottom_nav_bar.dart' show CartSwing;
import 'package:cached_network_image/cached_network_image.dart';

class StoreProductCard extends StatefulWidget {
  final String productId; // Firestore product document ID
  final String title;
  final String image; // asset or network
  final double price;
  final bool isOnSale;
  final double? originalPrice;
  final double? rating; // 0..5
  final int? reviewCount;
  final GlobalKey cartKey;
  final VoidCallback? onTap; // navigate to product view
  final VoidCallback? onCartBump; // optional callback to swing cart icon

  const StoreProductCard({
    super.key,
    required this.productId,
    required this.title,
    required this.image,
    required this.price,
    this.isOnSale = false,
    this.originalPrice,
    this.rating,
    this.reviewCount,
    required this.cartKey,
    this.onTap,
    this.onCartBump,
  });

  @override
  State<StoreProductCard> createState() => _StoreProductCardState();
}

class _StoreProductCardState extends State<StoreProductCard> with SingleTickerProviderStateMixin {
  final GlobalKey _imageKey = GlobalKey();
  bool _added = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F170C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kGold.withValues(alpha: 0.45), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Colors.black87, blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: widget.onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: _buildImage()),
                    if (widget.isOnSale && widget.originalPrice != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: kRed.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'SALE',
                            style: GoogleFonts.lora(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xE61F170C),
                      Color(0xF21F170C),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lora(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                        color: Colors.white,
                      ),
                    ),
                    if (widget.rating != null) ...[
                      const SizedBox(height: 6),
                      StarRating(
                        rating: widget.rating!.toDouble(),
                        reviewCount: widget.reviewCount,
                        compact: true,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (widget.isOnSale && widget.originalPrice != null) ...[
                          _ringValue(
                            widget.originalPrice!,
                            strikeThrough: true,
                            compact: true,
                          ),
                          const SizedBox(width: 8),
                        ],
                        _ringValue(widget.price, strikeThrough: false),
                        const Spacer(),
                        _AddButton(
                          added: _added,
                          onPressed: _added ? null : () async {
                            await _runFlyToCartAnimation();
                            // persist in cart
                            await CartController.instance.addItem(
                              CartItemModel(productId: widget.productId, title: widget.title, image: widget.image, price: widget.price, qty: 1),
                            );
                            // notify cart icon to bump/swing
                            // The bottom nav registers its state under this key
                            // ignore: invalid_use_of_visible_for_testing_member
                            // ignore: invalid_use_of_protected_member
                            // Directly access registry to trigger swing
                            // (keeps API minimal without global provider)
                            // Using dynamic import to avoid circular dep isn't needed here.
                            // We rely on the cartKey that was passed down from shell.
                            // ignore: unused_result
                            CartSwing.swing(widget.cartKey);
                            if (mounted) setState(() => _added = true);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    final isNetwork = widget.image.startsWith('http');
  final img = isNetwork
    ? CachedNetworkImage(
      imageUrl: widget.image,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (c, _) => Container(color: const Color(0x221F170C)),
      errorWidget: (c, _, __) => const Icon(Icons.broken_image, color: Colors.white54),
      )
    : Image.asset(widget.image, fit: BoxFit.cover);
    return Hero(
      tag: widget.image + widget.title,
      child: Container(key: _imageKey, child: img),
    );
  }

  // Format rings as an integer-like value (store uses rings, not currency)
  String _formatRings(double v) => v.toStringAsFixed(0);

  // Small helper to render a ring icon next to its numeric value.
  // If strikeThrough is true, the value text will be struck out (used for old price on sale).
  Widget _ringValue(
    double value, {
    bool strikeThrough = false,
    bool compact = false,
  }) {
    final iconSize = compact ? 14.0 : 18.0;
    final fontSize = compact ? 12.0 : 16.0;
    final color = strikeThrough ? Colors.white70 : kGold;
    final fontWeight = strikeThrough ? FontWeight.w500 : FontWeight.w800;
    final lineThickness = compact ? 1.6 : 2.0;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Use the provided ring icon asset
        Image.asset(
          'assets/icon/ring_img.png',
          width: iconSize,
          height: iconSize,
          filterQuality: FilterQuality.high,
        ),
        const SizedBox(width: 4),
        Text(
          _formatRings(value),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: color,
            decoration: strikeThrough ? TextDecoration.lineThrough : TextDecoration.none,
            decorationColor: color,
            letterSpacing: strikeThrough ? 0.2 : 0.4,
          ),
        ),
      ],
    );

    if (!strikeThrough) return content;

    // When striking through, draw a clear cut line across both the icon and the text
    // so it's visually obvious the old price is discounted.
    return Stack(
      alignment: Alignment.center,
      children: [
        content,
        // Horizontal cut line across the entire row width
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: Alignment.center,
              child: Container(
                height: lineThickness,
                width: double.infinity,
                color: kRed.withValues(alpha: 0.9),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool added;
  const _AddButton({this.onPressed, this.added = false});

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        _controller.forward(from: 0);
        widget.onPressed?.call();
      },
      child: ScaleTransition(
        scale: Tween(begin: 1.0, end: 1.15).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
        ),
        child: Container(

          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: kGold,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kGold.withValues(alpha: 0.65), width: 1),
          ),
          child: Icon(widget.added ? Icons.done : Icons.add, size: 18, color: kDeepBlack),
        ),
      ),
    );
  }
}

// Helper: small image used during fly-to-cart animation
class _MiniImage extends StatelessWidget {
  final String image;
  const _MiniImage(this.image);
  @override
  Widget build(BuildContext context) {
    final isNetwork = image.startsWith('http');
  final img = isNetwork
    ? CachedNetworkImage(
      imageUrl: image,
      fit: BoxFit.cover,
      placeholder: (c, _) => Container(color: const Color(0x221F170C)),
      errorWidget: (c, _, __) => const Icon(Icons.broken_image, size: 16, color: Colors.white54),
      )
    : Image.asset(image, fit: BoxFit.cover);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: 40, height: 40, child: img),
    );
  }
}

extension on _StoreProductCardState {
  Future<void> _runFlyToCartAnimation() async {
  final overlay = Overlay.of(context);

    final startBox = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    final endBox = widget.cartKey.currentContext?.findRenderObject() as RenderBox?;
    if (startBox == null || endBox == null) return;

    final start = startBox.localToGlobal(startBox.size.center(Offset.zero));
    final end = endBox.localToGlobal(endBox.size.center(Offset.zero));

    final controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    final curve = CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn);

    final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
    double arcHeight = (end - start).distance * 0.25;
    arcHeight = arcHeight.clamp(50, 120);
    final horizontalSign = (end.dx - start.dx) >= 0 ? 1.0 : -1.0;
    final control = Offset(mid.dx + 24 * horizontalSign, mid.dy - arcHeight);

    Offset _quad(Offset p0, Offset p1, Offset p2, double t) {
      final mt = 1 - t;
      final x = mt * mt * p0.dx + 2 * mt * t * p1.dx + t * t * p2.dx;
      final y = mt * mt * p0.dy + 2 * mt * t * p1.dy + t * t * p2.dy;
      return Offset(x, y);
    }

    late OverlayEntry entry;
    entry = OverlayEntry(builder: (context) {
      final t = curve.value;
      final pos = _quad(start, control, end, t);
      final s = lerpDouble(1.0, 0.3, Curves.easeInOut.transform(t))!;
      final fadeT = t <= 0.8 ? 0.0 : (t - 0.8) / 0.2;
      final opacity = 1.0 - Curves.easeIn.transform(fadeT.clamp(0.0, 1.0));
      final rotate = (t * (1 - t)) * 0.5 * horizontalSign;
      return Positioned(
        left: pos.dx - 20,
        top: pos.dy - 20,
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: s,
            child: Transform.rotate(
              angle: rotate,
              child: _MiniImage(widget.image),
            ),
          ),
        ),
      );
    });

    overlay.insert(entry);
    controller.addListener(() => entry.markNeedsBuild());
    final completer = Completer<void>();
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        entry.remove();
        controller.dispose();
        completer.complete();
      }
    });
    controller.forward();
    await completer.future;
  }
}
