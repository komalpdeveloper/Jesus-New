import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:clientapp/core/theme/palette.dart';
import 'package:clientapp/shared/widgets/cosmic_background.dart';
import 'package:clientapp/services/subscription_manager.dart';
import 'package:clientapp/main.dart' show MainNav;
import 'dart:ui';
import 'package:shimmer/shimmer.dart';

class PaywallScreen extends StatefulWidget {
  final bool isTopUpMode;
  const PaywallScreen({super.key, this.isTopUpMode = false});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen>
    with SingleTickerProviderStateMixin {
  Offerings? _offerings;

  String? _loadingStatus; // Overlay status text (null means no overlay)
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Promo code state
  final TextEditingController _promoController = TextEditingController();
  String? _promoMessage;
  bool _promoSuccess = false;
  bool _showPromoField = false;

  // TopUp product ID - ensure this matches RevenueCat
  static const String _topUpProductId = 'chat_topup_250';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutQuad),
        );

    _fetchOfferings();
  }

  @override
  void dispose() {
    _animController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _fetchOfferings() async {
    try {
      Offerings offerings = await Purchases.getOfferings();
      if (mounted) {
        setState(() {
          _offerings = offerings;
        });
        _animController.forward();
      }
    } on PlatformException catch (e) {
      debugPrint('Error fetching offerings: $e');
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _purchasePackage(Package package) async {
    setState(() => _loadingStatus = "Processing Payment...");
    try {
      CustomerInfo customerInfo = await Purchases.purchasePackage(package);
      if (customerInfo.entitlements.all['premium_access']?.isActive == true) {
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Purchase failed: ${e.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _loadingStatus = null);
      }
    }
  }

  Future<void> _purchaseTopUp() async {
    // Since top-ups might be consumables not in the main offering, we might need to fetch products directly or look for a specific package in offerings.
    // For simplicity, let's try to find a package with the ID first.

    // Assuming 'chat_topup_250' is configured in RevenueCat and attached to an offering or available as a product.
    // We will list products.

    setState(() => _loadingStatus = "Loading Top-Up...");

    try {
      final products = await Purchases.getProducts([_topUpProductId]);
      if (products.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Top-up currently unavailable.')),
          );
        }
        return;
      }

      final product = products.first;

      // Purchase StoreProduct
      setState(() => _loadingStatus = "Processing Top-Up...");
      await Purchases.purchaseStoreProduct(product);

      // If successful (no error thrown)
      await SubscriptionManager.addTopUp(250);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully added 250 messages!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Purchase failed: ${e.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _loadingStatus = null);
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _loadingStatus = "Restoring Purchases...");
    try {
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      if (customerInfo.entitlements.all['premium_access']?.isActive == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Purchases restored successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No active premium subscription found.'),
            ),
          );
        }
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingStatus = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background with Overlay
          const Positioned.fill(child: CosmicBackground(accent: kGold)),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.6)),
          ),

          // Content
          SafeArea(
            child: _offerings == null
                ? const Center(child: CircularProgressIndicator(color: kGold))
                : FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                60, // Increased top padding for close button
                                24,
                                24,
                              ),
                              child: widget.isTopUpMode
                                  ? _buildTopUpContent()
                                  : _buildPaywallContent(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          if (_loadingStatus != null)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 30,
                      ),
                      decoration: BoxDecoration(
                        color: kRoyalBlue.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kGold.withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: kGold.withOpacity(0.1),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: kGold),
                          const SizedBox(height: 24),
                          Text(
                            _loadingStatus!,
                            style: GoogleFonts.cinzel(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Please wait...",
                            style: GoogleFonts.lora(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Close Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.4),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopUpContent() {
    return Column(
      children: [
        Hero(
          tag: 'premium_ring',
          child: Container(
            height: 140,
            width: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: kGold.withOpacity(0.3),
                  blurRadius: 50,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Image.asset('assets/ring/ring.gif', fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          "Limit Reached",
          style: GoogleFonts.cinzel(
            fontSize: 28,
            color: kGold,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: kGold.withOpacity(0.5), blurRadius: 20)],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "You have used your 500 monthly messages.",
          textAlign: TextAlign.center,
          style: GoogleFonts.lora(
            fontSize: 16,
            color: Colors.white70,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 48),

        // Top Up Card
        GestureDetector(
          onTap: _purchaseTopUp,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFD4AF37).withOpacity(0.2),
                  const Color(0xFF503986).withOpacity(0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kGold, width: 2),
              boxShadow: [
                BoxShadow(
                  color: kGold.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kGold.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_circle, color: kGold, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "+250 Messages",
                        style: GoogleFonts.lora(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        "Continue chatting instantly",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  "\$4.99",
                  style: GoogleFonts.lora(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: kGold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          "Your monthly limit resets next month.",
          textAlign: TextAlign.center,
          style: GoogleFonts.lora(
            fontSize: 13,
            color: Colors.white54,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildPaywallContent() {
    return Column(
      children: [
        // Logo / Hero
        Hero(
          tag: 'premium_ring',
          child: Container(
            height: 140,
            width: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: kGold.withOpacity(0.3),
                  blurRadius: 50,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Image.asset('assets/ring/ring.gif', fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 20),

        // Title
        Text(
          "Divine Connection",
          style: GoogleFonts.cinzel(
            fontSize: 28,
            color: kGold,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: kGold.withOpacity(0.5), blurRadius: 20)],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Unlock unlimited wisdom & insights",
          textAlign: TextAlign.center,
          style: GoogleFonts.lora(
            fontSize: 16,
            color: Colors.white70,
            height: 1.3,
          ),
        ),

        const SizedBox(height: 32),

        // Features
        _buildFeatureItem(Icons.all_inclusive, "Unlimited Messages"),
        _buildFeatureItem(Icons.lock_outline, "Private & Secure Journal"),
        _buildFeatureItem(Icons.star_rate_rounded, "Priority AI Access"),

        const SizedBox(height: 40),

        // Packages
        _buildPackagesList(),

        const SizedBox(height: 24),

        // Restore
        GestureDetector(
          onTap: _restorePurchases,
          child: Text(
            "Restore Purchases",
            style: GoogleFonts.lora(
              color: Colors.white54,
              decoration: TextDecoration.underline,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Promo Code Section
        _buildPromoCodeSection(),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: kGold, size: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: GoogleFonts.lora(fontSize: 15, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Future<void> _applyPromoCode() async {
    final code = _promoController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _promoMessage = 'Please enter a promo code';
        _promoSuccess = false;
      });
      return;
    }

    final normalized = code.replaceAll(RegExp(r"\s+"), '').toLowerCase();

    // Check for lifetime premium promo code
    if (normalized == 'chrisisinnocent') {
      setState(() => _loadingStatus = "Activating Premium...");

      await SubscriptionManager.activateLifetimePremium();

      if (mounted) {
        setState(() {
          _loadingStatus = null;
          _promoMessage =
              '🎉 Pro Active Pro Forever! Lifetime premium activated!';
          _promoSuccess = true;
        });

        // Show success snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎉 Lifetime Premium Activated!',
              style: GoogleFonts.lora(),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigate to main chat home screen (like building new)
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainNav()),
            (route) => false,
          );
        }
      }
    } else {
      setState(() {
        _promoMessage = 'Invalid promo code';
        _promoSuccess = false;
      });
    }
  }

  Widget _buildPromoCodeSection() {
    return Column(
      children: [
        // Toggle button to show/hide promo field
        if (!_showPromoField)
          GestureDetector(
            onTap: () => setState(() => _showPromoField = true),
            child: Text(
              "Have a promo code?",
              style: GoogleFonts.lora(
                color: Colors.white54,
                decoration: TextDecoration.underline,
                fontSize: 13,
              ),
            ),
          ),

        // Promo code input field
        if (_showPromoField) ...[
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _promoSuccess
                    ? Colors.green.withOpacity(0.6)
                    : kGold.withOpacity(0.3),
              ),
              color: Colors.white.withOpacity(0.05),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promoController,
                    style: GoogleFonts.lora(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Enter promo code',
                      hintStyle: GoogleFonts.lora(
                        color: Colors.white38,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    enabled: !_promoSuccess,
                  ),
                ),
                if (!_promoSuccess)
                  GestureDetector(
                    onTap: _applyPromoCode,
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [kGold.withOpacity(0.8), kGold],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: kGold.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'Apply',
                        style: GoogleFonts.cinzel(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                if (_promoSuccess)
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 24,
                    ),
                  ),
              ],
            ),
          ),
          if (_promoMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _promoMessage!,
              style: GoogleFonts.lora(
                color: _promoSuccess ? Colors.greenAccent : Colors.redAccent,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildPackagesList() {
    if (_offerings == null || _offerings!.current == null) {
      return const Text("Unavailable", style: TextStyle(color: Colors.white54));
    }

    final packages = _offerings!.current!.availablePackages;

    // Find the 3-month package to highlight
    // Prioritize identifier containing '3' or 'month' or 'quarter' if enum check fails
    // But PackageType.threeMonth is safest.

    // Sort logic: Put recommended in middle or highlight it.
    // Display order:
    // 1. Weekly (Bottom/Low)
    // 2. 3-Months (Highlighted/Big)
    // 3. 6-Months (Standard)

    // Let's render as a column
    return Column(
      children: packages.map((pkg) {
        final isPreferred = pkg.packageType == PackageType.threeMonth;
        return _SubscriptionCard(
          package: pkg,
          isRecommended: isPreferred,
          onTap: () => _purchasePackage(pkg),
        );
      }).toList(),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final Package package;
  final bool isRecommended;
  final VoidCallback onTap;

  const _SubscriptionCard({
    required this.package,
    required this.isRecommended,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // If recommended, scale up slightly
    final scale = isRecommended ? 1.0 : 0.95;
    final color = isRecommended ? kGold : kRoyalBlue;
    final bgGradient = isRecommended
        ? LinearGradient(
            colors: [
              const Color(0xFFD4AF37).withOpacity(0.2),
              const Color(0xFF503986).withOpacity(0.2),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: [
              Colors.white.withOpacity(0.05),
              Colors.white.withOpacity(0.02),
            ],
          );

    return Transform.scale(
      scale: scale,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Main Card
              Container(
                decoration: BoxDecoration(
                  gradient: bgGradient,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: color.withOpacity(isRecommended ? 1.0 : 0.3),
                    width: isRecommended ? 2 : 1,
                  ),
                  boxShadow: isRecommended
                      ? [
                          BoxShadow(
                            color: kGold.withOpacity(0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : [],
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Radio indicator
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isRecommended ? kGold : Colors.white24,
                          width: 2,
                        ),
                        color: isRecommended ? kGold : Colors.transparent,
                      ),
                      child: isRecommended
                          ? const Center(
                              child: Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.black,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),

                    // Text info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            package.storeProduct.title
                                .replaceAll(RegExp(r'\(.*\)'), '')
                                .trim(), // Clean title
                            style: GoogleFonts.lora(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            package.storeProduct.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Price
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          package.storeProduct.priceString,
                          style: GoogleFonts.lora(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isRecommended ? kGold : Colors.white,
                          ),
                        ),
                        if (isRecommended &&
                            package.packageType == PackageType.threeMonth)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Shimmer.fromColors(
                              baseColor: kGold,
                              highlightColor: Colors.white,
                              child: const Text(
                                "BEST VALUE",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Floating Badge for Recommended
              if (isRecommended)
                Positioned(
                  top: -12,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: kGold,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: kGold.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      "MOST POPULAR",
                      style: GoogleFonts.cinzel(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
