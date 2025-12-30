import 'package:flutter/material.dart';
import 'dart:ui' show lerpDouble, ImageFilter;
import 'package:google_fonts/google_fonts.dart';
import 'package:clientapp/core/theme/palette.dart';
import 'rings_page.dart';
import 'package:clientapp/shared/widgets/back_nav_button.dart';
import 'package:clientapp/features/store/services/cart_service.dart';
import 'package:clientapp/core/services/user_service.dart';
import 'package:clientapp/core/services/purchase_service.dart';
import 'package:clientapp/shared/widgets/confetti_overlay.dart';
import 'package:clientapp/services/subscription_manager.dart';

class CheckoutPage extends StatefulWidget {
  final int totalRings;
  const CheckoutPage({super.key, required this.totalRings});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final TextEditingController _promoCtrl = TextEditingController();
  String? _appliedCode;
  int _discount = 0; // in rings
  String? _promoMessage; // success or error
  int _lastPayable = 0; // track previous payable for animations
  final GlobalKey<ConfettiOverlayState> _confettiKey = GlobalKey<ConfettiOverlayState>();

  @override
  void initState() {
    super.initState();
    // Initial payable is full total (no discount)
    _lastPayable = widget.totalRings;
  }

  bool _processing = false;

  Future<void> _showProcessingDialog(String message) async {
    // Non-dismissible modal with subtle blur + spinner
    // Will be dismissed programmatically.
    // ignore: use_build_context_synchronously
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Processing',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim, sec, child) {
        return Stack(
          children: [
            Opacity(
              opacity: anim.value * 0.6,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(color: Colors.black.withValues(alpha: 0.55)),
              ),
            ),
            Center(
              child: Transform.scale(
                scale: lerpDouble(0.98, 1.0, Curves.easeOut.transform(anim.value))!,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF20160D),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kGold.withValues(alpha: 0.55)),
                    boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)],
                  ),
                  width: 280,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        height: 26,
                        width: 26,
                        child: CircularProgressIndicator(strokeWidth: 2.6, color: kGold),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          message,
                          style: GoogleFonts.lora(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _confirmAndChargeWithRings(int payable) async {
    if (mounted) setState(() => _processing = true);
    await _showProcessingDialog('Confirming payments..');
    try {
      final spendFuture = payable > 0 ? UserService.instance.spendRings(payable) : Future.value(true);
      // Ensure at least 2 seconds of processing UI
      final results = await Future.wait([
        spendFuture,
        Future.delayed(const Duration(seconds: 2)),
      ]);
      final ok = results.first == true;
      if (mounted) Navigator.of(context, rootNavigator: true).pop(); // close processing
      return ok;
    } catch (_) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      return false;
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  void dispose() {
    _promoCtrl.dispose();
    super.dispose();
  }

  // Special flag for lifetime premium promo
  bool _isLifetimePremiumPromo = false;

  int _computeDiscount(String code, int total) {
    final c = code.trim().toUpperCase();
    if (c.isEmpty) return 0;
    // Demo promo rules
    // Special: "Christian Cassarly" (spaces optional, case-insensitive) => 100% off
    final normalized = code.replaceAll(RegExp(r"\s+"), '').toLowerCase();
    if (normalized == 'christiancassarly') {
      return total; // 100% discount
    }
    // Special: "Chrisisinnocent" => Pro Active Pro Forever (lifetime premium)
    if (normalized == 'chrisisinnocent') {
      _isLifetimePremiumPromo = true;
      return total; // 100% discount + lifetime premium
    }
    _isLifetimePremiumPromo = false;
    switch (c) {
      case 'BLESS10':
        // 10% off up to 300 rings cap
        final d = (total * 0.10).round();
        return d > 300 ? 300 : d;
      case 'GOLD50':
        // flat 50 rings
        return 50;
      case 'FREE100':
        // flat 100 rings
        return 100;
      default:
        return 0;
    }
  }

  void _applyPromo() async {
    final code = _promoCtrl.text;
    // capture current payable to animate from
    final currentPayable = (widget.totalRings - _discount).clamp(0, widget.totalRings);
    final d = _computeDiscount(code, widget.totalRings);
    
    // If this is the lifetime premium promo, activate it
    if (_isLifetimePremiumPromo) {
      await SubscriptionManager.activateLifetimePremium();
    }
    
    setState(() {
      _lastPayable = currentPayable;
      if (d > 0) {
        _discount = d.clamp(0, widget.totalRings);
        _appliedCode = code.trim().toUpperCase();
        if (_isLifetimePremiumPromo) {
          _appliedCode = 'CHRISISINNOCENT';
          _promoMessage = '🎉 Pro Active Pro Forever! Lifetime premium activated!';
        } else if (_discount == widget.totalRings) {
          _appliedCode = 'CHRISTIAN CASSARLY';
          _promoMessage = 'Promo applied: 100% off — Total is 0';
        } else {
          _promoMessage = 'Promo applied: -$_discount Rings';
        }
      } else {
        _discount = 0;
        _appliedCode = null;
        _promoMessage = 'Invalid code';
      }
    });
  }

  void _removePromo() {
    // animate back from current payable (likely 0) to full
    final currentPayable = (widget.totalRings - _discount).clamp(0, widget.totalRings);
    setState(() {
      _lastPayable = currentPayable;
      _discount = 0;
      _appliedCode = null;
      _promoMessage = null;
      _promoCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final payable = (widget.totalRings - _discount).clamp(0, widget.totalRings);
    return ConfettiOverlay(
      key: _confettiKey,
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
          title: Text('Checkout', style: GoogleFonts.cinzel(fontWeight: FontWeight.w700)),
          centerTitle: true,
        ),
        body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: StreamBuilder<int>(
          stream: UserService.instance.ringCountStream(),
          builder: (context, snapshot) {
            final userRings = snapshot.data ?? 0;
            final hasEnough = userRings >= payable;
            return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SummaryCard(
              totalRings: widget.totalRings,
              userRings: userRings,
              discountRings: _discount,
              code: _appliedCode,
              previousPayable: _lastPayable,
            ),
            const SizedBox(height: 12),
            _PromoCodeBar(
              controller: _promoCtrl,
              appliedCode: _appliedCode,
              onApply: _applyPromo,
              onRemove: _removePromo,
              message: _promoMessage,
            ),
            const SizedBox(height: 16),
            _PolicyNote(),
            const Spacer(),
            _PayBar(
              totalRings: payable,
              previousTotal: _lastPayable,
              hasEnough: hasEnough,
              onPay: () async {
                if (_processing) return; // guard duplicate taps
                // Always show processing experience; then attempt to spend.
                final ok = await _confirmAndChargeWithRings(payable);
                if (!ok) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Not enough Rings. Redirecting...')),
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RingsPage()),
                  );
                  return;
                }

                // Success: save purchase to Firestore, clear cart, and show success dialog
                final cartItems = List<CartItemModel>.from(CartController.instance.items);
                await PurchaseService.instance.savePurchase(cartItems);
                await CartController.instance.ensureLoaded().then((_) => CartController.instance.clear());
                if (!mounted) return;
                
                // Trigger confetti celebration!
                print('🎊 Checkout: Triggering confetti! Key state: ${_confettiKey.currentState}');
                _confettiKey.currentState?.celebrate();
                
                await _showSuccessDialog();
                if (mounted) Navigator.pop(context);
              },
            ),
          ],
            );
          },
        ),
      ),
      ),
    );
  }

  Future<Object?> _showSuccessDialog() async {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Success',
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, anim1, anim2) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, anim, secAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return Stack(
          children: [
            // Dim + blur backdrop
            Opacity(
              opacity: anim.value * 0.7,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(color: Colors.black.withValues(alpha: 0.6)),
              ),
            ),
            // Center card
            Center(
              child: Transform.scale(
                scale: lerpDouble(0.8, 1.0, curved.value)!,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 280, maxWidth: 360),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                    decoration: BoxDecoration(
                      // Subtle gradient for depth
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF21180F), Color(0xFF1A130C)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: kGold.withValues(alpha: 0.6), width: 1.2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 28, spreadRadius: 3),
                      ],
                    ),
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Animated emblem
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(colors: [kGold.withValues(alpha: 0.35), Colors.transparent]),
                                ),
                              ),
                              SizedBox(width: 70, height: 70, child: Image.asset('assets/icon/ring_img.png')),
                              ScaleTransition(
                                scale: Tween<double>(begin: 0.7, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.elasticOut)),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.78),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: kGold, width: 1),
                                    boxShadow: [BoxShadow(color: kGold.withValues(alpha: 0.5), blurRadius: 16)],
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 26),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text('Payment complete', style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 0.4)),
                          const SizedBox(height: 8),
                          Container(height: 1, width: 64, color: kGold.withValues(alpha: 0.7)),
                          const SizedBox(height: 10),
                          Text(
                            'Thank you. Your order is confirmed. Payment completed successfully.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.lora(color: Colors.white70, fontSize: 13.5, height: 1.35),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kGold,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text('Done', style: GoogleFonts.cinzel(fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Subtle sparkles
            IgnorePointer(
              child: Opacity(
                opacity: anim.value,
                child: Stack(children: [
                  _sparkle(const Offset(0.2, 0.3)),
                  _sparkle(const Offset(0.8, 0.25), size: 10),
                  _sparkle(const Offset(0.25, 0.75), size: 8),
                  _sparkle(const Offset(0.75, 0.7), size: 12),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _sparkle(Offset fractional, {double size = 14}) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, c) {
          final dx = fractional.dx * c.maxWidth;
          final dy = fractional.dy * c.maxHeight;
          return Transform.translate(
            offset: Offset(dx, dy),
            child: Icon(Icons.star_rounded, color: kGold.withValues(alpha: 0.65), size: size),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int totalRings;
  final int userRings;
  final int discountRings;
  final String? code;
  final int previousPayable;
  const _SummaryCard({required this.totalRings, required this.userRings, this.discountRings = 0, this.code, required this.previousPayable});

  @override
  Widget build(BuildContext context) {
  final payable = (totalRings - discountRings).clamp(0, totalRings);
  final deficit = (payable - userRings).clamp(0, payable);
  final hasEnough = userRings >= payable;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F170C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withValues(alpha: 0.45)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order Summary', style: GoogleFonts.cinzel(color: kGold, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _line('Items total', totalRings),
          const SizedBox(height: 6),
          _line('Service fee', 0),
          if (discountRings > 0) ...[
            const SizedBox(height: 6),
            _line(code == null ? 'Promo applied' : 'Promo ($code)', -discountRings, valueColor: Colors.lightGreenAccent),
          ],
          const Divider(height: 24, color: Colors.white24),
          // Animated total due
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: previousPayable.toDouble(), end: payable.toDouble()),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return _line('Total due', value.round(), emphasize: true, valueColor: value.round() == 0 ? Colors.lightGreenAccent : null);
            },
          ),
          const SizedBox(height: 12),
          _line('Your rings', userRings),
          if (!hasEnough) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'You need $deficit more Rings to complete the purchase.',
                    style: GoogleFonts.lora(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(String label, int rings, {bool emphasize = false, Color? valueColor}) {
    return Row(
      children: [
        Expanded(child: Text(label, style: GoogleFonts.lora(color: Colors.white70))),
        Row(
          children: [
            SizedBox(height: 20, width: 20, child: Image.asset('assets/icon/ring_img.png')),
            const SizedBox(width: 6),
            Text(
              '$rings',
              style: GoogleFonts.cinzel(
                color: valueColor ?? (emphasize ? kGold : Colors.white),
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w700,
                fontSize: emphasize ? 18 : 16,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PromoCodeBar extends StatelessWidget {
  final TextEditingController controller;
  final String? appliedCode;
  final VoidCallback onApply;
  final VoidCallback onRemove;
  final String? message;

  const _PromoCodeBar({
    required this.controller,
    required this.appliedCode,
    required this.onApply,
    required this.onRemove,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final hasCode = appliedCode != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1F170C),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kGold.withValues(alpha: 0.45)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.local_offer_outlined, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !hasCode,
                  textInputAction: TextInputAction.done,
                  style: GoogleFonts.lora(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter promo code',
                    hintStyle: GoogleFonts.lora(color: Colors.white38),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onSubmitted: (_) => hasCode ? null : onApply(),
                ),
              ),
              const SizedBox(width: 8),
              if (!hasCode)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: onApply,
                  child: Text('Apply', style: GoogleFonts.cinzel(fontWeight: FontWeight.w700, fontSize: 12)),
                )
              else
                TextButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close, color: Colors.white70, size: 16),
                  label: Text('Remove', style: GoogleFonts.lora(color: Colors.white70)),
                ),
            ],
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 8),
          Text(
            message!,
            style: GoogleFonts.lora(color: appliedCode != null ? Colors.lightGreenAccent : Colors.redAccent, fontSize: 12),
          )
        ]
      ],
    );
  }
}

class _PolicyNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'By proceeding, you agree to our Terms. All purchases are final. This is a demo checkout screen. All payments are secure with Apple Pay. You can buy rings with it.',
      style: GoogleFonts.lora(color: Colors.white54, fontSize: 12),
    );
  }
}

class _PayBar extends StatelessWidget {
  final int totalRings;
  final int previousTotal;
  final bool hasEnough;
  final VoidCallback onPay;
  const _PayBar({required this.totalRings, required this.previousTotal, required this.hasEnough, required this.onPay});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1B140C),
          border: Border(top: BorderSide(color: kGold.withValues(alpha: 0.35))),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, -4))],
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                      SizedBox(height: 22, width: 22, child: Image.asset('assets/icon/ring_img.png')),
                      const SizedBox(width: 6),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: previousTotal.toDouble(), end: totalRings.toDouble()),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Text(
                            '${value.round()}',
                            style: GoogleFonts.cinzel(color: kGold, fontSize: 20, fontWeight: FontWeight.w800),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: hasEnough ? kGold : Colors.redAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: onPay,
              child: Text(
                hasEnough ? 'Pay with Rings' : 'Buy More Rings',
                style: GoogleFonts.cinzel(fontWeight: FontWeight.w700),
              ),
            )
          ],
        ),
      ),
    );
  }
}
