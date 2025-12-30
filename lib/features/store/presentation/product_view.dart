import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui' show lerpDouble;
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:clientapp/core/theme/palette.dart';
import 'package:clientapp/shared/widgets/back_nav_button.dart';
import 'package:clientapp/shared/widgets/star_rating.dart';
import 'widgets/store_bottom_nav_bar.dart';
import 'package:clientapp/features/store/services/cart_service.dart';
// 'widgets/store_bottom_nav_bar.dart' already provides CartSwing
import 'package:clientapp/features/store/presentation/cart_page.dart';
import 'package:clientapp/features/store/presentation/checkout_page.dart';

/// Product details screen styled to match the Store UI.
///
/// Required fields: [title], [image] (asset or network), and [ringPrice].
/// Optional: [description].
class ProductViewPage extends StatefulWidget {
  final String productId; // Firestore product document ID
  final String title;
  final String image; // asset or network
  final double ringPrice;
  final String? description;
  final List<String>? images; // optional additional images (network or asset)

  const ProductViewPage({
    super.key,
    required this.productId,
    required this.title,
    required this.image,
    required this.ringPrice,
    this.description,
    this.images,
  });

  @override
  State<ProductViewPage> createState() => _ProductViewPageState();
}

class _ProductViewPageState extends State<ProductViewPage>
    with SingleTickerProviderStateMixin {
  int _qty = 1;
  bool _added = false;
  final GlobalKey _imageKey = GlobalKey();
  final GlobalKey _cartKey = GlobalKey();
  int _imageIndex = 0; // selected image index for gallery
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.9,
      initialPage: _imageIndex,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF130E0A),
      appBar: _buildAppBar(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        children: [
          Builder(
            builder: (context) {
              final imgs = (widget.images != null && widget.images!.isNotEmpty)
                  ? widget.images!
                  : <String>[widget.image];

              // Carousel slider with subtle center-scale effect
              Widget slider = AspectRatio(
                aspectRatio: 1,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: imgs.length,
                  onPageChanged: (i) => setState(() => _imageIndex = i),
                  itemBuilder: (context, i) {
                    return AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, child) {
                        double t = 0;
                        if (_pageController.hasClients &&
                            _pageController.position.haveDimensions) {
                          final page =
                              _pageController.page ?? _imageIndex.toDouble();
                          t = (1 - (page - i).abs()).clamp(0.0, 1.0);
                        } else {
                          t = (i == _imageIndex) ? 1.0 : 0.0;
                        }
                        final scale = lerpDouble(
                          0.94,
                          1.0,
                          Curves.easeOut.transform(t),
                        )!;
                        final elevation = lerpDouble(0, 8, t)!;
                        return Center(
                          child: Transform.scale(
                            scale: scale,
                            child: Material(
                              color: Colors.transparent,
                              elevation: elevation,
                              borderRadius: BorderRadius.circular(20),
                              child: _ImageCard(
                                title: widget.title,
                                image: imgs[i],
                                // Attach the key only to the currently visible card so the fly-to-cart starts here
                                targetKey: (i == _imageIndex)
                                    ? _imageKey
                                    : null,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              );

              return Column(
                children: [
                  slider,
                  if (imgs.length > 1) ...[
                    const SizedBox(height: 10),
                    _ThumbnailsBar(
                      images: imgs,
                      selectedIndex: _imageIndex,
                      onSelect: (i) {
                        setState(() => _imageIndex = i);
                        _pageController.animateToPage(
                          i,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOut,
                        );
                      },
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          _TitleAndPrice(
            title: widget.title,
            price: widget.ringPrice,
            qty: _qty,
          ),
          const SizedBox(height: 16),
          const _GoldDivider(),
          const SizedBox(height: 12),
          _QuantitySelector(
            value: _qty,
            onChanged: (v) => setState(() => _qty = v.clamp(1, 999999)),
          ),
          const SizedBox(height: 14),
          _ActionButtons(
            added: _added,
            onBuy: () => _onBuyNow(),
            onAdd: _onAddToCart,
          ),
          const SizedBox(height: 16),
          _DescriptionSection(text: widget.description ?? _lorem),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leadingWidth: 60,
      leading: const Padding(
        padding: EdgeInsets.only(left: 6),
        child: BackNavButton(),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _AppBarCartIcon(key: _cartKey),
        ),
      ],
    );
  }

  Future<void> _onAddToCart() async {
    await _runFlyToCartAnimation();
    // Persist to cart
    await CartController.instance.addItem(
      CartItemModel(
        productId: widget.productId,
        title: widget.title,
        image: widget.image,
        price: widget.ringPrice,
        qty: _qty,
      ),
    );
    // trigger cart icon swing
    CartSwing.swing(_cartKey);
    if (mounted) {
      setState(() => _added = true);
    }
  }

  Future<void> _onBuyNow() async {
    // Add item to cart temporarily for checkout
    final item = CartItemModel(
      productId: widget.productId,
      title: widget.title,
      image: widget.image,
      price: widget.ringPrice,
      qty: _qty,
    );

    // Clear cart and add only this item for single-item checkout
    await CartController.instance.ensureLoaded();
    await CartController.instance.clear();
    await CartController.instance.addItem(item);

    // Navigate to checkout
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CheckoutPage(totalRings: (widget.ringPrice * _qty).round()),
      ),
    );

    // After returning from checkout, reload cart state
    if (mounted) {
      await CartController.instance.ensureLoaded();
    }
  }

  Future<void> _runFlyToCartAnimation() async {
    final overlay = Overlay.of(context);

    final startBox = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    final endBox = _cartKey.currentContext?.findRenderObject() as RenderBox?;
    if (startBox == null || endBox == null) return;

    final start = startBox.localToGlobal(startBox.size.center(Offset.zero));
    final end = endBox.localToGlobal(endBox.size.center(Offset.zero));

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    final curve = CurvedAnimation(
      parent: controller,
      curve: Curves.fastOutSlowIn,
    );

    // Quadratic bezier control point for a smooth arc
    final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
    double arcHeight = (end - start).distance * 0.25;
    if (arcHeight < 60) arcHeight = 60;
    if (arcHeight > 140) arcHeight = 140;
    final horizontalSign = (end.dx - start.dx) >= 0 ? 1.0 : -1.0;
    final control = Offset(mid.dx + 30 * horizontalSign, mid.dy - arcHeight);

    Offset _quad(Offset p0, Offset p1, Offset p2, double t) {
      final mt = 1 - t;
      final x = mt * mt * p0.dx + 2 * mt * t * p1.dx + t * t * p2.dx;
      final y = mt * mt * p0.dy + 2 * mt * t * p1.dy + t * t * p2.dy;
      return Offset(x, y);
    }

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        final t = curve.value;
        final pos = _quad(start, control, end, t);
        final easeScale = Curves.easeInOut.transform(t);
        final scale = lerpDouble(1.0, 0.25, easeScale)!;
        final fadeT = t <= 0.75 ? 0.0 : (t - 0.75) / 0.25;
        final opacity = 1.0 - Curves.easeIn.transform(fadeT.clamp(0.0, 1.0));
        final rotate =
            (t * (1 - t)) * 0.6 * horizontalSign; // peak rotation mid-flight
        return Positioned(
          left: pos.dx - 24,
          top: pos.dy - 24,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Transform.rotate(
                angle: rotate,
                child: _MiniImage(image: widget.image),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);
    controller.addListener(() => entry.markNeedsBuild());
    final completer = Completer<void>();
    controller.addStatusListener((status) async {
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

class _ThumbnailsBar extends StatelessWidget {
  final List<String> images;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  const _ThumbnailsBar({
    required this.images,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final img = images[i];
          final isSelected = i == selectedIndex;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? kGold : kGold.withValues(alpha: 0.35),
                  width: isSelected ? 2 : 1.2,
                ),
                boxShadow: isSelected
                    ? [
                        const BoxShadow(
                          color: Colors.black54,
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ]
                    : const [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: img.startsWith('http')
                    ? CachedNetworkImage(
                        imageUrl: img,
                        fit: BoxFit.cover,
                        placeholder: (c, _) =>
                            Container(color: const Color(0x221F170C)),
                        errorWidget: (c, _, __) => const Icon(
                          Icons.broken_image,
                          color: Colors.white54,
                        ),
                      )
                    : Image.asset(img, fit: BoxFit.cover),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MiniImage extends StatelessWidget {
  final String image;
  const _MiniImage({required this.image});

  @override
  Widget build(BuildContext context) {
    final Widget img = image.startsWith('http')
        ? CachedNetworkImage(
            imageUrl: image,
            fit: BoxFit.cover,
            placeholder: (c, _) => Container(color: const Color(0x221F170C)),
            errorWidget: (c, _, __) =>
                const Icon(Icons.broken_image, color: Colors.white54),
          )
        : Image.asset(image, fit: BoxFit.cover);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: 48, height: 48, child: img),
    );
  }
}

class _ImageCard extends StatelessWidget {
  final String title;
  final String image;
  final Key? targetKey;
  const _ImageCard({required this.title, required this.image, this.targetKey});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: image + title,
              child: Container(
                key: targetKey,
                child: image.startsWith('http')
                    ? CachedNetworkImage(
                        imageUrl: image,
                        fit: BoxFit.cover,
                        placeholder: (c, _) =>
                            Container(color: const Color(0x221F170C)),
                        errorWidget: (c, _, __) => const Icon(
                          Icons.broken_image,
                          color: Colors.white54,
                        ),
                      )
                    : Image.asset(image, fit: BoxFit.cover),
              ),
            ),
            // Thin gold border line with rounded corners on top of the image
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: kGold.withValues(alpha: 0.7),
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleAndPrice extends StatelessWidget {
  final String title;
  final double price;
  final int qty;
  const _TitleAndPrice({
    required this.title,
    required this.price,
    required this.qty,
  });

  String _format(double v) => v.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: GoogleFonts.cinzel(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/icon/ring_img.png', width: 24, height: 24),
            const SizedBox(width: 12),
            Text(
              '${_format(price)} Rings',
              style: GoogleFonts.lora(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: kGold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Demo rating on product detail
        const StarRating(rating: 4.6, reviewCount: 212),
        if (qty > 1) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '× $qty = ',
                style: GoogleFonts.lora(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${_format(price * qty)} Rings',
                style: GoogleFonts.lora(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: kGold,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _GoldDivider extends StatelessWidget {
  const _GoldDivider();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1.2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            kGold.withValues(alpha: 0.7),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _QuantitySelector extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _QuantitySelector({required this.value, required this.onChanged});

  @override
  State<_QuantitySelector> createState() => _QuantitySelectorState();
}

class _QuantitySelectorState extends State<_QuantitySelector> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(covariant _QuantitySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _parseController() != widget.value) {
      _controller.text = widget.value.toString();
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  int _parseController() {
    final txt = _controller.text.trim();
    final n = int.tryParse(txt) ?? widget.value;
    return n;
  }

  void _commitFromField() {
    int n = _parseController().clamp(1, 999999);
    if (n != widget.value) widget.onChanged(n);
    if (_controller.text != n.toString()) {
      setState(() => _controller.text = n.toString());
    }
  }

  void _changeBy(int delta) {
    final n = (widget.value + delta).clamp(1, 999999);
    widget.onChanged(n);
    if (_controller.text != n.toString()) {
      setState(() => _controller.text = n.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1F170C),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kGold.withValues(alpha: 0.45)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _QtyBtn(icon: Icons.remove, onTap: () => _changeBy(-1)),
                const SizedBox(width: 2),
                Focus(
                  onFocusChange: (hasFocus) {
                    if (!hasFocus) _commitFromField();
                    setState(() {}); // refresh focus styling
                  },
                  child: GestureDetector(
                    onTap: () {
                      _focusNode.requestFocus();
                      _controller.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _controller.text.length,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      width: 82,
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF261C10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _focusNode.hasFocus
                              ? kGold
                              : kGold.withValues(alpha: 0.35),
                          width: _focusNode.hasFocus ? 1.6 : 1.0,
                        ),
                      ),
                      child: Center(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          cursorColor: kGold,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cinzel(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            signed: false,
                            decimal: false,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                            border: InputBorder.none,
                            hintText: 'Qty',
                            hintStyle: GoogleFonts.lora(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                          onSubmitted: (_) => _commitFromField(),
                          onEditingComplete: _commitFromField,
                          onChanged: (txt) {
                            // Live clamp on change to keep 1-999999, but don't fire callback too often
                            final v = int.tryParse(txt);
                            if (v == null) return; // allow empty while typing
                            int clamped = v.clamp(1, 999999);

                            // Update parent immediately to reflect total price
                            if (clamped != widget.value) {
                              widget.onChanged(clamped);
                            }

                            if (clamped.toString() != txt) {
                              // Replace with clamped text preserving caret at end
                              _controller.text = clamped.toString();
                              _controller
                                  .selection = TextSelection.fromPosition(
                                TextPosition(offset: _controller.text.length),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                _QtyBtn(icon: Icons.add, onTap: () => _changeBy(1)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap to type quantity',
            style: GoogleFonts.lora(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 42,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: kGold),
      ),
    );
  }
}

class _AppBarCartIcon extends StatefulWidget {
  const _AppBarCartIcon({super.key});

  @override
  State<_AppBarCartIcon> createState() => _AppBarCartIconState();
}

class _AppBarCartIconState extends State<_AppBarCartIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _angle;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _angle = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.35), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.35, end: -0.25), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.25, end: 0.15), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.15, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 0.25),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 0.25),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 0.5),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    // Load cart state so the badge reflects current count
    CartController.instance.ensureLoaded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.key is GlobalKey) {
      CartSwing.register(widget.key as GlobalKey, _swing);
    }
  }

  @override
  void dispose() {
    if (widget.key is GlobalKey) {
      CartSwing.unregister(widget.key as GlobalKey);
    }
    _controller.dispose();
    super.dispose();
  }

  void _swing() {
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const CartPage())),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (_, child) => Transform.rotate(
                angle: _angle.value,
                alignment: Alignment.topCenter,
                child: Transform.scale(scale: _scale.value, child: child),
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                color: Colors.white,
              ),
            ),
            // Cart count badge
            Positioned(
              right: -2,
              top: -2,
              child: AnimatedBuilder(
                animation: CartController.instance,
                builder: (context, _) {
                  final count = CartController.instance.itemCount;
                  if (count <= 0) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: kGold,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(minWidth: 16),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final VoidCallback onBuy;
  final VoidCallback onAdd;
  final bool added;
  const _ActionButtons({
    required this.onBuy,
    required this.onAdd,
    required this.added,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kGold,
              foregroundColor: kDeepBlack,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () {
              FocusScope.of(context).unfocus();
              onBuy();
            },
            child: Text(
              'Checkout',
              style: GoogleFonts.cinzel(
                color: kDeepBlack,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F170C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: kGold.withValues(alpha: 0.45)),
              ),
            ),
            onPressed: added
                ? null
                : () {
                    FocusScope.of(context).unfocus();
                    onAdd();
                  },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: Text(
                added ? 'Added to Cart' : 'Add to Cart',
                key: ValueKey(added),
                style: GoogleFonts.cinzel(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DescriptionSection extends StatelessWidget {
  final String text;
  const _DescriptionSection({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F170C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Text(
          text,
          style: GoogleFonts.lora(
            color: Colors.white70,
            height: 1.35,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }
}

// Reviews section removed per request

const _lorem =
    'An artisan blend of sanctified botanicals suspended in luminous oil. Apply during meditations to enhance focus and serenity. Distilled under the third moon by the temple alchemists.';
