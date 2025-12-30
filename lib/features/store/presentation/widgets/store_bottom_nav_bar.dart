import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:clientapp/core/theme/palette.dart';
import 'package:clientapp/features/store/presentation/store_category_page.dart';
import 'package:clientapp/features/store/presentation/cart_page.dart';
// Navigation is delegated to caller via onTap
import 'package:clientapp/features/store_admin/data/repositories/category_repository.dart';
import 'package:clientapp/features/store/services/cart_service.dart';

// Public helper to trigger the cart icon swing from anywhere given the same GlobalKey
class CartSwing {
  static final Map<GlobalKey, VoidCallback> _handlers = {};
  static void register(GlobalKey key, VoidCallback handler) => _handlers[key] = handler;
  static void unregister(GlobalKey key) => _handlers.remove(key);
  static void swing(GlobalKey key) => _handlers[key]?.call();
}

class StoreBottomNavBar extends StatelessWidget {
  final int currentIndex; // 0: Home, 1: Shop, 2: Categories, 3: Cart
  final GlobalKey cartKey;
  final void Function(int) onTap;
  final List<String> categories; // used when index 2 tapped
  final void Function()? onCartBump; // notify external pages to swing cart

  const StoreBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.cartKey,
    required this.onTap,
    this.categories = const ['All', 'Relics', 'Scrolls', 'Oils', 'Bundles', 'Charms', 'Artifacts'],
    this.onCartBump,
  });

  @override
  Widget build(BuildContext context) {
    print('StoreBottomNavBar build - currentIndex: $currentIndex, onTap: $onTap');
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1F170C),
          border: Border(top: BorderSide(color: kGold.withValues(alpha: 0.35))),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, -3))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavButton(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
              label: 'Home',
              isSelected: currentIndex == 0,
              onTap: () {
                print('Home button tapped, calling onTap(0)');
                onTap(0);
                print('onTap(0) completed');
              },
            ),
            _NavButton(
              icon: Icons.storefront_outlined,
              selectedIcon: Icons.storefront,
              label: 'WordMart',
              isSelected: currentIndex == 1,
              onTap: () {
                print('WordMart button tapped, calling onTap(1)');
                onTap(1);
                print('onTap(1) completed');
              },
            ),
            _NavButton(
              icon: Icons.category_outlined,
              selectedIcon: Icons.category,
              label: 'Categories',
              isSelected: currentIndex == 2,
              onTap: () {
                print('Categories button tapped');
                _handleCategoriesSheet(context, 2);
              },
            ),
            _NavButton(
              icon: Icons.shopping_cart_outlined,
              selectedIcon: Icons.shopping_cart,
              label: 'Cart',
              isSelected: currentIndex == 3,
              onTap: () {
                print('Cart button tapped');
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CartPage()),
                );
              },
              customIcon: _SwingingCartIcon(key: cartKey),
              customSelectedIcon: _SwingingCartIcon(key: cartKey, selected: true),
            ),
          ],
        ),
      ),
    );
  }

  void _handleCategoriesSheet(BuildContext context, int i) async {
    // Load actual categories from Firestore (active ones), fallback to provided list
    List<String> names = const [];
    try {
      final repo = CategoryRepository();
      final list = await repo.listActive();
      names = list.map((c) => c.name).where((n) => n.isNotEmpty).toList();
    } catch (_) {
      names = const [];
    }
    final sheetCategories = (names.isNotEmpty ? names : categories).where((c) => c != 'All').toList();
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1F170C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CategoriesSheet(
        // Hide the synthetic 'All' from the sheet
        categories: sheetCategories,
      ),
    );
    if (selected != null && context.mounted) {
      // Open category page on top
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StoreCategoryPage(category: selected, cartKey: cartKey),
        ),
      );
    }
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget? customIcon;
  final Widget? customSelectedIcon;

  const _NavButton({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.customIcon,
    this.customSelectedIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              customIcon != null && customSelectedIcon != null
                  ? (isSelected ? customSelectedIcon! : customIcon!)
                  : Icon(
                      isSelected ? selectedIcon : icon,
                      color: isSelected ? kGold : Colors.white70,
                      size: 24,
                    ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.lora(
                  color: isSelected ? kGold : Colors.white70,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwingingCartIcon extends StatefulWidget {
  final bool selected;
  const _SwingingCartIcon({super.key, this.selected = false});

  // registration handled via CartSwing

  @override
  State<_SwingingCartIcon> createState() => _SwingingCartIconState();
}

class _SwingingCartIconState extends State<_SwingingCartIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _angle;
  final cart = CartController.instance;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _angle = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.35), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.35, end: -0.25), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.25, end: 0.15), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.15, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    cart.addListener(_onCartChanged);
    cart.ensureLoaded();
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
    cart.removeListener(_onCartChanged);
    if (widget.key is GlobalKey) {
      CartSwing.unregister(widget.key as GlobalKey);
    }
    _controller.dispose();
    super.dispose();
  }

  void _onCartChanged() => setState(() {});

  void _swing() {
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final baseIcon = Icon(widget.selected ? Icons.shopping_cart : Icons.shopping_cart_outlined,
        color: widget.selected ? kGold : Colors.white70);
    final hasItems = cart.items.isNotEmpty;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (_, child) => Transform.rotate(
            angle: _angle.value,
            alignment: Alignment.topCenter,
            child: child,
          ),
          child: baseIcon,
        ),
        if (hasItems)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: kGold, shape: BoxShape.circle),
            ),
          )
      ],
    );
  }
}

class _CategoriesSheet extends StatelessWidget {
  final List<String> categories;
  const _CategoriesSheet({required this.categories});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text('Categories', style: GoogleFonts.cinzel(color: kGold, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: categories.length,
              separatorBuilder: (_, __) => Divider(color: kGold.withValues(alpha: 0.15)),
              itemBuilder: (context, index) {
                final c = categories[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  title: Text(c, style: GoogleFonts.lora(color: Colors.white, fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                  onTap: () => Navigator.pop(context, c),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
