import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:clientapp/core/theme/palette.dart';
import 'package:clientapp/shared/widgets/back_nav_button.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter/services.dart';
import 'package:clientapp/core/services/user_service.dart';

/// In-game currency: Rings purchase page.
/// Shows up to 3 packages. Actual pricing/ids will be provided later by the client.
class RingsPage extends StatefulWidget {
  const RingsPage({super.key});

  @override
  State<RingsPage> createState() => _RingsPageState();
}

class _RingsPageState extends State<RingsPage> {
  // Known consumable product IDs
  static const Set<String> _kProductIds = {
    'com.cassarly.jesusnew.rings.100',
    'com.cassarly.jesusnew.rings.1000',
    'com.cassarly.jesusnew.rings.5000',
  };

  static const Map<String, int> _idToRings = {
    'com.cassarly.jesusnew.rings.100': 100,
    'com.cassarly.jesusnew.rings.1000': 1000,
    'com.cassarly.jesusnew.rings.5000': 5000,
  };

  static const Map<String, String> _idToTitle = {
    'com.cassarly.jesusnew.rings.100': 'Starter',
    'com.cassarly.jesusnew.rings.1000': 'Treasury',
    'com.cassarly.jesusnew.rings.5000': 'Overflow',
  };

  static const Map<String, String> _idToImage = {
    'com.cassarly.jesusnew.rings.100': 'assets/packages/1.png',
    'com.cassarly.jesusnew.rings.1000': 'assets/packages/2.png',
    'com.cassarly.jesusnew.rings.5000': 'assets/packages/3.png',
  };

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool _storeAvailable = false;
  bool _loading = true;
  bool _purchasePending = false;
  List<ProductDetails> _products = const [];
  List<String> _notFoundIds = const [];
  // Debug console removed; keep minimal internal buffer for optional logging
  StringBuffer _debugBuf = StringBuffer();

  // UI-only in-memory balance per requirement
  int _ringBalance = 0; // live balance from Firestore
  // Track delivered purchases to avoid double-credit
  final Set<String> _deliveredPurchaseIds = {};

  @override
  void initState() {
    super.initState();
    _log('RingsPage init; platform=${Platform.operatingSystem}');
    _initStore();
    // Listen to Firestore ring balance
    UserService.instance.ringCountStream().listen((count) {
      if (mounted) setState(() => _ringBalance = count);
    });
    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onDone: () {
        _sub?.cancel();
      },
      onError: (Object e) {
        if (mounted) {
          _log('purchaseStream error: $e');
          setState(() => _purchasePending = false);
        }
      },
    );
  }

  Future<void> _initStore() async {
    setState(() => _loading = true);
    try {
      _log('Querying store for products: ${_kProductIds.join(', ')}');
      final available = await _iap.isAvailable();
      _log('Store available: $available');
      if (!available) {
        if (mounted) {
          setState(() {
            _storeAvailable = false;
            _loading = false;
          });
        }
        return;
      }

      final response = await _iap.queryProductDetails(_kProductIds);
      _log(
        'queryProductDetails: found=${response.productDetails.length}, notFound=${response.notFoundIDs.length}',
      );
      if (mounted) {
        setState(() {
          _storeAvailable = true;
          _products = response.productDetails.toList()
            ..sort(
              (a, b) =>
                  (_idToRings[b.id] ?? 0).compareTo(_idToRings[a.id] ?? 0),
            );
          _loading = false;
          _notFoundIds = response.notFoundIDs.toList();
        });
      }
      if (response.notFoundIDs.isNotEmpty) {
        _log('Not found IDs: ${response.notFoundIDs.join(', ')}');
      }
      for (final pd in response.productDetails) {
        _log('Product: id=${pd.id}, title=${pd.title}, price=${pd.price}');
      }
    } catch (e) {
      if (mounted) {
        _log('Store init error: $e');
        setState(() {
          _storeAvailable = false;
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      _log(
        'Purchase update: productID=${purchase.productID}, status=${purchase.status}',
      );
      switch (purchase.status) {
        case PurchaseStatus.pending:
          if (mounted) setState(() => _purchasePending = true);
          break;
        case PurchaseStatus.error:
          if (mounted) setState(() => _purchasePending = false);
          if (mounted) {
            final msg = purchase.error?.message ?? 'Unknown error';
            _log('Purchase error for ${purchase.productID}: $msg');
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Purchase failed: $msg')));
          }
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // For this demo we trust the purchase and deliver immediately
          await _deliverIfFirstTime(purchase);
          break;
        case PurchaseStatus.canceled:
          _log('Purchase canceled: ${purchase.productID}');
          if (mounted) setState(() => _purchasePending = false);
          break;
      }

      // Always complete the purchase if required by the platform
      if (purchase.pendingCompletePurchase) {
        try {
          // For Android consumables, autoConsume below handles this; still call completePurchase for both platforms.
          _log('Completing purchase: ${purchase.productID}');
          await _iap.completePurchase(purchase);
        } catch (_) {}
      }
    }
  }

  Future<void> _deliverIfFirstTime(PurchaseDetails purchase) async {
    final uniqueKey =
        purchase.purchaseID ??
        purchase.transactionDate ??
        '${purchase.productID}-${DateTime.now().millisecondsSinceEpoch}';
    if (_deliveredPurchaseIds.contains(uniqueKey)) {
      _log(
        'Duplicate delivery ignored for ${purchase.productID} (key=$uniqueKey)',
      );
      return;
    }

    final ringsToAdd = _idToRings[purchase.productID] ?? 0;
    if (ringsToAdd <= 0) {
      _log(
        'No ring mapping found for ${purchase.productID}. Skipping delivery.',
      );
      if (mounted) setState(() => _purchasePending = false);
      return;
    }

    // Atomically increment user's ringCount in Firestore; stream will update UI
    try {
      await UserService.instance.incrementRings(ringsToAdd);
      _deliveredPurchaseIds.add(uniqueKey);
      _log('Delivered $ringsToAdd rings for ${purchase.productID}.');
      if (mounted) {
        setState(() => _purchasePending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added $ringsToAdd rings to your balance.',
              style: GoogleFonts.lora(),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: kRoyalBlue.withValues(alpha: 0.92),
          ),
        );
      }
    } catch (e) {
      _log('Failed to update ring balance: $e');
      if (mounted) setState(() => _purchasePending = false);
    }
  }

  Future<void> _buy(ProductDetails product) async {
    _log('Starting purchase for ${product.id}');
    setState(() => _purchasePending = true);
    final purchaseParam = PurchaseParam(
      productDetails: product,
      applicationUserName: null,
    );
    try {
      // Consumables must be auto-consumed on iOS, and it's recommended on Android
      // to allow re-purchase without manual consumption. All our Ring packs are
      // consumables, so we always pass autoConsume: true.
      await _iap.buyConsumable(purchaseParam: purchaseParam, autoConsume: true);
    } catch (e) {
      if (mounted) {
        setState(() => _purchasePending = false);
        if (e is PlatformException && e.code == 'userCancelled') {
          // User dismissed the App Store login or purchase sheet. Not an error.
          _log('Purchase start canceled by user for ${product.id}');
          // Optional: Show a subtle toast/snackbar, or stay silent.
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Purchase canceled')));
        } else {
          _log('Failed to start purchase for ${product.id}: $e');
          final msg = e is PlatformException
              ? (e.message ?? e.code)
              : e.toString();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not start purchase: $msg')),
          );
        }
      }
    }
  }

  void _log(String message) {
    final ts = DateTime.now().toIso8601String();
    setState(() {
      _debugBuf.writeln('[$ts] $message');
    });
  }

  // Debug text getter removed; console not shown in production

  // Removed copy/clear debug helpers; console hidden in production

  @override
  Widget build(BuildContext context) {
    // Build runtime packages from store products
    final packages = _products.map((pd) {
      return _RingPackage(
        id: pd.id,
        title: _idToTitle[pd.id] ?? pd.title,
        rings: _idToRings[pd.id] ?? 0,
        priceLabel: pd.price,
        image: _idToImage[pd.id] ?? 'assets/packages/1.png',
      );
    }).toList();

    return Scaffold(
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
          'Get Rings',
          style: GoogleFonts.cinzel(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            children: [
              _HeroBalanceCard(balance: _ringBalance),
              const SizedBox(height: 22),
              if (Platform.isIOS) ...[
                const _AcceptedPaymentsRow(),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: Text(
                  'Select Package',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cinzel(
                    color: kGold,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (!_storeAvailable)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28.0),
                  child: Text(
                    'Store not available right now. Please try again later.',
                    style: GoogleFonts.lora(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                )
              else if (packages.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'No products found for your store configuration.',
                        style: GoogleFonts.lora(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      if (_notFoundIds.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Missing IDs: ${_notFoundIds.join(', ')}',
                          style: GoogleFonts.lora(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                )
              else
                _PackageGrid(
                  packages: packages,
                  onBuy: (pkg) {
                    final pd = _products.firstWhere((p) => p.id == pkg.id);
                    _buy(pd);
                  },
                ),
            ],
          ),
          if (_purchasePending)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _HeroBalanceCard extends StatelessWidget {
  final int balance;
  const _HeroBalanceCard({required this.balance});
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        decoration: BoxDecoration(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: kGold.withValues(alpha: 0.35),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Image.asset('assets/icon/ring_img.png'),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Rings',
                  style: GoogleFonts.cinzel(
                    color: const Color.fromARGB(179, 255, 255, 255),
                    fontSize: 15,
                    letterSpacing: 0.8,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated count-up for ring balance
                    TweenAnimationBuilder<double>(
                      key: ValueKey(balance),
                      tween: Tween<double>(begin: 0, end: balance.toDouble()),
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        final display = value
                            .clamp(0, balance.toDouble())
                            .toInt();
                        return Text(
                          '$display',
                          style: GoogleFonts.cinzel(
                            color: kGold,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AcceptedPaymentsRow extends StatelessWidget {
  const _AcceptedPaymentsRow();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1F170C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kGold.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.apple, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Secure payments via Apple In‑App Purchase',
              style: GoogleFonts.lora(color: Colors.white70, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 0,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.apple, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Apple Pay',
                      style: GoogleFonts.cinzel(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PackageGrid extends StatelessWidget {
  final List<_RingPackage> packages;
  final void Function(_RingPackage pkg) onBuy;
  const _PackageGrid({required this.packages, required this.onBuy});

  @override
  Widget build(BuildContext context) {
    // Use Wrap instead of GridView so when there is an odd card (like 3rd),
    // it can naturally center on a new line.
    final width = MediaQuery.sizeOf(context).width;
    final isNarrow = width < 380;
    final itemWidth = isNarrow
        ? width - 36
        : (width - 18 /*left*/ - 18 /*right*/ - 12 /*gap*/ ) / 2;
    final itemHeight = itemWidth / 0.8; // keep similar aspect as before

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        for (final p in packages)
          SizedBox(
            width: itemWidth,
            height: itemHeight,
            child: _PackageCard(pkg: p, onBuy: () => onBuy(p)),
          ),
      ],
    );
  }
}

class _PackageCard extends StatefulWidget {
  final _RingPackage pkg;
  final VoidCallback onBuy;
  const _PackageCard({required this.pkg, required this.onBuy});

  @override
  State<_PackageCard> createState() => _PackageCardState();
}

class _PackageCardState extends State<_PackageCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  bool get _isBestValue => widget.pkg.id == 'rings_tier_3';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _pulse = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _ctrl.addListener(() => setState(() {}));
    if (_isBestValue) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _PackageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasBest = oldWidget.pkg.id == 'rings_tier_3';
    if (_isBestValue && !wasBest) {
      _ctrl.repeat(reverse: true);
    } else if (!_isBestValue && wasBest) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBestValue = _isBestValue;
    final isPopular = widget.pkg.id == 'rings_tier_2';
    final t = isBestValue ? _pulse.value : 0.0; // 0..1
    final double borderWidth = lerpDouble(1.2, 2.2, t)!;
    final double glowBlur = lerpDouble(16, 30, t)!;
    final double glowAlpha = 0.35 + 0.35 * t; // 0.35..0.70

    return InkWell(
      onTap: widget.onBuy,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: kGold.withValues(alpha: 0.5 + 0.3 * t),
            width: borderWidth,
          ),
          boxShadow: [
            const BoxShadow(
              color: Colors.black54,
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
            if (isBestValue)
              BoxShadow(
                color: kGold.withValues(alpha: glowAlpha),
                blurRadius: glowBlur,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            color: const Color(0xFF0E0A18),
            child: Column(
              children: [
                // Image area (smaller than full card)
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Subtle backdrop gradient
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF1B1320), Color(0xFF0E0A18)],
                          ),
                        ),
                      ),
                      // Centered, smaller image
                      Align(
                        alignment: Alignment.topCenter,
                        child: FractionallySizedBox(
                          heightFactor: 0.72,
                          widthFactor: 0.9,
                          child: Image.asset(
                            widget.pkg.image,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                      // Bottom vignette for legibility
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          height: 70,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Color(0xAA000000), Color(0x00000000)],
                            ),
                          ),
                        ),
                      ),
                      // Tag badges
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Row(
                          children: [
                            if (isBestValue)
                              _TagBadge(label: 'Best Value')
                            else if (isPopular)
                              _TagBadge(label: 'Popular'),
                          ],
                        ),
                      ),
                      // Bottom-left overlay: title + rings
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.pkg.title,
                              style: GoogleFonts.cinzel(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/icon/ring_img.png',
                                  width: 14,
                                  height: 14,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '${widget.pkg.rings} Rings',
                                    style: GoogleFonts.lora(
                                      color: kGold,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Footer with buy button only (avoids covering overlay text)
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xB31A1511),
                    border: Border(
                      top: BorderSide(color: kGold.withValues(alpha: 0.3)),
                    ),
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _PayButton(
                        label: widget.pkg.priceLabel,
                        onPressed: widget.onBuy,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PayButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _PayButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isIOS = Platform
        .isIOS; // style hint only; real Apple Pay requires StoreKit entitlements
    // Shorten long labels like "$4.99 USD" -> "$4.99" to avoid wrapping on small cards
    final String smartLabel = label.replaceAll(' USD', '').trim();
    if (isIOS) {
      // Apple Pay styled button
      return SizedBox(
        height: 44,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: onPressed,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.apple, size: 20),
              const SizedBox(width: 8),
              Text(
                'Apple Pay • $smartLabel',
                style: GoogleFonts.cinzel(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
    }

    // Gold button for other platforms
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: kGold,
          foregroundColor: kDeepBlack,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          'Buy • $smartLabel',
          style: GoogleFonts.cinzel(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _TagBadge extends StatelessWidget {
  final String label;
  const _TagBadge({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kGold.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kGold.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: GoogleFonts.lora(
          color: kGold,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// _PolicyNote was removed as it is not currently used on the page.

// Debug console widget removed in production

class _RingPackage {
  final String id;
  final String title;
  final int rings;
  final String priceLabel; // display label until real pricing is wired
  final String image; // asset path for background art
  const _RingPackage({
    required this.id,
    required this.title,
    required this.rings,
    required this.priceLabel,
    required this.image,
  });
}
