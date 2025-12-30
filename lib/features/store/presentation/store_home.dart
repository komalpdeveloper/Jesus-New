import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:clientapp/core/theme/palette.dart';
import 'product_view.dart';
import 'rings_page.dart';
import 'widgets/apple_pay_button.dart';
import 'package:clientapp/shared/widgets/cosmic_background.dart';
import 'widgets/store_bottom_nav_bar.dart';
import 'package:clientapp/shared/widgets/back_nav_button.dart';
import 'widgets/store_product_card.dart';
import 'package:clientapp/features/store_admin/data/admin_auth.dart';
import 'package:clientapp/features/store_admin/presentation/admin_pages.dart';
// no dart:io needed for network banners
import 'package:clientapp/features/store_admin/data/repositories/banner_repository.dart';
import 'package:clientapp/features/store_admin/data/repositories/product_repository.dart';
import 'package:clientapp/features/store_admin/data/models/product.dart';
import 'package:clientapp/core/services/user_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:clientapp/features/store/services/store_listings_service.dart';
import 'widgets/store_shimmer_loading.dart';

class StoreHomePage extends StatefulWidget {
  final GlobalKey? cartKey; // when embedded in a shell, cart icon target from shell
  final bool embed; // if true, do not render own bottom nav
  const StoreHomePage({super.key, this.cartKey, this.embed = false});

  @override
  State<StoreHomePage> createState() => _StoreHomePageState();
}

class _StoreHomePageState extends State<StoreHomePage> {
  late final GlobalKey _cartKey;

  @override
  void initState() {
    super.initState();
    _cartKey = widget.cartKey ?? GlobalKey();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF130E0A),
      appBar: _buildAppBar(context),
      body: _Body(cartKey: _cartKey),
      bottomNavigationBar: widget.embed
          ? null
          : StoreBottomNavBar(
              currentIndex: 0,
              cartKey: _cartKey,
              onTap: (_) {},
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
        // Ring count with Apple Pay button
        Padding(
          padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: const _RingStatus(compact: true),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final VoidCallback? onTap;
  const _Banner({this.onTap});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: null, // disabled: no action on tap
          child: Container(
            height: 190,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              image: const DecorationImage(
                image: AssetImage('assets/banner/banner.png'),
                fit: BoxFit.cover,
              ),
              border: Border.all(color: kGold.withValues(alpha: 0.5), width: 1.4),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 6)),
              ],
            ),
            child: Stack(
              children: [
                // Overlay gradient to keep text readable
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xAA2B0E47), Color(0x9910091F)],
                      ),
                    ),
                  ),
                ),
                // Subtle sheen across content for active vibe
                Sheen(
                  period: const Duration(seconds: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Weekend Blessings',
                          style: GoogleFonts.cinzel(
                            fontSize: 22,
                            color: kGold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Earn double rings on all clearance relics today only.',
                          style: GoogleFonts.lora(fontSize: 13.5, color: Colors.white70, height: 1.3),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kGold,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: onTap,
                          child: Text(
                            'Shop Now',
                            style: GoogleFonts.cinzel(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ),
                      ],
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

// Admin-managed main banner (falls back to static banner if none configured)
class _AdminHomeMainBanner extends StatefulWidget {
  final VoidCallback? onTap;
  const _AdminHomeMainBanner({this.onTap});
  @override
  State<_AdminHomeMainBanner> createState() => _AdminHomeMainBannerState();
}

class _AdminHomeMainBannerState extends State<_AdminHomeMainBanner> {
  final _repo = BannerRepository();
  String? _url;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _repo.listByPlacement('homeMain');
      _url = list.isNotEmpty ? list.first.imageUrl : null;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_url == null) return _Banner(onTap: widget.onTap);
    final width = MediaQuery.of(context).size.width * 0.8;
    return Center(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: widget.onTap, // Navigate to shop page
          child: Container(
            width: width,
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              image: DecorationImage(
                image: CachedNetworkImageProvider(_url!),
                fit: BoxFit.cover,
                onError: (_, __) {},
              ),
              border: Border.all(color: kGold.withValues(alpha: 0.5), width: 1.4),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 6)),
              ],
            ),
            child: Stack(children: [
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xAA2B0E47), Color(0x9910091F)],
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// Admin-managed sub banners (up to 3) displayed as small tiles
class _AdminHomeSubBanners extends StatefulWidget {
  const _AdminHomeSubBanners();
  @override
  State<_AdminHomeSubBanners> createState() => _AdminHomeSubBannersState();
}

class _AdminHomeSubBannersState extends State<_AdminHomeSubBanners> {
  final _repo = BannerRepository();
  List<String?> _urls = List.filled(3, null);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final subs = await _repo.listByPlacement('homeSub');
      final urls = List<String?>.filled(3, null);
      for (final b in subs) {
        if (b.slot >= 0 && b.slot < 3) urls[b.slot] = b.imageUrl;
      }
      _urls = urls;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final subs = _urls;
    if (subs.every((e) => e == null)) return const SizedBox.shrink();
    final width = MediaQuery.of(context).size.width * 0.8;
    return Center(
      child: SizedBox(
        width: width,
        height: 120,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemBuilder: (_, i) {
            final url = subs[i];
            return AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kGold.withValues(alpha: 0.4)),
                  color: const Color(0xFF1F170C),
                  image: url == null
                      ? null
                      : DecorationImage(image: CachedNetworkImageProvider(url), fit: BoxFit.cover),
                ),
                child: url == null ? Center(child: Text('Banner ${i + 1}', style: GoogleFonts.lora(color: Colors.white38))) : null,
              ),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemCount: subs.length,
        ),
      ),
    );
  }
}

// Single banner below Hot Now (placement: homeBelow)
class _AdminHomeBelowBanner extends StatefulWidget {
  @override
  State<_AdminHomeBelowBanner> createState() => _AdminHomeBelowBannerState();
}

class _AdminHomeBelowBannerState extends State<_AdminHomeBelowBanner> {
  final _repo = BannerRepository();
  String? _url;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _repo.listByPlacement('homeBelow');
      _url = list.isNotEmpty ? list.first.imageUrl : null;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _url == null) return const SizedBox.shrink();
    final width = MediaQuery.of(context).size.width * 0.8;
    return Center(
      child: Container(
        width: width,
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kGold.withValues(alpha: 0.4)),
          image: DecorationImage(image: CachedNetworkImageProvider(_url!), fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _WordmartTitle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ADMIN button above the logo
        Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              onPressed: () async {
                final loggedIn = await AdminAuth.isLoggedIn();
                if (loggedIn) {
                  // open dashboard
                  // New in-memory store instance for now
                  // (swap with a persisted store later)
                  // ignore: use_build_context_synchronously
                  Navigator.push(context, MaterialPageRoute(builder: (_) => AdminHomePage(store: adminStore)));
                } else {
                  // ignore: use_build_context_synchronously
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminLoginPage()));
                }
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white70, width: 1.6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('ADMIN'),
            ),
          ),
        ),
        Center(
          child: SizedBox(
            width: 250,
            child: Image.asset(
              'assets/main_store_logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) {
                // Fallback to a generic logo, then text
                return Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stack) => Text(
                    'WORDMART',
                    style: GoogleFonts.cinzel(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                      color: kGold,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}


class _Body extends StatefulWidget {
  final GlobalKey cartKey;
  const _Body({required this.cartKey});

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  final _repo = ProductRepository();
  final _listingsService = StoreListingsService();
  final _scroll = ScrollController();
  final _newArrivalsKey = GlobalKey();
  final _popularKey = GlobalKey();
  final _clearanceKey = GlobalKey();

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
      alignment: 0.08,
    );
  }

  // Demo fallback items so UI never looks empty
  List<_Product> get _demoHot => const [
        _Product(productId: 'demo1', title: 'Hot Relic', image: 'assets/items/1.png', price: 5.99, sale: true, originalPrice: 8.99),
        _Product(productId: 'demo2', title: 'Anointed Oil', image: 'assets/logo.png', price: 3.49, sale: false),
        _Product(productId: 'demo3', title: 'Blessing Bundle', image: 'assets/logo.png', price: 9.99, sale: true, originalPrice: 12.99),
        _Product(productId: 'demo4', title: 'Scented Charm', image: 'assets/logo.png', price: 2.99, sale: false),
      ];
  List<_Product> get _demoPopular => const [
        _Product(productId: 'demo5', title: 'Test Name #1', image: 'assets/items/1.png', price: 4.99, sale: false),
        _Product(productId: 'demo6', title: 'Test Name #2', image: 'assets/logo.png', price: 5.99, sale: true, originalPrice: 7.99),
        _Product(productId: 'demo7', title: 'Test Name #3', image: 'assets/logo.png', price: 6.49, sale: false),
        _Product(productId: 'demo8', title: 'Test Name #4', image: 'assets/logo.png', price: 7.49, sale: true, originalPrice: 9.99),
      ];
  List<_Product> get _demoClearance => const [
        _Product(productId: 'demo9', title: 'Clearance Relic 1', image: 'assets/logo.png', price: 2.49, sale: true, originalPrice: 5.49),
        _Product(productId: 'demo10', title: 'Clearance Relic 2', image: 'assets/logo.png', price: 2.99, sale: true, originalPrice: 5.99),
        _Product(productId: 'demo11', title: 'Clearance Relic 3', image: 'assets/logo.png', price: 3.49, sale: true, originalPrice: 6.49),
        _Product(productId: 'demo12', title: 'Clearance Relic 4', image: 'assets/logo.png', price: 3.99, sale: true, originalPrice: 6.99),
      ];

  Future<List<_Product>> _fetchCurated(String section, {int? limit}) async {
    List<String> productIds = [];
    
    // Fetch curated product IDs from Firestore
    switch (section) {
      case 'hot':
        productIds = await _listingsService.getHotProductIds();
        break;
      case 'new':
        productIds = await _listingsService.getNewProductIds();
        break;
      case 'clearance':
        productIds = await _listingsService.getClearanceProductIds();
        break;
    }

    // If we have curated IDs, fetch those products
    if (productIds.isNotEmpty) {
      final products = await _repo.getByIds(productIds, onlyActive: true);
      if (products.isNotEmpty) {
        return products.map((m) => _mapProduct(m, isClearance: section == 'clearance')).toList();
      }
    }

    // Fallback: use category-based fetch if no curated list exists
    final categorySlug = section == 'hot' 
        ? 'hot-now' 
        : section == 'new' 
            ? 'new-arrivals' 
            : 'weekend-clearance';
    
    final byCat = await _repo.listByCategory(categorySlug, limit: limit);
    if (byCat.isNotEmpty) {
      return byCat.map((m) => _mapProduct(m, isClearance: section == 'clearance')).toList();
    }

    // Final fallback: recent active products
    final recent = await _repo.listRecent(limit: limit ?? 8);
    final active = recent.where((p) => p.isActive).toList();
    return active.map((m) => _mapProduct(m, isClearance: section == 'clearance')).toList();
  }

  static _Product _mapProduct(ProductModel m, {bool isClearance = false}) {
    final image = (m.imageUrls.isNotEmpty) ? m.imageUrls.first : 'assets/logo.png';
    final original = null; // placeholder if we later encode discount price
    return _Product(
      productId: m.id,
      title: m.title,
      image: image,
      images: m.imageUrls,
      price: m.price,
      sale: isClearance, // visually mark clearance as on sale
      originalPrice: original,
      rating: m.rating,
      reviewCount: m.reviews,
      description: m.description,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: _WordmartTitle(),
          ),
        ),
  SliverToBoxAdapter(child: _AdminHomeMainBanner(onTap: () => _scrollTo(_clearanceKey))),
  // Admin-configured sub banners (up to 3)
  // Removed extra sub banners above Hot Now per request
        // Additional promo banners for real-store feel
        // SliverToBoxAdapter(
        //   child: PromoBanners(margin: const EdgeInsets.fromLTRB(16, 4, 16, 12)),
        // ),
        // Categories removed per request
        // Hot items carousel below categories
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hot Now', style: GoogleFonts.cinzel(color: kGold, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                FutureBuilder<List<_Product>>(
                  future: _fetchCurated('hot', limit: 10),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const HotStripShimmer();
                    }
                    final items = (snap.hasError ? <_Product>[] : (snap.data ?? const []));
                    return _HotStrip(items: items.isNotEmpty ? items : _demoHot, cartKey: widget.cartKey);
                  },
                ),
              ],
            ),
          ),
        ),
        // Bottom promo row
        // Admin banners below Hot Now
        SliverToBoxAdapter(
          child: const _AdminHomeSubBanners(),
        ),
        // New Arrivals
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('New Arrivals', key: _newArrivalsKey, style: GoogleFonts.cinzel(color: kGold, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    _SectionChip(label: 'Freshly added')
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          sliver: SliverToBoxAdapter(
            child: FutureBuilder<List<_Product>>(
              future: _fetchCurated('new', limit: 8),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const ProductGridShimmer(itemCount: 4);
                }
                final items = (snap.hasError ? <_Product>[] : (snap.data ?? const []));
                final recent = items.isNotEmpty ? items : _demoPopular; // fallback
                return _ProductsGrid(items: recent, cartKey: widget.cartKey, variant: _GridVariant.newArrivals);
              },
            ),
          ),
        ),
        // Popular Offerings
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Text('Popular Offerings', key: _popularKey, style: GoogleFonts.cinzel(color: kGold, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                _SectionChip(label: 'Trending now', color: kRoyalBlue.withValues(alpha: 0.55)),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          sliver: SliverToBoxAdapter(
            child: FutureBuilder<List<_Product>>(
              future: _fetchCurated('new', limit: 8),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const ProductGridShimmer(itemCount: 4);
                }
                final items = (snap.hasError ? <_Product>[] : (snap.data ?? const []));
                return _ProductsGrid(items: items.isNotEmpty ? items : _demoPopular, cartKey: widget.cartKey, variant: _GridVariant.popular);
              },
            ),
          ),
        ),

        // Weekend Clearance
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Text('Weekend Clearance', key: _clearanceKey, style: GoogleFonts.cinzel(color: kGold, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                _SectionChip(label: 'Up to 50% off', color: kRed.withValues(alpha: 0.85)),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          sliver: SliverToBoxAdapter(
            child: FutureBuilder<List<_Product>>(
              future: _fetchCurated('clearance', limit: 8),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const ProductGridShimmer(itemCount: 4);
                }
                final items = (snap.hasError ? <_Product>[] : (snap.data ?? const []));
                return _ProductsGrid(items: items.isNotEmpty ? items : _demoClearance, cartKey: widget.cartKey, variant: _GridVariant.clearance);
              },
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}

// Static horizontal strip for Hot Now (no animation), ~3 items visible
class _HotStrip extends StatelessWidget {
  final List<_Product> items;
  final GlobalKey cartKey;
  const _HotStrip({required this.items, required this.cartKey});

  @override
  Widget build(BuildContext context) {
    final controller = ScrollController();
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final maxW = constraints.maxWidth;
        double cardW = (maxW - spacing * 2) / 3; // approx 3 per view
        cardW = cardW.clamp(110.0, 160.0);

        void scrollBy(double delta) {
          final target = (controller.offset + delta).clamp(
            controller.position.minScrollExtent,
            controller.position.maxScrollExtent,
          );
          controller.animateTo(
            target,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }

        return SizedBox(
          height: 180,
          child: Stack(
            children: [
              ListView.separated(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: spacing),
                itemBuilder: (context, i) => _HotStripCard(product: items[i], width: cardW),
              ),
              // Left button
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  ignoring: false,
                  child: _ScrollButton(
                    icon: Icons.chevron_left,
                    onTap: () => scrollBy(-cardW - spacing),
                  ),
                ),
              ),
              // Right button
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: _ScrollButton(
                  icon: Icons.chevron_right,
                  onTap: () => scrollBy(cardW + spacing),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HotStripCard extends StatelessWidget {
  final _Product product;
  final double width;
  const _HotStripCard({required this.product, required this.width});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductViewPage(
              productId: product.productId,
              title: product.title,
              image: product.image,
              images: product.images.isEmpty ? null : product.images,
              ringPrice: product.price,
              description: product.description,
            ),
          ),
        );
      },
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: const Color(0xFF1F170C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kGold.withValues(alpha: 0.35), width: 1),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: Stack(
          children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 96,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Builder(builder: (_) {
                        final img = product.image;
                        return img.startsWith('http')
                            ? CachedNetworkImage(
                                imageUrl: img,
                                fit: BoxFit.cover,
                                placeholder: (c, _) => Container(color: const Color(0x221F170C)),
                                errorWidget: (c, _, __) => const Icon(Icons.broken_image, color: Colors.white54),
                              )
                            : Image.asset(img, fit: BoxFit.cover);
                      }),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xCC1F170C)],
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lora(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        SizedBox(height: 15, width: 15, child: Image.asset('assets/icon/ring_img.png')),
                        const SizedBox(width: 5),
                        Text(
                          product.price.toStringAsFixed(0),
                          style: GoogleFonts.cinzel(color: kGold, fontWeight: FontWeight.w800, fontSize: 13.5),
                        ),
                        if (product.sale && product.originalPrice != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            product.originalPrice!.toStringAsFixed(0),
                            style: GoogleFonts.cinzel(color: Colors.white60, decoration: TextDecoration.lineThrough, fontSize: 12),
                          ),
                        ]
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // HOT tag with subtle pulse
          Positioned(
            top: 8,
            left: 8,
            child: _HotTag(),
          ),
        ],
      ),
      ),
    );
  }
}

class _ScrollButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ScrollButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kGold.withValues(alpha: 0.5)),
          ),
          child: Icon(icon, size: 22, color: kGold),
        ),
      ),
    );
  }
}

class _HotTag extends StatefulWidget {
  @override
  State<_HotTag> createState() => _HotTagState();
}

class _HotTagState extends State<_HotTag> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _scale = Tween(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: kRed.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Text('HOT', style: GoogleFonts.cinzel(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1)),
      ),
    );
  }
}
class _Product {
  final String productId; // Firestore product document ID
  final String title;
  final String image; // primary image
  final List<String> images; // all images
  final double price;
  final bool sale;
  final double? originalPrice;
  final double? rating;
  final int? reviewCount;
  final String? description;
  const _Product({
    required this.productId,
    required this.title,
    required this.image,
    this.images = const [],
    required this.price,
    required this.sale,
    this.originalPrice,
    this.rating,
    this.reviewCount,
    this.description,
  });
}

class _ProductsGrid extends StatelessWidget {
  final List<_Product> items;
  final GlobalKey cartKey;
  final _GridVariant variant;
  const _ProductsGrid({required this.items, required this.cartKey, this.variant = _GridVariant.normal});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final p = items[index];
        final card = StoreProductCard(
          productId: p.productId,
          title: p.title,
          image: p.image,
          price: p.price,
          isOnSale: p.sale,
          originalPrice: p.originalPrice,
          rating: p.rating,
          reviewCount: p.reviewCount,
          cartKey: cartKey,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductViewPage(
                  productId: p.productId,
                  title: p.title,
                  image: p.image,
                  ringPrice: p.price,
                  images: p.images.isEmpty ? null : p.images,
                  description: p.description,
                ),
              ),
            );
          },
        );
        return Stack(
          children: [
            card,
            if (variant != _GridVariant.normal)
              Positioned(
                top: 8,
                left: 8,
                child: _CornerBadge(
                  label: switch (variant) {
                    _GridVariant.clearance => 'CLEARANCE',
                    _GridVariant.popular => 'POPULAR',
                    _GridVariant.newArrivals => 'NEW',
                    _ => '',
                  },
                  color: switch (variant) {
                    _GridVariant.clearance => kRed.withValues(alpha: 0.9),
                    _GridVariant.popular => kRoyalBlue.withValues(alpha: 0.75),
                    _GridVariant.newArrivals => Colors.greenAccent,
                    _ => kGold,
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

enum _GridVariant { normal, newArrivals, popular, clearance }

class _CornerBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _CornerBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3))],
        border: Border.all(color: Colors.black.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: GoogleFonts.cinzel(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.8),
      ),
    );
  }
}

class _SectionChip extends StatelessWidget {
  final String label;
  final Color? color;
  const _SectionChip({required this.label, this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (color ?? kGold.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kGold.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: GoogleFonts.lora(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
    );
  }
}

class _RingStatus extends StatelessWidget {
  final bool compact;
  const _RingStatus({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final ringSize = compact ? 28.0 : 35.0;
    final valueFont = compact ? 15.0 : 18.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(
        color: kRoyalBlue.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kGold.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Slightly larger ring with glow in store context to highlight
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: kGold.withValues(alpha: 0.35), blurRadius: 16, spreadRadius: 1),
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
                Text('Rings', style: GoogleFonts.cinzel(fontSize: 11, color: Colors.white70, letterSpacing: 1)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
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
          )
        ],
      ),
    );
  }
}
