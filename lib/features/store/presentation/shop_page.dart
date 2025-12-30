import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:clientapp/core/theme/palette.dart';
import 'widgets/store_product_card.dart';
import 'product_view.dart';
import 'rings_page.dart';
import 'widgets/apple_pay_button.dart';
import 'package:clientapp/shared/widgets/back_nav_button.dart';
import 'widgets/store_bottom_nav_bar.dart';
import 'package:clientapp/features/store_admin/data/repositories/banner_repository.dart';
import 'package:clientapp/features/store_admin/data/repositories/category_repository.dart';
import 'package:clientapp/features/store_admin/data/repositories/product_repository.dart';
import 'package:clientapp/features/store_admin/data/models/product.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:clientapp/core/services/user_service.dart';
// removed unused admin_pages and dart:io imports

class ShopPage extends StatefulWidget {
  final String? initialCategory;
  final GlobalKey? cartKey;
  final bool embed;
  const ShopPage({super.key, this.initialCategory, this.cartKey, this.embed = false});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  final TextEditingController _searchCtl = TextEditingController();
  List<String> _categories = const ['All'];
  String _selected = 'All';
  // Sorting is optional; default to none
  SortOption _sort = SortOption.none;
  static const int _pageSize = 20;
  int _currentPage = 1;

  List<ProductModel> _allProducts = const [];
  // Key used as the animation target for fly-to-cart from product cards
  late final GlobalKey _cartKey;

  final _categoryRepo = CategoryRepository();
  final _productRepo = ProductRepository();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cartKey = widget.cartKey ?? GlobalKey();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Fetch categories (active only) and products
      final cats = await _categoryRepo.listActive();
      final prods = await _productRepo.listAll();

      final names = ['All', ...cats.map((c) => c.name)];

      // Apply initial category if provided
      String sel = 'All';
      final initCat = widget.initialCategory;
      if (initCat != null && names.contains(initCat)) {
        sel = initCat;
      }

      if (!mounted) return;
      setState(() {
        _categories = names;
        _selected = sel;
        _allProducts = prods.where((p) => p.isActive).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _categories = const ['All'];
        _allProducts = const [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print('ShopPage build called, embed: ${widget.embed}');
    final products = _filtered();
    final totalPages = (products.length / _pageSize).ceil();
    final safeTotal = totalPages == 0 ? 1 : totalPages;
    final page = math.min(math.max(1, _currentPage), safeTotal);
    final start = (page - 1) * _pageSize;
    final pageItems = products.skip(start).take(_pageSize).toList();
    return Scaffold(
      backgroundColor: const Color(0xFF130E0A),
      appBar: widget.embed 
          ? null 
          : AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 60,
        leading: const Padding(
          padding: EdgeInsets.only(left: 6),
          child: BackNavButton(),
        ),
        title: SizedBox(
          height: 30,
          child: Image.asset(
            'assets/store_logo.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to a generic logo, then to text if not present
              return Image.asset(
                'assets/logo.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Text(
                  'WordMart',
                  style: GoogleFonts.cinzel(color: kGold, fontWeight: FontWeight.w700, fontSize: 16),
                ),
              );
            },
          ),
        ),
        actions: widget.embed ? null : const [
          // Keep ring status, remove cart from AppBar
          Padding(
            padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: _RingStatus(compact: true),
          ),
          SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  if (_loading)
                    const LinearProgressIndicator(minHeight: 2),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _SearchBar(controller: _searchCtl, onChanged: (_) => setState(() { _currentPage = 1; })),
                  ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _Filters(
                    categories: _categories,
                    selected: _selected,
                    onSelect: (v) => setState(() { _selected = v; _currentPage = 1; }),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _SortBar(
                    sort: _sort,
                    onChange: (s) => setState(() { _sort = s; _currentPage = 1; }),
                  ),
                ),
                const SizedBox(height: 12),
                const _AdminStoreSubBanners(),
                const SizedBox(height: 8),
                const SizedBox(height: 12),
              ],
            ),
          ),
          if (!_loading && pageItems.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No items found', style: GoogleFonts.lora(color: Colors.white70)),
                ),
              ),
            )
          else ...[
            if (_loading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: _GridSectionSliver(products: pageItems, cartKey: _cartKey),
              ),
            SliverToBoxAdapter(child: const SizedBox(height: 12)),
            SliverToBoxAdapter(child: const SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _PaginationBar(
                  currentPage: page,
                  totalPages: safeTotal,
                  onPageChange: (p) => setState(() => _currentPage = p),
                ),
              ),
            ),
            SliverToBoxAdapter(child: const SizedBox(height: 24)),
          ],
          ],
        ),
      ),
      bottomNavigationBar: widget.embed
          ? null
          : StoreBottomNavBar(
              currentIndex: 1,
              cartKey: _cartKey,
              onTap: (_) {},
              categories: _categories,
            ),
    );
  }

  List<ProductModel> _filtered() {
    final q = _searchCtl.text.trim().toLowerCase();
    final list = _allProducts.where((p) {
      final catOk = _selected == 'All' || p.categoryName == _selected;
      final queryOk = q.isEmpty || p.title.toLowerCase().contains(q);
      return catOk && queryOk;
    }).toList();
    switch (_sort) {
      case SortOption.lowToHigh:
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case SortOption.highToLow:
        list.sort((b, a) => a.price.compareTo(b.price));
        break;
      case SortOption.mostPopular:
        // Using reviews as a proxy for popularity; fall back to rating
        list.sort((b, a) {
          final byReviews = a.reviews.compareTo(b.reviews);
          if (byReviews != 0) return byReviews;
          return a.rating.compareTo(b.rating);
        });
        break;
      case SortOption.none:
        break;
    }
    return list;
  }
}

// Admin-managed banners for the Store page (up to 3 slots)
class _AdminStoreSubBanners extends StatefulWidget {
  const _AdminStoreSubBanners();
  @override
  State<_AdminStoreSubBanners> createState() => _AdminStoreSubBannersState();
}

class _AdminStoreSubBannersState extends State<_AdminStoreSubBanners> {
  final _repo = BannerRepository();
  List<String?> _urls = List.filled(3, null);
  bool _loading = true;
  final PageController _pageController = PageController(viewportFraction: 1.0, keepPage: true);
  int _currentPage = 0;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final subs = await _repo.listByPlacement('storeSub');
      final urls = List<String?>.filled(3, null);
      for (final b in subs) {
        if (b.slot >= 0 && b.slot < 3) urls[b.slot] = b.imageUrl;
      }
      _urls = urls;
    } catch (_) {}
    if (mounted) {
      setState(() => _loading = false);
      _restartAutoSlide();
    }
  }

  void _restartAutoSlide() {
    _autoTimer?.cancel();
    final count = _urls.length;
    if (count <= 1) return;
    // Reset page index if out of bounds
    if (_currentPage >= count) _currentPage = 0;
    _autoTimer = Timer.periodic(const Duration(seconds: 3), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final c = _urls.length;
      if (c <= 1) return;
      _currentPage = (_currentPage + 1) % c;
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageController.dispose();
    super.dispose();
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
        height: 160,
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: (i) => _currentPage = i,
          itemCount: subs.length,
          itemBuilder: (_, i) {
            final url = subs[i];
            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kGold.withValues(alpha: 0.35)),
                  color: const Color(0xFF1F170C),
                  image: url == null
                      ? null
                      : DecorationImage(
                          image: CachedNetworkImageProvider(url),
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

enum SortOption { none, lowToHigh, highToLow, mostPopular }

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: GoogleFonts.lora(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Search',
        hintStyle: GoogleFonts.lora(color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF1F170C),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        prefixIcon: const Icon(Icons.search, color: Colors.white70),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: kGold.withValues(alpha: 0.35)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: kGold.withValues(alpha: 0.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: kGold, width: 1.5),
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelect;
  const _Filters({required this.categories, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title for categories
        Text('Categories', style: GoogleFonts.cinzel(color: kGold, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (_, i) {
              final c = categories[i];
              final selectedNow = c == selected;
              return ChoiceChip(
                selected: selectedNow,
                label: Text(c, style: GoogleFonts.lora(fontWeight: FontWeight.w600)),
                labelStyle: TextStyle(color: selectedNow ? kDeepBlack : Colors.white),
                selectedColor: kGold,
                backgroundColor: const Color(0xFF1F170C),
                side: BorderSide(color: kGold.withValues(alpha: 0.35)),
                onSelected: (_) => onSelect(c),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemCount: categories.length,
          ),
        ),
      ],
    );
  }
}

class _SortBar extends StatelessWidget {
  final SortOption sort;
  final ValueChanged<SortOption> onChange;
  const _SortBar({required this.sort, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final isSelected = [
      sort == SortOption.lowToHigh,
      sort == SortOption.highToLow,
      sort == SortOption.mostPopular,
    ];
    final labels = ['Low to High', 'High to Low', 'Most Popular'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sort', style: GoogleFonts.cinzel(color: kGold, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1F170C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kGold.withValues(alpha: 0.35)),
          ),
          child: ToggleButtons(
            isSelected: isSelected,
            // Tap the selected option again to clear (set to none)
            onPressed: (index) {
              final sel = switch (index) {
                0 => SortOption.lowToHigh,
                1 => SortOption.highToLow,
                _ => SortOption.mostPopular,
              };
              onChange(sort == sel ? SortOption.none : sel);
            },
            borderRadius: BorderRadius.circular(12),
            borderColor: kGold.withValues(alpha: 0.35),
            selectedBorderColor: kGold,
            fillColor: kRoyalBlue.withValues(alpha: 0.55),
            selectedColor: kGold,
            color: Colors.white70,
            constraints: const BoxConstraints(minHeight: 40, minWidth: 110),
            children: labels
                .map((t) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(t, style: GoogleFonts.lora(fontWeight: FontWeight.w600)),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

// _BannerCard removed; replaced with PromoBanners

class _PaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChange;
  const _PaginationBar({required this.currentPage, required this.totalPages, required this.onPageChange});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          _NavBtn(
            label: 'Prev',
            enabled: currentPage > 1,
            onTap: currentPage > 1 ? () => onPageChange(currentPage - 1) : null,
          ),
          ...List.generate(totalPages, (i) {
            final page = i + 1;
            final selected = page == currentPage;
            return ChoiceChip(
              selected: selected,
              label: Text('$page', style: GoogleFonts.lora(fontWeight: FontWeight.w700)),
              labelStyle: TextStyle(color: selected ? kDeepBlack : Colors.white),
              selectedColor: kGold,
              backgroundColor: const Color(0xFF1F170C),
              side: BorderSide(color: kGold.withValues(alpha: 0.35)),
              onSelected: (_) => onPageChange(page),
            );
          }),
          _NavBtn(
            label: 'Next',
            enabled: currentPage < totalPages,
            onTap: currentPage < totalPages ? () => onPageChange(currentPage + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback? onTap;
  const _NavBtn({required this.label, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: enabled ? kGold : Colors.white38,
        side: BorderSide(color: enabled ? kGold : Colors.white24),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: GoogleFonts.cinzel(fontWeight: FontWeight.w600)),
    );
  }
}

class _GridSectionSliver extends StatelessWidget {
  final List<ProductModel> products;
  final GlobalKey cartKey;
  const _GridSectionSliver({required this.products, required this.cartKey});

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      delegate: SliverChildBuilderDelegate(
        (_, i) {
          final p = products[i];
          return StoreProductCard(
            productId: p.id,
            title: p.title,
            image: (p.imageUrls.isNotEmpty ? p.imageUrls.first : 'assets/logo.png'),
            price: p.price.toDouble(),
            rating: p.rating, // real rating
            reviewCount: p.reviews, // real reviews
            cartKey: cartKey,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductViewPage(
                    productId: p.id,
                    title: p.title,
                    image: (p.imageUrls.isNotEmpty ? p.imageUrls.first : 'assets/logo.png'),
                    images: p.imageUrls.isNotEmpty ? p.imageUrls : null,
                    ringPrice: p.price.toDouble(),
                    description: p.description,
                  ),
                ),
              );
            },
          );
        },
        childCount: products.length,
      ),
    );
  }
}

// Removed obsolete _ShopAppBarActions and _CartButton (cart moved to bottom nav)

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
                        builder: (context, snap) {
                          final count = snap.data ?? 0;
                          return Text(
                            '$count',
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

// Removed legacy _ShopProduct demo class. Now using ProductModel from admin data.
