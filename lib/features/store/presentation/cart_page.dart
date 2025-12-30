import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:clientapp/core/theme/palette.dart';
import 'package:flutter/services.dart';
import 'rings_page.dart';
import 'widgets/apple_pay_button.dart';
import 'checkout_page.dart';
import 'package:clientapp/shared/widgets/back_nav_button.dart';
import 'package:clientapp/features/store/services/cart_service.dart';
import 'package:clientapp/core/services/user_service.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final cart = CartController.instance;

  @override
  void initState() {
    super.initState();
    cart.addListener(_onCart);
    // ensure load happens and rebuild
    cart.ensureLoaded();
  }

  @override
  void dispose() {
    cart.removeListener(_onCart);
    super.dispose();
  }

  void _onCart() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final isEmpty = cart.items.isEmpty;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFF130E0A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leadingWidth: 60,
          leading: const Padding(
            padding: EdgeInsets.only(left: 6),
            child: BackNavButton(),
          ),
          title: Text(
            'Cart',
            style: GoogleFonts.cinzel(fontWeight: FontWeight.w700),
          ),
          centerTitle: true,
          actions: const [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: _RingStatus(compact: true),
            ),
            SizedBox(width: 4),
          ],
        ),
        body: isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 80,
                      color: Colors.white24,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your cart is empty',
                      style: GoogleFonts.cinzel(
                        color: Colors.white54,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add items to get started',
                      style: GoogleFonts.lora(
                        color: Colors.white38,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
                itemCount: cart.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _CartTile(
                  item: cart.items[i],
                  onInc: () => cart.incrementAt(i),
                  onDec: () => cart.decrementAt(i),
                  onRemove: () => cart.removeAt(i),
                  onSet: (q) => cart.setQtyAt(i, q),
                ),
              ),
        bottomNavigationBar: isEmpty
            ? null
            : _BottomBar(totalRings: cart.totalRings),
      ),
    );
  }
}

class _CartTile extends StatelessWidget {
  final CartItemModel item;
  final VoidCallback onInc;
  final VoidCallback onDec;
  final VoidCallback onRemove;
  final ValueChanged<int> onSet;
  const _CartTile({
    required this.item,
    required this.onInc,
    required this.onDec,
    required this.onRemove,
    required this.onSet,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1F170C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kGold.withValues(alpha: 0.35)),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: (item.image.startsWith('http')
                    ? CachedNetworkImage(
                        imageUrl: item.image,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        placeholder: (c, _) =>
                            Container(color: const Color(0x221F170C)),
                        errorWidget: (c, _, __) => const Icon(
                          Icons.broken_image,
                          size: 18,
                          color: Colors.white54,
                        ),
                      )
                    : Image.asset(
                        item.image,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      )),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.lora(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        SizedBox(
                          height: 18,
                          width: 18,
                          child: Image.asset('assets/icon/ring_img.png'),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${item.price.toStringAsFixed(0)}',
                          style: GoogleFonts.cinzel(
                            color: kGold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _QtyStepper(
                qty: item.qty,
                onDec: onDec,
                onInc: onInc,
                onSet: onSet,
              ),
            ],
          ),
        ),
        Positioned(
          top: 2,
          right: 4,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white70, size: 15),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QtyStepper extends StatefulWidget {
  final int qty;
  final VoidCallback onDec;
  final VoidCallback onInc;
  final ValueChanged<int> onSet;
  const _QtyStepper({
    required this.qty,
    required this.onDec,
    required this.onInc,
    required this.onSet,
  });

  @override
  State<_QtyStepper> createState() => _QtyStepperState();
}

class _QtyStepperState extends State<_QtyStepper> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.qty.toString());
  }

  @override
  void didUpdateWidget(covariant _QtyStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.qty != widget.qty) {
      final currentVal = int.tryParse(_controller.text);
      if (currentVal != widget.qty) {
        _controller.text = widget.qty.toString();
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // We need access to the index to call setQtyAt. We'll use an Inherited approach here by tapping into the cart page's list builder via a callback.
    // Instead, in this scope, we will use the onInc/onDec for buttons and for manual edit we'll compute delta and call those appropriately is fragile.
    // Better: expose a direct setter via an inherited or pass a setter callback. We'll add an optional onSet callback on the parent call site.
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A1E10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGold.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          _QtyBtn(icon: Icons.remove, onTap: widget.onDec),
          GestureDetector(
            onTap: () {
              _focusNode.requestFocus();
              _controller.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _controller.text.length,
              );
            },
            child: Container(
              width: 60,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Focus(
                onFocusChange: (hasFocus) async {
                  if (!hasFocus) {
                    final n = int.tryParse(_controller.text) ?? widget.qty;
                    final clamped = n.clamp(1, 999999);
                    if (clamped != widget.qty) {
                      widget.onSet(clamped);
                    }
                    if (_controller.text != clamped.toString()) {
                      setState(() => _controller.text = clamped.toString());
                    }
                  }
                },
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  cursorColor: kGold,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cinzel(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  textInputAction: TextInputAction.done,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: false,
                    decimal: false,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 6),
                  ),
                  onSubmitted: (_) => _focusNode.unfocus(),
                  onChanged: (txt) {
                    final v = int.tryParse(txt);
                    if (v == null) return;
                    final clamped = v.clamp(1, 999999);

                    // Update parent immediately
                    if (clamped != widget.qty) {
                      widget.onSet(clamped);
                    }

                    if (clamped.toString() != txt) {
                      _controller.text = clamped.toString();
                      _controller.selection = TextSelection.fromPosition(
                        TextPosition(offset: _controller.text.length),
                      );
                    }
                  },
                ),
              ),
            ),
          ),
          _QtyBtn(icon: Icons.add, onTap: widget.onInc),
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
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF1F170C),
        ),
        child: Icon(icon, size: 18, color: kGold),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int totalRings;
  const _BottomBar({required this.totalRings});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B140C),
        border: Border(top: BorderSide(color: kGold.withValues(alpha: 0.35))),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Total', style: GoogleFonts.lora(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      SizedBox(
                        height: 22,
                        width: 22,
                        child: Image.asset('assets/icon/ring_img.png'),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$totalRings',
                        style: GoogleFonts.cinzel(
                          color: kGold,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CheckoutPage(totalRings: totalRings),
                  ),
                );
              },
              child: Text(
                'Checkout',
                style: GoogleFonts.cinzel(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// _CartItem removed; using CartItemModel from cart_service.dart

class _RingStatus extends StatelessWidget {
  final bool compact;
  const _RingStatus({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final ringSize = compact ? 28.0 : 35.0;
    final valueFont = compact ? 15.0 : 18.0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: kRoyalBlue.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kGold.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: kGold.withValues(alpha: 0.35),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: SizedBox(
              height: ringSize + (compact ? 2 : 4),
              width: ringSize + (compact ? 2 : 4),
              child: Image.asset('assets/icon/ring_img.png'),
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!compact)
                Text(
                  'Rings',
                  style: GoogleFonts.cinzel(
                    fontSize: 11,
                    color: Colors.white70,
                    letterSpacing: 1,
                  ),
                ),
              Row(
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RingsPage()),
                      );
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 2,
                      ),
                      child: StreamBuilder<int>(
                        stream: UserService.instance.ringCountStream(),
                        builder: (context, snapshot) {
                          final rings = snapshot.data ?? 0;
                          return Text(
                            '$rings',
                            style: GoogleFonts.cinzel(
                              fontSize: valueFont,
                              fontWeight: FontWeight.w700,
                              color: kGold,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  ApplePayMiniButton(
                    compact: true,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RingsPage()),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
