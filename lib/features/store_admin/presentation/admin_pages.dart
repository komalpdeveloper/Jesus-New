import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:clientapp/core/theme/palette.dart';
import 'package:clientapp/features/store_admin/data/admin_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:clientapp/core/navigation/route_observer.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:clientapp/features/store_admin/data/repositories/category_repository.dart';
import 'package:clientapp/features/store_admin/data/repositories/product_repository.dart';
import 'package:clientapp/features/store_admin/data/repositories/banner_repository.dart';
import 'package:clientapp/features/store_admin/data/services/storage_service.dart';
import 'package:clientapp/features/store_admin/data/services/cloud_functions_service.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../../church_admin/data/models/church_models.dart';
import '../../church_admin/data/repositories/church_repository.dart';
import '../../church_admin/presentation/church_admin_page.dart';
import '../../church_admin/presentation/church_radio_admin_page.dart';
import 'aleph_reader_screen.dart';

// Simple in-memory models for demo admin
// Shared singleton instance so data is consistent across app sessions
final AdminStore adminStore = AdminStore();

class AdminItem {
  AdminItem({
    required this.title,
    required this.price,
    required this.description,
    required this.images,
    required this.category,
    required this.quantity,
    required this.rating,
    required this.reviews,
    this.note,
    this.pngPath,
    this.pngBytes,
  });
  final String title;
  final double price;
  final String description;
  final List<String> images; // file paths
  final String category;
  final int quantity;
  final double rating; // generated automatically
  final int reviews; // generated automatically
  final String? note;
  final String? pngPath; // optional local path to PNG icon
  final Uint8List? pngBytes; // optional bytes for platforms without file path
}

class AdminStore extends ChangeNotifier {
  final List<AdminItem> items = [];
  final List<String> categories = [];
  final List<AdminBanner> banners = [];

  // Backend repositories
  final CategoryRepository _categoryRepo = CategoryRepository();
  final ProductRepository _productRepo = ProductRepository();

  int get itemCount => items.length;
  int get categoryCount => categories.length;
  int get bannerCount => banners.length;

  void addItem(AdminItem item) {
    items.add(item);
    notifyListeners();

    // Fire-and-forget persist to Firestore + Storage
    _persistItem(item);
  }

  // New: Add and await persistence. Returns true on success, false on failure.
  Future<bool> addItemAndPersist(AdminItem item) async {
    try {
      items.add(item);
      notifyListeners();
      await _persistItem(item);
      return true;
    } catch (e) {
      debugPrint('[AdminStore] addItemAndPersist failed: $e');
      return false;
    }
  }

  void addCategory(String name) {
    final n = name.trim();
    if (n.isEmpty) return;
    if (categories.any((c) => c.toLowerCase() == n.toLowerCase()))
      return; // prevent dup
    categories.add(n);
    notifyListeners();

    // Fire-and-forget create in Firestore. Errors are logged to console.
    _categoryRepo
        .create(name: n, order: categories.indexOf(n))
        .then((_) => debugPrint('[AdminStore] Category "$n" saved'))
        .catchError(
          (e, st) => debugPrint('[AdminStore] Failed to save category: $e'),
        );
  }

  // New: add category and await backend completion; returns true/false
  Future<bool> addCategoryAndPersist(String name) async {
    final n = name.trim();
    if (n.isEmpty) return false;
    // Attempt backend first to ensure slug uniqueness and limit checks
    try {
      final created = await _categoryRepo.create(
        name: n,
        order: categories.length,
      );
      if (!categories.any(
        (c) => c.toLowerCase() == created.name.toLowerCase(),
      )) {
        categories.add(created.name);
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[AdminStore] addCategoryAndPersist failed: $e');
      return false;
    }
  }

  Future<bool> removeCategorySafely(String name) async {
    // Check if category exists and whether products reference it
    try {
      final cat = await _categoryRepo.findByName(name);
      if (cat == null) {
        // Not in Firestore; remove locally
        categories.removeWhere((c) => c.toLowerCase() == name.toLowerCase());
        notifyListeners();
        return true;
      }
      final hasProducts = await _productRepo.existsInCategory(cat.slug);
      if (hasProducts) {
        debugPrint(
          '[AdminStore] Cannot delete category "$name" — products exist.',
        );
        return false;
      }

      // Safe to delete in backend then update local state
      await _categoryRepo.deleteByName(name);
      categories.removeWhere((c) => c.toLowerCase() == name.toLowerCase());
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[AdminStore] removeCategorySafely failed: $e');
      return false;
    }
  }

  // Banners helpers
  List<AdminBanner> byPlacement(BannerPlacement p) =>
      banners.where((b) => b.placement == p).toList()
        ..sort((a, b) => a.slot.compareTo(b.slot));

  String? canAddBanner(BannerPlacement p, int slot) {
    final existing = byPlacement(p);
    if (slot < 0 || slot >= p.maxSlots) return 'Invalid slot for ${p.label}';
    if (existing.any((b) => b.slot == slot)) return 'Slot already filled';
    if (existing.length >= p.maxSlots)
      return 'All ${p.maxSlots} slot(s) are already filled';
    return null;
  }

  bool addAdminBanner(AdminBanner b) {
    final err = canAddBanner(b.placement, b.slot);
    if (err != null) return false;
    banners.add(b);
    notifyListeners();
    return true;
  }

  void removeAdminBanner(BannerPlacement p, int slot) {
    banners.removeWhere((b) => b.placement == p && b.slot == slot);
    notifyListeners();
  }

  void addBanner(String name) {
    // legacy no-op retained for backward compatibility
  }

  // Internal: persist listing to Firestore and upload images to Storage via repository
  Future<void> _persistItem(AdminItem item) async {
    // Convert local file paths to Files
    final files = item.images
        .map((p) => File(p))
        .where((f) => f.existsSync())
        .toList();
    debugPrint(
      '[AdminStore] Persisting product "${item.title}" with ${files.length} local image(s)',
    );
    // Ensure category exists (or create) and use its slug as categoryId
    final cat = await _categoryRepo.findByName(item.category);
    if (cat == null) {
      throw Exception(
        'Category "${item.category}" does not exist. Create it first.',
      );
    }
    debugPrint('[AdminStore] Using category slug=${cat.slug}');
    await _productRepo.create(
      title: item.title,
      description: item.description,
      price: item.price,
      imageFiles: files,
      pngFile: (item.pngPath != null && File(item.pngPath!).existsSync())
          ? File(item.pngPath!)
          : null,
      pngBytes: (item.pngPath == null) ? item.pngBytes : null,
      categoryId: cat.slug,
      categoryName: cat.name,
      quantity: item.quantity,
      rating: item.rating,
      reviews: item.reviews,
      note: item.note,
    );
    debugPrint('[AdminStore] Product persisted');
  }

  // New: refresh categories from Firestore and replace local list
  Future<void> refreshCategoriesFromFirestore() async {
    try {
      final remote = await _categoryRepo.listActive();
      categories
        ..clear()
        ..addAll(remote.map((e) => e.name));
      notifyListeners();
    } catch (e) {
      debugPrint('[AdminStore] Failed to load categories: $e');
    }
  }
}

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _emailCtrl = TextEditingController(text: AdminAuth.demoEmail);
  final _passCtrl = TextEditingController(text: AdminAuth.demoPassword);
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // Capture navigator before the async gap to avoid using BuildContext afterwards
    final navigator = Navigator.of(context);
    try {
      final ok = await AdminAuth.login(_emailCtrl.text, _passCtrl.text);
      if (!mounted) return;
      if (ok) {
        navigator.pushReplacement(
          MaterialPageRoute(builder: (_) => AdminHomePage(store: adminStore)),
        );
      } else {
        setState(() {
          _error = 'Invalid email or password';
        });
      }
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepBlack,
      appBar: AppBar(title: const Text('Admin Login')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            color: kRoyalBlue.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: kRoyalBlue),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Wordmart Admin',
                    style: GoogleFonts.cinzel(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: kGold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: kGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Login'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use the demo credentials prefilled above.',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key, required this.store});
  final AdminStore store;

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> with RouteAware {
  int _productCount = 0;
  bool _loading = true;
  List<_RecentVM> _recent = const [];

  @override
  void initState() {
    super.initState();
    _refreshFromBackend();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route changes
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    // Unsubscribe from route observer
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // Called when coming back to this page (e.g., after pushing another route)
  @override
  void didPopNext() {
    _refreshFromBackend();
  }

  Future<void> _refreshFromBackend() async {
    setState(() {
      _loading = true;
    });
    try {
      // Keep categories fresh too
      await widget.store.refreshCategoriesFromFirestore();
      final repo = ProductRepository();
      final recentModels = await repo.listRecent(limit: 6);
      final cnt = await repo.countActive();
      _recent = recentModels
          .map(
            (m) => _RecentVM(
              title: m.title,
              imageUrl: (m.imageUrls.isNotEmpty ? m.imageUrls.first : null),
              subtitle:
                  'Price: \\${m.price.toStringAsFixed(2)} • Cat: \\${m.categoryName} • Qty: \\${m.quantity} • ⭐ \\${m.rating.toStringAsFixed(1)} (\\${m.reviews})',
            ),
          )
          .toList();
      _productCount = cnt;
    } catch (e) {
      debugPrint('[AdminHome] Failed to load recent/count: $e');
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
        });
    }
  }

  Future<void> _triggerManualUpdate(BuildContext context) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kRoyalBlue.withValues(alpha: 0.9),
        title: const Text('Update Store Listings?'),
        content: const Text(
          'This will shuffle and update the Hot, New, and Clearance product lists.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading dialog
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final service = CloudFunctionsService();
      final result = await service.manuallyTriggerUpdate();

      if (!context.mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      // Show result
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Update completed'),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Scaffold(
      backgroundColor: kDeepBlack,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () async {
              // Capture navigator before the async gap to avoid using BuildContext afterwards
              final navigator = Navigator.of(context);
              await AdminAuth.logout();
              if (!mounted) return;
              // Return to the app's root (MainNav) without importing it to avoid cycles
              navigator.popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: RefreshIndicator(
            onRefresh: _refreshFromBackend,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Stat row
                _statsRowFromBackend(),
                const SizedBox(height: 20),
                // Actions grid
                _actionsGrid(context, store),
                const SizedBox(height: 20),
                // Recent listings (optional)
                _recentListingsFromBackend(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statsRowFromBackend() {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            title: 'Items',
            value: _productCount.toString(),
            icon: Icons.inventory_2_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            title: 'Categories',
            value: widget.store.categoryCount.toString(),
            icon: Icons.category_rounded,
          ),
        ),
      ],
    );
  }

  Widget _actionsGrid(BuildContext context, AdminStore store) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Store Section
        _ActionSection(
          title: 'Store',
          icon: Icons.store_rounded,
          actions: [
            _ActionItem(
              label: 'View Listings',
              icon: Icons.list_alt_rounded,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ViewListingsPage(store: store),
                ),
              ),
            ),
            _ActionItem(
              label: 'Add Listing',
              icon: Icons.add_box_rounded,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddListingPage(store: store)),
              ),
            ),
            _ActionItem(
              label: 'Add Category',
              icon: Icons.category_rounded,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddCategoryPage(store: store),
                ),
              ),
            ),
            _ActionItem(
              label: 'Manage Banners',
              icon: Icons.collections_rounded,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ManageBannersPage(store: store),
                ),
              ),
            ),
            _ActionItem(
              label: 'Update Offers',
              icon: Icons.refresh_rounded,
              onTap: () => _triggerManualUpdate(context),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Church Section
        _ActionSection(
          title: 'Church',
          icon: Icons.church,
          actions: [
            _ActionItem(
              label: 'Church Admin',
              icon: Icons.church,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChurchAdminPage()),
              ),
            ),
            _ActionItem(
              label: 'Church Radio',
              icon: Icons.radio,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChurchRadioAdminPage()),
              ),
            ),
            _ActionItem(
              label: 'Aleph Reader',
              icon: Icons.menu_book_rounded,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AlephReaderScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _recentListingsFromBackend() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_recent.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: kRoyalBlue.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kRoyalBlue),
        ),
        child: const Text(
          'No listings yet — add your first listing to see it here.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    final recent = _recent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Listings',
          style: GoogleFonts.cinzel(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: kGold,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recent.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final it = recent[i];
              final img = it.imageUrl;
              return Container(
                width: 220,
                decoration: BoxDecoration(
                  color: kRoyalBlue.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kRoyalBlue),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(12),
                        ),
                        image: img == null
                            ? null
                            : DecorationImage(
                                image: CachedNetworkImageProvider(img),
                                fit: BoxFit.cover,
                              ),
                      ),
                      child: img == null
                          ? const Icon(
                              Icons.image_not_supported,
                              color: Colors.white54,
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            it.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            it.subtitle,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const _StatTile({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: kRoyalBlue.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kRoyalBlue.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kRoyalBlue),
            ),
            child: Icon(icon, color: kGold),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.cinzel(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: kGold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  _ActionItem({required this.label, required this.icon, required this.onTap});
}

class _ActionSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_ActionItem> actions;
  const _ActionSection({
    required this.title,
    required this.icon,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kRoyalBlue.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kRoyalBlue),
              ),
              child: Icon(icon, color: kGold, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: GoogleFonts.cinzel(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: kGold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Action buttons grid
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
            return GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.7,
              ),
              itemCount: actions.length,
              itemBuilder: (_, i) => _ActionTile(item: actions[i]),
            );
          },
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final _ActionItem item;
  const _ActionTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white70, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, color: kGold),
            const SizedBox(width: 10),
            Text(item.label, style: GoogleFonts.lora(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

class _RecentVM {
  final String title;
  final String? imageUrl;
  final String subtitle;
  const _RecentVM({
    required this.title,
    required this.imageUrl,
    required this.subtitle,
  });
}

class ViewListingsPage extends StatefulWidget {
  const ViewListingsPage({super.key, required this.store});
  final AdminStore store;

  @override
  State<ViewListingsPage> createState() => _ViewListingsPageState();
}

class _ViewListingsPageState extends State<ViewListingsPage> {
  bool _loading = true;
  List<_ProductRowVM> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ProductRepository();
      final list = await repo.listAll();
      _rows = list
          .map(
            (m) => _ProductRowVM(
              id: m.id,
              title: m.title,
              subtitle:
                  'Price: ${m.price.toStringAsFixed(2)}  •  Cat: ${m.categoryName}  •  Qty: ${m.quantity}  •  ⭐ ${m.rating.toStringAsFixed(1)} (${m.reviews})',
              imageUrl: m.imageUrls.isNotEmpty ? m.imageUrls.first : null,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('[ViewListings] load failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(String productId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kRoyalBlue.withValues(alpha: 0.9),
        title: const Text('Delete listing?'),
        content: const Text(
          'This will remove the product and its images. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final repo = ProductRepository();
      await repo.delete(productId: productId);
      if (!mounted) return;
      Navigator.of(context).pop(); // close progress
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Listing deleted')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // close progress
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to delete listing')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepBlack,
      appBar: AppBar(title: const Text('Listings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final it = _rows[i];
                  return ListTile(
                    tileColor: kRoyalBlue.withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: kRoyalBlue),
                    ),
                    title: Text(it.title),
                    subtitle: Text(it.subtitle),
                    leading: it.imageUrl == null
                        ? const Icon(Icons.image_not_supported)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: it.imageUrl!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              placeholder: (c, _) =>
                                  Container(color: const Color(0x221F170C)),
                              errorWidget: (c, _, __) => const Icon(
                                Icons.broken_image,
                                size: 18,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.image_outlined,
                            color: Colors.white70,
                          ),
                          tooltip: 'Manage PNG icon',
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ManagePngPage(productId: it.id),
                              ),
                            );
                            await _load();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white70),
                          tooltip: 'Edit listing',
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditListingPage(
                                  store: widget.store,
                                  productId: it.id,
                                ),
                              ),
                            );
                            await _load();
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _delete(it.id),
                          tooltip: 'Delete listing',
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _ProductRowVM {
  final String id;
  final String title;
  final String subtitle;
  final String? imageUrl;
  const _ProductRowVM({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
  });
}

class AddListingPage extends StatefulWidget {
  const AddListingPage({super.key, required this.store});
  final AdminStore store;

  @override
  State<AddListingPage> createState() => _AddListingPageState();
}

class _AddListingPageState extends State<AddListingPage> {
  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<XFile?> _images = [null, null, null];
  // optional PNG icon for the item
  PlatformFile? _png;
  String? _selectedCategory;
  String _qtyMode = 'Random number';
  final _customQtyCtrl = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    // Refresh categories from Firestore on open
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await widget.store.refreshCategoriesFromFirestore();
      if (!mounted) return;
      if (_selectedCategory == null && widget.store.categories.isNotEmpty) {
        setState(() => _selectedCategory = widget.store.categories.first);
      }
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    _noteCtrl.dispose();
    _customQtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(int index) async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x != null) setState(() => _images[index] = x);
  }

  Future<void> _save() async {
    setState(() => _error = null);
    final title = _titleCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim());
    final desc = _descCtrl.text.trim();
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    final cat =
        _selectedCategory ??
        (widget.store.categories.isNotEmpty
            ? widget.store.categories.first
            : '');

    if (title.isEmpty || price == null || desc.isEmpty) {
      setState(() => _error = 'Enter valid title, price and description');
      return;
    }
    if ((cat).isEmpty) {
      setState(() => _error = 'Select a category (create one if empty)');
      return;
    }
    // Determine quantity
    late int qty;
    if (_qtyMode == 'Random number') {
      qty = 50 + Random().nextInt(451); // 50..500
    } else if (_qtyMode == 'Low stock') {
      qty = 1 + Random().nextInt(5); // 1..5
    } else {
      final c = int.tryParse(_customQtyCtrl.text.trim());
      if (c == null || c < 0) {
        setState(() => _error = 'Enter a valid custom quantity');
        return;
      }
      qty = c;
    }

    // Auto-generate rating & reviews (unique-ish)
    final base = 3.8 + Random().nextDouble() * 1.2; // 3.8..5.0
    final rating = double.parse(base.toStringAsFixed(1));
    final reviews = 5 + Random().nextInt(195); // 5..199

    final images = _images.whereType<XFile>().map((x) => x.path).toList();

    final adminItem = AdminItem(
      title: title,
      price: price,
      description: desc,
      images: images,
      category: cat,
      quantity: qty,
      rating: rating,
      reviews: reviews,
      note: note,
      pngPath: _png?.path,
      pngBytes: (_png?.path == null) ? _png?.bytes : null,
    );

    // Show a simple progress indicator while saving
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final ok = await widget.store.addItemAndPersist(adminItem);
    if (!context.mounted) return;
    Navigator.of(context).pop(); // close progress
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(
        () => _error =
            'Failed to save product. Check Storage/Auth configuration.',
      );
    }
  }

  Future<void> _pickPng() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png'],
        withData: true,
      );
      if (res != null && res.files.isNotEmpty) {
        setState(() => _png = res.files.single);
      }
    } on MissingPluginException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'File picker is not initialized. Fully restart the app after adding the plugin.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to open file picker.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepBlack,
      appBar: AppBar(title: const Text('Add Listing')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 160,
                    child: TextField(
                      controller: _priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Price (rings)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Category dropdown
              DropdownButtonFormField<String>(
                value:
                    _selectedCategory ??
                    (widget.store.categories.isNotEmpty
                        ? widget.store.categories.first
                        : null),
                items: widget.store.categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v),
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              // Description
              TextField(
                controller: _descCtrl,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),
              // Note
              TextField(
                controller: _noteCtrl,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  helperText:
                      'If provided, rating will be auto-generated individually',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),
              // Optional PNG icon
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Item PNG icon (optional)',
                  style: GoogleFonts.cinzel(
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kRoyalBlue.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kRoyalBlue),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.image, color: Colors.white70),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _png?.name ?? 'No PNG selected',
                        style: const TextStyle(color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: _pickPng,
                      child: const Text('Choose .png'),
                    ),
                    const SizedBox(width: 8),
                    if (_png != null)
                      IconButton(
                        tooltip: 'Clear',
                        onPressed: () => setState(() => _png = null),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              // Image uploads (3)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Images (3)',
                  style: GoogleFonts.cinzel(
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: List.generate(
                  3,
                  (i) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
                      child: _ImagePickCard(
                        file: _images[i],
                        onPick: () => _pickImage(i),
                        onClear: () => setState(() => _images[i] = null),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // Quantity options
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Quantity',
                  style: GoogleFonts.cinzel(
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _qtyMode,
                      items: const [
                        DropdownMenuItem(
                          value: 'Random number',
                          child: Text('Random number'),
                        ),
                        DropdownMenuItem(
                          value: 'Low stock',
                          child: Text('Low stock'),
                        ),
                        DropdownMenuItem(
                          value: 'Custom number',
                          child: Text('Custom number'),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _qtyMode = v ?? 'Random number'),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_qtyMode == 'Custom number')
                    SizedBox(
                      width: 160,
                      child: TextField(
                        controller: _customQtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),
              if (_error != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EditListingPage extends StatefulWidget {
  const EditListingPage({
    super.key,
    required this.store,
    required this.productId,
  });
  final AdminStore store;
  final String productId;

  @override
  State<EditListingPage> createState() => _EditListingPageState();
}

class _EditListingPageState extends State<EditListingPage> {
  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<XFile?> _images = [null, null, null];
  List<String> _existingImageUrls = [];
  String? _selectedCategory;
  final _qtyCtrl = TextEditingController();
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await widget.store.refreshCategoriesFromFirestore();
      await _load();
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ProductRepository();
      final m = await repo.getById(widget.productId);
      if (m == null) {
        if (mounted) Navigator.pop(context);
        return;
      }
      _titleCtrl.text = m.title;
      _priceCtrl.text = m.price.toStringAsFixed(2);
      _descCtrl.text = m.description;
      _noteCtrl.text = m.note ?? '';
      _qtyCtrl.text = m.quantity.toString();
      _selectedCategory = m.categoryName;
      _existingImageUrls = m.imageUrls;
    } catch (e) {
      debugPrint('[EditListing] load failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage(int index) async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x != null) setState(() => _images[index] = x);
  }

  Future<void> _save() async {
    setState(() => _error = null);
    final title = _titleCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim());
    final desc = _descCtrl.text.trim();
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    final qty = int.tryParse(_qtyCtrl.text.trim());
    final catName =
        _selectedCategory ??
        (widget.store.categories.isNotEmpty
            ? widget.store.categories.first
            : '');

    if (title.isEmpty || price == null || desc.isEmpty || qty == null) {
      setState(
        () => _error = 'Enter valid title, price, quantity and description',
      );
      return;
    }
    if ((catName).isEmpty) {
      setState(() => _error = 'Select a category');
      return;
    }

    // Determine if images replaced
    final picked = _images.whereType<XFile>().toList();
    final replaceImages = picked.isNotEmpty; // if any selected, replace all
    final files = picked.map((x) => File(x.path)).toList();

    // Resolve category slug
    final catRepo = CategoryRepository();
    final cat = await catRepo.getOrCreateByName(catName);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final repo = ProductRepository();
      await repo.update(
        id: widget.productId,
        title: title,
        description: desc,
        price: price,
        newImageFiles: replaceImages ? files : null,
        categoryId: cat.slug,
        categoryName: cat.name,
        quantity: qty,
        note: note,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() => _error = 'Failed to save changes.');
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    _noteCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepBlack,
      appBar: AppBar(title: const Text('Edit Listing')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _titleCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Title',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 160,
                          child: TextField(
                            controller: _priceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Price (rings)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value:
                          _selectedCategory ??
                          (widget.store.categories.isNotEmpty
                              ? widget.store.categories.first
                              : null),
                      items: widget.store.categories
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCategory = v),
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),
                    TextField(
                      controller: _descCtrl,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),
                    TextField(
                      controller: _noteCtrl,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),
                    TextField(
                      controller: _qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Images',
                        style: GoogleFonts.cinzel(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: kGold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (int i = 0; i < 3; i++) ...[
                          Expanded(
                            child: _ImagePickCard(
                              file: _images[i],
                              placeholder: i < _existingImageUrls.length
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: CachedNetworkImage(
                                        imageUrl: _existingImageUrls[i],
                                        fit: BoxFit.cover,
                                        placeholder: (c, _) => Container(
                                          color: const Color(0x221F170C),
                                        ),
                                        errorWidget: (c, _, __) => const Icon(
                                          Icons.broken_image,
                                          color: Colors.white54,
                                        ),
                                      ),
                                    )
                                  : null,
                              onPick: () => _pickImage(i),
                              onClear: () => setState(() => _images[i] = null),
                            ),
                          ),
                          if (i < 2) const SizedBox(width: 10),
                        ],
                      ],
                    ),

                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FilledButton(
                          onPressed: _save,
                          child: const Text('Save Changes'),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

class _ImagePickCard extends StatelessWidget {
  final XFile? file;
  final Widget? placeholder; // optional remote preview when no file picked
  final VoidCallback onPick;
  final VoidCallback onClear;
  const _ImagePickCard({
    required this.file,
    this.placeholder,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: kRoyalBlue.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kRoyalBlue),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: file != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(file!.path), fit: BoxFit.cover),
                  )
                : (placeholder ??
                      const Center(
                        child: Icon(Icons.image, color: Colors.white54),
                      )),
          ),
          Positioned(
            bottom: 6,
            left: 6,
            child: FilledButton.tonal(
              onPressed: onPick,
              child: const Text('Pick'),
            ),
          ),
          if (file != null)
            Positioned(
              top: 6,
              right: 6,
              child: IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close, color: Colors.white70),
                style: IconButton.styleFrom(backgroundColor: Colors.black45),
              ),
            ),
        ],
      ),
    );
  }
}

class AddCategoryPage extends StatefulWidget {
  const AddCategoryPage({super.key, required this.store});
  final AdminStore store;
  @override
  State<AddCategoryPage> createState() => _AddCategoryPageState();
}

class _AddCategoryPageState extends State<AddCategoryPage> {
  final _nameCtrl = TextEditingController();
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await widget.store.refreshCategoriesFromFirestore();
    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepBlack,
      appBar: AppBar(title: const Text('Add Category')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current list
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Current categories',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${widget.store.categories.length}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kRoyalBlue.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kRoyalBlue),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in widget.store.categories)
                          Chip(
                            label: Text(c),
                            backgroundColor: kRoyalBlue.withValues(alpha: 0.5),
                            labelStyle: const TextStyle(color: Colors.white),
                            deleteIconColor: Colors.white70,
                            onDeleted: () async {
                              final ok = await widget.store
                                  .removeCategorySafely(c);
                              if (!ok && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Cannot delete: products exist in this category',
                                    ),
                                  ),
                                );
                              }
                              if (mounted) setState(() {});
                            },
                          ),
                        if (widget.store.categories.isEmpty)
                          const Text(
                            'No categories yet',
                            style: TextStyle(color: Colors.white60),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'Tip: too many categories can be harder to browse.',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'New category name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () async {
                          setState(() {
                            _error = null;
                          });
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                          final ok = await widget.store.addCategoryAndPersist(
                            _nameCtrl.text,
                          );
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          if (ok) {
                            _nameCtrl.clear();
                            await widget.store.refreshCategoriesFromFirestore();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Category added')),
                            );
                            setState(() {});
                          } else {
                            setState(() {
                              _error =
                                  'Failed to add category (duplicate or rules).';
                            });
                          }
                        },
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

// ======== Banners Management ========

enum BannerPlacement { homeMain, homeSub, storeSub }

extension BannerPlacementX on BannerPlacement {
  String get label => switch (this) {
    BannerPlacement.homeMain => 'Home • Main Banner',
    BannerPlacement.homeSub => 'Home • Sub Banners',
    BannerPlacement.storeSub => 'Store Page • Banners',
  };
  int get maxSlots => switch (this) {
    BannerPlacement.homeMain => 1,
    BannerPlacement.homeSub => 3,
    BannerPlacement.storeSub => 3,
  };
}

class AdminBanner {
  final String imagePath; // local file path for now
  final BannerPlacement placement;
  final int slot; // 0-based index within placement
  AdminBanner({
    required this.imagePath,
    required this.placement,
    required this.slot,
  }) : assert(slot >= 0);
}

// (extension removed - now methods live inside AdminStore)

class ManageBannersPage extends StatefulWidget {
  const ManageBannersPage({super.key, required this.store});
  final AdminStore store;

  @override
  State<ManageBannersPage> createState() => _ManageBannersPageState();
}

class _ManageBannersPageState extends State<ManageBannersPage> {
  final _repo = BannerRepository();
  final _storage = StorageService();

  List<BannerDoc> _homeMain = const [];
  List<BannerDoc> _homeSub = const [];
  List<BannerDoc> _storeSub = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final hm = await _repo.listByPlacement('homeMain');
      final hs = await _repo.listByPlacement('homeSub');
      final ss = await _repo.listByPlacement('storeSub');
      _homeMain = hm;
      _homeSub = hs;
      _storeSub = ss;
    } catch (e) {
      debugPrint('[Banners] load failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _placementToStr(BannerPlacement p) => switch (p) {
    BannerPlacement.homeMain => 'homeMain',
    BannerPlacement.homeSub => 'homeSub',
    BannerPlacement.storeSub => 'storeSub',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepBlack,
      appBar: AppBar(title: const Text('Manage Banners')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section(BannerPlacement.homeMain),
                const SizedBox(height: 16),
                _section(BannerPlacement.homeSub),
                const SizedBox(height: 16),
                _section(BannerPlacement.storeSub),
              ],
            ),
    );
  }

  Widget _section(BannerPlacement placement) {
    final items = switch (placement) {
      BannerPlacement.homeMain => _homeMain,
      BannerPlacement.homeSub => _homeSub,
      BannerPlacement.storeSub => _storeSub,
    };
    final max = placement.maxSlots;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              placement.label,
              style: GoogleFonts.cinzel(
                fontWeight: FontWeight.w700,
                color: kGold,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${items.length}/$max active)',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(max, (i) {
            final found = items.where((b) => b.slot == i).toList();
            if (found.isEmpty) {
              return _emptyTile(placement, i);
            }
            final b = found.first;
            return _bannerTile(placement, b.slot, b.imageUrl);
          }),
        ),
      ],
    );
  }

  Widget _bannerTile(BannerPlacement p, int slot, String imageUrl) {
    return Stack(
      children: [
        Container(
          width: 160,
          height: 90,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kRoyalBlue),
            image: DecorationImage(
              image: NetworkImage(imageUrl),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton(
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(backgroundColor: Colors.black54),
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: () async {
              final placementStr = _placementToStr(p);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    const Center(child: CircularProgressIndicator()),
              );
              try {
                await _storage.deleteBannerImage(
                  placement: placementStr,
                  slot: slot,
                );
                await _repo.delete(placement: placementStr, slot: slot);
                if (mounted) Navigator.of(context).pop();
                await _loadAll();
              } catch (e) {
                if (mounted) Navigator.of(context).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete banner')),
                  );
                }
              }
            },
          ),
        ),
        Positioned(
          bottom: 4,
          left: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Slot ${slot + 1}',
              style: const TextStyle(fontSize: 11, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyTile(BannerPlacement placement, int slot) {
    return InkWell(
      onTap: () async {
        final changed = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddBannerFormPage(
              store: widget.store,
              initialPlacement: placement,
              initialSlot: slot,
            ),
          ),
        );
        if (changed == true) await _loadAll();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 160,
        height: 90,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kRoyalBlue),
          color: kRoyalBlue.withValues(alpha: 0.25),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, color: Colors.white70, size: 20),
            const SizedBox(height: 4),
            Text(
              'Add banner in slot ${slot + 1}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class AddBannerFormPage extends StatefulWidget {
  const AddBannerFormPage({
    super.key,
    required this.store,
    required this.initialPlacement,
    required this.initialSlot,
  });
  final AdminStore store;
  final BannerPlacement initialPlacement;
  final int initialSlot;

  @override
  State<AddBannerFormPage> createState() => _AddBannerFormPageState();
}

class _AddBannerFormPageState extends State<AddBannerFormPage> {
  late final BannerPlacement _placement;
  late final int _slot;
  XFile? _file;
  final _picker = ImagePicker();
  String? _error;
  final _storage = StorageService();
  final _repo = BannerRepository();

  String _placementToStr(BannerPlacement p) => switch (p) {
    BannerPlacement.homeMain => 'homeMain',
    BannerPlacement.homeSub => 'homeSub',
    BannerPlacement.storeSub => 'storeSub',
  };

  @override
  void initState() {
    super.initState();
    _placement = widget.initialPlacement;
    _slot = widget.initialSlot;
  }

  Future<void> _pick() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x != null) setState(() => _file = x);
  }

  void _save() {
    setState(() => _error = null);
    if (_file == null) {
      setState(() => _error = 'Please select an image');
      return;
    }
    final err = widget.store.canAddBanner(_placement, _slot);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    () async {
      try {
        // Double-check remote slot not occupied
        final exists = await _repo.exists(
          placement: _placementToStr(_placement),
          slot: _slot,
        );
        if (exists) {
          if (!mounted) return;
          Navigator.of(context).pop();
          setState(() => _error = 'Slot already filled remotely');
          return;
        }
        final url = await _storage.uploadBannerImage(
          placement: _placementToStr(_placement),
          slot: _slot,
          file: File(_file!.path),
        );
        await _repo.upsert(
          placement: _placementToStr(_placement),
          slot: _slot,
          imageUrl: url,
          isActive: true,
        );
        if (!mounted) return;
        Navigator.of(context).pop(); // close progress
        Navigator.pop(context, true);
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context).pop(); // close progress
        setState(() => _error = 'Failed to upload banner');
      }
    }();
  }

  @override
  Widget build(BuildContext context) {
    // Placement and slot are preselected and hidden.
    return Scaffold(
      backgroundColor: kDeepBlack,
      appBar: AppBar(title: const Text('Add Banner')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Placement and slot are provided by the tile tap; only upload image here.
            SizedBox(
              width: double.infinity,
              height: 160,
              child: InkWell(
                onTap: _pick,
                child: Container(
                  decoration: BoxDecoration(
                    color: kRoyalBlue.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kRoyalBlue),
                    image: _file == null
                        ? null
                        : DecorationImage(
                            image: FileImage(File(_file!.path)),
                            fit: BoxFit.cover,
                          ),
                  ),
                  child: _file == null
                      ? const Center(
                          child: Text(
                            'Tap to upload image',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : null,
                ),
              ),
            ),

            const SizedBox(height: 12),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: _save, child: const Text('Save')),
            ),
          ],
        ),
      ),
    );
  }
}

// ======== Church Admin ========

class ChurchAdminPage extends StatefulWidget {
  const ChurchAdminPage({super.key});
  @override
  State<ChurchAdminPage> createState() => _ChurchAdminPageState();
}

class _ChurchAdminPageState extends State<ChurchAdminPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepBlack,
      appBar: AppBar(
        title: const Text('Church Admin'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Sermons'),
            Tab(text: 'Stories'),
            Tab(text: 'Sacraments'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _ChurchSectionView(section: ChurchSection.sermons),
          _ChurchSectionView(section: ChurchSection.stories),
          _ChurchSectionView(section: ChurchSection.sacraments),
        ],
      ),
    );
  }
}

class _ChurchSectionView extends StatefulWidget {
  final ChurchSection section;
  const _ChurchSectionView({required this.section});
  @override
  State<_ChurchSectionView> createState() => _ChurchSectionViewState();
}

class _ChurchSectionViewState extends State<_ChurchSectionView> {
  final _repo = ChurchRepository();
  bool _loading = true;
  List<ChurchMainItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _items = await _repo.listMain(widget.section);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final changed = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ChurchAddMainPage(section: widget.section),
                        ),
                      );
                      if (changed == true) await _load();
                    },
                    icon: const Icon(Icons.add),
                    label: Text('Add ${widget.section.label} item'),
                  ),
                ),
                const SizedBox(height: 12),
                for (final it in _items) ...[
                  _ChurchMainTile(
                    section: widget.section,
                    item: it,
                    onChanged: _load,
                  ),
                  const SizedBox(height: 10),
                ],
                if (_items.isEmpty)
                  const Text(
                    'No items yet',
                    style: TextStyle(color: Colors.white70),
                  ),
              ],
            ),
          );
  }
}

class ChurchAddMainPage extends StatefulWidget {
  final ChurchSection section;
  const ChurchAddMainPage({super.key, required this.section});
  @override
  State<ChurchAddMainPage> createState() => _ChurchAddMainPageState();
}

class _ChurchAddMainPageState extends State<ChurchAddMainPage> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  File? _thumbFile;
  PlatformFile? _audio;
  final _picker = ImagePicker();
  final _repo = ChurchRepository();
  String? _error;
  double _uploadProgress = 0.0;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickThumb() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x != null) setState(() => _thumbFile = File(x.path));
  }

  Future<void> _pickAudio() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['mp3', 'm4a', 'aac'],
        withData: true,
      );
      if (res != null && res.files.isNotEmpty)
        setState(() => _audio = res.files.single);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to select audio')));
    }
  }

  Future<void> _save() async {
    setState(() => _error = null);
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Enter a title');
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      _uploadProgress = 0.0;
      await _repo.createMain(
        section: widget.section,
        title: title,
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        thumbnailFile: _thumbFile,
        audioBytes: _audio?.bytes,
        onAudioProgress: (p) {
          setState(() {
            _uploadProgress = p;
          });
        },
        audioContentType:
            (_audio != null &&
                _audio!.extension != null &&
                _audio!.extension!.toLowerCase() == 'm4a')
            ? 'audio/mp4'
            : 'audio/mpeg',
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() => _error = 'Failed to save item');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepBlack,
      appBar: AppBar(title: Text('Add ${widget.section.label} Item')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PickFileCard(
                    label: 'Thumbnail (optional)',
                    onTap: _pickThumb,
                    picked: _thumbFile?.path != null ? 'Selected' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PickFileCard(
                    label: 'Main audio (optional)',
                    onTap: _pickAudio,
                    picked: _audio?.name,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2A1E1E),
                border: Border.all(color: const Color(0xFF6E3D3D)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'If you add main item audio, you can\'t add sub items for this item. If you want to add sub items, do not add a main item audio.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            if (_audio != null) ...[
              const SizedBox(height: 8),
              _UploadProgressBar(
                progress: _uploadProgress,
                visible: _uploadProgress > 0 && _uploadProgress < 1,
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: _save, child: const Text('Save')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChurchMainTile extends StatelessWidget {
  final ChurchSection section;
  final ChurchMainItem item;
  final Future<void> Function() onChanged;
  const _ChurchMainTile({
    required this.section,
    required this.item,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kRoyalBlue.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kRoyalBlue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (item.thumbnailUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    item.thumbnailUrl!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.cinzel(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.description != null &&
                        item.description!.isNotEmpty)
                      Text(
                        item.description!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit details',
                icon: const Icon(Icons.edit),
                onPressed: () async {
                  final changed = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChurchEditMainDetailsPage(
                        section: section,
                        item: item,
                      ),
                    ),
                  );
                  if (changed == true) await onChanged();
                },
              ),
              if (item.audioUrl == null)
                IconButton(
                  tooltip: 'Manage subitems',
                  icon: const Icon(Icons.playlist_add),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChurchSubitemsPage(
                          section: section,
                          mainItem: item,
                        ),
                      ),
                    );
                    await onChanged();
                  },
                ),
              IconButton(
                tooltip: 'Add/Replace audio',
                icon: const Icon(Icons.audiotrack),
                onPressed: () async {
                  final changed = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChurchEditMainAudioPage(
                        section: section,
                        mainId: item.id,
                        hasAudio: item.audioUrl != null,
                      ),
                    ),
                  );
                  if (changed == true) await onChanged();
                },
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Delete?'),
                      content: const Text(
                        'This will remove the item and its files.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    final repo = ChurchRepository();
                    await repo.deleteMain(section, item.id);
                    await onChanged();
                  }
                },
              ),
            ],
          ),
          if (item.audioUrl != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: const [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amber,
                    size: 16,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'This item has a main audio. Subitems are disabled.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          if (item.audioUrl != null) ...[
            const SizedBox(height: 6),
            _InlineAudioPlayer(url: item.audioUrl!),
          ],
        ],
      ),
    );
  }
}

class ChurchEditMainDetailsPage extends StatefulWidget {
  final ChurchSection section;
  final ChurchMainItem item;
  const ChurchEditMainDetailsPage({
    super.key,
    required this.section,
    required this.item,
  });
  @override
  State<ChurchEditMainDetailsPage> createState() =>
      _ChurchEditMainDetailsPageState();
}

class _ChurchEditMainDetailsPageState extends State<ChurchEditMainDetailsPage> {
  final _repo = ChurchRepository();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  File? _thumbFile;
  final _picker = ImagePicker();
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleCtrl.text = widget.item.title;
    _descCtrl.text = widget.item.description ?? '';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickThumb() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x != null) setState(() => _thumbFile = File(x.path));
  }

  Future<void> _save() async {
    setState(() => _error = null);
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Enter title');
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await _repo.updateMain(
        section: widget.section,
        id: widget.item.id,
        title: title,
        description: _descCtrl.text.trim(),
        newThumbnail: _thumbFile,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() => _error = 'Failed to update');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepBlack,
      appBar: AppBar(title: const Text('Edit Main Details')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PickFileCard(
                    label: 'Replace thumbnail',
                    onTap: _pickThumb,
                    picked: _thumbFile?.path != null ? 'Selected' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: _save, child: const Text('Save')),
            ),
          ],
        ),
      ),
    );
  }
}

class ChurchEditMainAudioPage extends StatefulWidget {
  final ChurchSection section;
  final String mainId;
  final bool hasAudio;
  const ChurchEditMainAudioPage({
    super.key,
    required this.section,
    required this.mainId,
    required this.hasAudio,
  });
  @override
  State<ChurchEditMainAudioPage> createState() =>
      _ChurchEditMainAudioPageState();
}

class _ChurchEditMainAudioPageState extends State<ChurchEditMainAudioPage> {
  final _repo = ChurchRepository();
  PlatformFile? _audio;
  String? _error;
  Future<void> _pickAudio() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'm4a', 'aac'],
      withData: true,
    );
    if (res != null && res.files.isNotEmpty)
      setState(() => _audio = res.files.single);
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (_audio == null && !widget.hasAudio) {
      setState(() => _error = 'Pick an audio');
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await _repo.updateMain(
        section: widget.section,
        id: widget.mainId,
        newAudioBytes: _audio?.bytes,
        removeAudio: _audio == null && widget.hasAudio,
        audioContentType:
            (_audio != null &&
                _audio!.extension != null &&
                _audio!.extension!.toLowerCase() == 'm4a')
            ? 'audio/mp4'
            : 'audio/mpeg',
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() => _error = 'Failed to update');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kDeepBlack,
    appBar: AppBar(title: const Text('Edit Main Audio')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _PickFileCard(
            label: 'Select audio',
            onTap: _pickAudio,
            picked: _audio?.name,
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(onPressed: _save, child: const Text('Save')),
          ),
        ],
      ),
    ),
  );
}

class ChurchSubitemsPage extends StatefulWidget {
  final ChurchSection section;
  final ChurchMainItem mainItem;
  const ChurchSubitemsPage({
    super.key,
    required this.section,
    required this.mainItem,
  });
  @override
  State<ChurchSubitemsPage> createState() => _ChurchSubitemsPageState();
}

class _ChurchSubitemsPageState extends State<ChurchSubitemsPage> {
  final _repo = ChurchRepository();
  bool _loading = true;
  List<ChurchSubItem> _subs = const [];
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  File? _thumbFile;
  final _picker = ImagePicker();
  PlatformFile? _audio;
  String? _error;
  double _uploadProgress = 0.0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _subs = await _repo.listSubItems(widget.section, widget.mainItem.id);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickAudio() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'm4a', 'aac'],
      withData: true,
    );
    if (res != null && res.files.isNotEmpty)
      setState(() => _audio = res.files.single);
  }

  Future<void> _pickThumb() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x != null) setState(() => _thumbFile = File(x.path));
  }

  Future<void> _add() async {
    setState(() => _error = null);
    final title = _titleCtrl.text.trim();
    if (title.isEmpty || _audio?.bytes == null) {
      setState(() => _error = 'Enter title and pick audio');
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Material(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: 360,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Uploading…',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 12),
                          _UploadProgressBar(
                            progress: _uploadProgress,
                            visible: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    try {
      _uploadProgress = 0.0;
      await _repo.addSubItem(
        section: widget.section,
        mainId: widget.mainItem.id,
        title: title,
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        thumbnailFile: _thumbFile,
        audioBytes: _audio!.bytes!,
        audioContentType:
            (_audio!.extension != null &&
                _audio!.extension!.toLowerCase() == 'm4a')
            ? 'audio/mp4'
            : 'audio/mpeg',
        onAudioProgress: (p) {
          _uploadProgress = p;
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      _titleCtrl.clear();
      _descCtrl.clear();
      setState(() => _audio = null);
      setState(() => _thumbFile = null);
      await _load();
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() => _error = 'Failed to add');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepBlack,
      appBar: AppBar(title: Text('${widget.mainItem.title} • Subitems')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Add subitem',
                  style: GoogleFonts.cinzel(
                    fontWeight: FontWeight.w700,
                    color: kGold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PickFileCard(
                        label: 'Audio',
                        onTap: _pickAudio,
                        picked: _audio?.name,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _PickFileCard(
                        label: 'Thumbnail (optional)',
                        onTap: _pickThumb,
                        picked: _thumbFile?.path != null ? 'Selected' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(onPressed: _add, child: const Text('Add')),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Subitems',
                  style: GoogleFonts.cinzel(
                    fontWeight: FontWeight.w700,
                    color: kGold,
                  ),
                ),
                const SizedBox(height: 8),
                for (final s in _subs)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kRoyalBlue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kRoyalBlue),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (s.thumbnailUrl != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              s.thumbnailUrl!,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (s.description != null &&
                                  s.description!.isNotEmpty)
                                Text(
                                  s.description!,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 4),
                              _InlineAudioPlayer(url: s.audioUrl),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            final changed = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChurchEditSubItemPage(
                                  section: widget.section,
                                  mainId: widget.mainItem.id,
                                  item: s,
                                ),
                              ),
                            );
                            if (changed == true) await _load();
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                          ),
                          onPressed: () async {
                            await _repo.deleteSubItem(
                              widget.section,
                              widget.mainItem.id,
                              s.id,
                            );
                            await _load();
                          },
                        ),
                      ],
                    ),
                  ),
                if (_subs.isEmpty)
                  const Text(
                    'No subitems yet',
                    style: TextStyle(color: Colors.white70),
                  ),
              ],
            ),
    );
  }
}

class ChurchEditSubItemPage extends StatefulWidget {
  final ChurchSection section;
  final String mainId;
  final ChurchSubItem item;
  const ChurchEditSubItemPage({
    super.key,
    required this.section,
    required this.mainId,
    required this.item,
  });
  @override
  State<ChurchEditSubItemPage> createState() => _ChurchEditSubItemPageState();
}

class _ChurchEditSubItemPageState extends State<ChurchEditSubItemPage> {
  final _repo = ChurchRepository();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  File? _thumbFile;
  final _picker = ImagePicker();
  PlatformFile? _audio;
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleCtrl.text = widget.item.title;
    _descCtrl.text = widget.item.description ?? '';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickThumb() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x != null) setState(() => _thumbFile = File(x.path));
  }

  Future<void> _pickAudio() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'm4a', 'aac'],
      withData: true,
    );
    if (res != null && res.files.isNotEmpty)
      setState(() => _audio = res.files.single);
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter title');
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await _repo.updateSubItem(
        section: widget.section,
        mainId: widget.mainId,
        id: widget.item.id,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        newThumbnail: _thumbFile,
        newAudioBytes: _audio?.bytes,
        audioContentType:
            (_audio?.extension != null &&
                _audio!.extension!.toLowerCase() == 'm4a')
            ? 'audio/mp4'
            : 'audio/mpeg',
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() => _error = 'Failed to update');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepBlack,
      appBar: AppBar(title: const Text('Edit Subitem')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PickFileCard(
                    label: 'Replace thumbnail (optional)',
                    onTap: _pickThumb,
                    picked: _thumbFile?.path != null ? 'Selected' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PickFileCard(
                    label: 'Replace audio (optional)',
                    onTap: _pickAudio,
                    picked: _audio?.name,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: _save, child: const Text('Save')),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadProgressBar extends StatelessWidget {
  final double progress; // 0..1
  final bool visible;
  const _UploadProgressBar({required this.progress, this.visible = true});
  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: progress > 0 && progress < 1 ? progress : null,
            backgroundColor: Colors.white12,
            color: kGold,
          ),
        ),

        // const SizedBox(height: 6),
        // Text('Uploading audio… $pct%', style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }
}

class _PickFileCard extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final String? picked;
  const _PickFileCard({required this.label, required this.onTap, this.picked});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: kRoyalBlue.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kRoyalBlue),
        ),
        child: Row(
          children: [
            const Icon(Icons.attach_file),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                picked ?? label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.upload_file),
          ],
        ),
      ),
    );
  }
}

// ======== Manage PNG for a Product ========

class ManagePngPage extends StatefulWidget {
  const ManagePngPage({super.key, required this.productId});
  final String productId;

  @override
  State<ManagePngPage> createState() => _ManagePngPageState();
}

class _ManagePngPageState extends State<ManagePngPage> {
  final _repo = ProductRepository();
  PlatformFile? _png;
  String? _currentPngUrl;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final m = await _repo.getById(widget.productId);
      _currentPngUrl = m?.productPNGurl;
    } catch (e) {
      _error = 'Failed to load item';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickPng() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png'],
        withData: true,
      );
      if (res != null && res.files.isNotEmpty)
        setState(() => _png = res.files.single);
    } on MissingPluginException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'File picker is not initialized. Fully restart the app after adding the plugin.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to open file picker.')),
      );
    }
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (_png == null && _currentPngUrl == null) {
      setState(() => _error = 'Pick a PNG or remove existing');
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await _repo.update(
        id: widget.productId,
        newPngFile: (_png?.path != null) ? File(_png!.path!) : null,
        newPngBytes: (_png?.path == null && _png?.bytes != null)
            ? _png!.bytes
            : null,
        removePng:
            _png == null &&
            _currentPngUrl !=
                null, // clear if user removed selection and there was existing
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() => _error = 'Failed to update PNG');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepBlack,
      appBar: AppBar(title: const Text('Manage Item PNG')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kRoyalBlue.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kRoyalBlue),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.image, color: Colors.white70),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _png?.name ??
                                (_currentPngUrl != null
                                    ? 'Existing PNG set'
                                    : 'No PNG selected'),
                            style: const TextStyle(color: Colors.white70),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: _pickPng,
                          child: const Text('Choose .png'),
                        ),
                        const SizedBox(width: 8),
                        if (_png != null || _currentPngUrl != null)
                          IconButton(
                            tooltip: 'Remove',
                            onPressed: () => setState(() {
                              _png = null;
                              _currentPngUrl = null;
                            }),
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.redAccent,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _save,
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ======== Inline Audio Player (preview) ========
class _InlineAudioPlayer extends StatefulWidget {
  const _InlineAudioPlayer({required this.url});
  final String url;

  @override
  State<_InlineAudioPlayer> createState() => _InlineAudioPlayerState();
}

class _InlineAudioPlayerState extends State<_InlineAudioPlayer> {
  late final AudioPlayer _player;
  String? _error;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    // Don't load audio on init - wait for user to press play
  }

  @override
  void didUpdateWidget(covariant _InlineAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _initialized = false;
      _error = null;
      _player.stop();
    }
  }

  Future<void> _init() async {
    if (_initialized) return;
    setState(() => _error = null);
    try {
      final audioSource = AudioSource.uri(
        Uri.parse(widget.url),
        tag: MediaItem(
          id: widget.url,
          album: "Church Admin",
          title: "Audio Preview",
          artUri: Uri.parse(
            'https://firebasestorage.googleapis.com/v0/b/test-61111.appspot.com/o/church%2Fradio%2Fchurch_radio_logo.png?alt=media&token=d63335d3-52f1-473a-a2a7-0a454a5a5e5f',
          ),
        ),
      );
      await _player.setAudioSource(audioSource);
      _initialized = true;
    } catch (e) {
      setState(() => _error = 'Failed to load audio');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final two = (int n) => n.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final h = d.inHours;
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Text(
        _error!,
        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
      );
    }
    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, snapState) {
        final state = snapState.data;
        final playing = state?.playing ?? false;
        final processing = state?.processingState;
        final buffering =
            processing == ProcessingState.loading ||
            processing == ProcessingState.buffering;
        final duration = _player.duration ?? Duration.zero;
        return Row(
          children: [
            if (buffering)
              const SizedBox(
                width: 32,
                height: 32,
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                tooltip: playing ? 'Pause' : 'Play',
                icon: Icon(
                  playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                ),
                onPressed: () async {
                  if (playing) {
                    await _player.pause();
                  } else {
                    // Ensure source is loaded
                    if (_player.audioSource == null) {
                      await _init();
                    }
                    await _player.play();
                  }
                },
              ),
            Expanded(
              child: StreamBuilder<Duration>(
                stream: _player.positionStream,
                builder: (context, snapPos) {
                  final pos = snapPos.data ?? Duration.zero;
                  final max = duration.inMilliseconds > 0
                      ? duration.inMilliseconds.toDouble()
                      : 1.0;
                  final val = pos.inMilliseconds
                      .clamp(0, max.toInt())
                      .toDouble();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Slider(
                        value: val,
                        min: 0,
                        max: max,
                        onChanged: (d) =>
                            _player.seek(Duration(milliseconds: d.toInt())),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _fmt(pos),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            _fmt(duration),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
