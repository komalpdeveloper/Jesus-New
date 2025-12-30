import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:clientapp/core/theme/palette.dart';
import 'package:clientapp/shared/widgets/back_nav_button.dart';
import 'package:clientapp/features/store/presentation/widgets/store_product_card.dart';
import 'package:clientapp/features/store/presentation/product_view.dart';
import 'package:clientapp/features/store_admin/data/repositories/product_repository.dart';
import 'package:clientapp/features/store_admin/data/models/product.dart';

/// A page that shows products for a given store category.
class StoreCategoryPage extends StatefulWidget {
  final String category;
  final GlobalKey? cartKey;
  const StoreCategoryPage({super.key, required this.category, this.cartKey});

  @override
  State<StoreCategoryPage> createState() => _StoreCategoryPageState();
}

class _StoreCategoryPageState extends State<StoreCategoryPage> {
  final GlobalKey _cartKey = GlobalKey();
  final _repo = ProductRepository();
  List<ProductModel> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Fetch all then filter by categoryName for now (can optimize to query by categoryId if needed)
      final all = await _repo.listAll();
      final list = all.where((p) => p.isActive && p.categoryName == widget.category).toList();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = const [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartKey = widget.cartKey ?? _cartKey;
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
        title: Text(widget.category, style: GoogleFonts.cinzel(color: kGold, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_items.isEmpty
              ? Center(child: Text('No items found', style: GoogleFonts.lora(color: Colors.white70)))
              : CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      sliver: _GridSliver(items: _items, cartKey: cartKey),
                    ),
                  ],
                )),
    );
  }
}

class _GridSliver extends StatelessWidget {
  final List<ProductModel> items;
  final GlobalKey cartKey;
  const _GridSliver({required this.items, required this.cartKey});

  @override
  Widget build(BuildContext context) {
    const spacing = 12.0;
    final size = MediaQuery.of(context).size;
    final childAspect = size.width > 700 ? 0.86 : 0.80;
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: size.width > 700 ? 3 : 2,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: childAspect,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          final it = items[i];
          return StoreProductCard(
            productId: it.id,
            title: it.title,
            image: (it.imageUrls.isNotEmpty ? it.imageUrls.first : 'assets/logo.png'),
            price: it.price.toDouble(),
            rating: it.rating,
            reviewCount: it.reviews,
            cartKey: cartKey,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductViewPage(
                    productId: it.id,
                    title: it.title,
                    image: (it.imageUrls.isNotEmpty ? it.imageUrls.first : 'assets/logo.png'),
                    images: it.imageUrls.isNotEmpty ? it.imageUrls : null,
                    ringPrice: it.price.toDouble(),
                    description: it.description,
                  ),
                ),
              );
            },
          );
        },
        childCount: items.length,
      ),
    );
  }
}
// Removed demo _Item; using ProductModel from admin data.
