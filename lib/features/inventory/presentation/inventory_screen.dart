import 'dart:math';
import 'package:clientapp/features/temple_window/presentation/game_webview.dart';
import 'package:clientapp/shared/widgets/back_nav_button.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/inventory_item.dart';
import 'widgets/item_action_dialog.dart';
import 'widgets/flying_item_animation.dart';
import 'package:clientapp/features/store/presentation/store_shell.dart';
import 'package:clientapp/core/services/purchase_service.dart';
import 'package:clientapp/core/models/purchased_item.dart';
import 'package:clientapp/shared/widgets/confetti_overlay.dart';
import 'package:clientapp/shared/widgets/animated_loading_indicator.dart';
import 'package:clientapp/features/store_admin/data/repositories/product_repository.dart';
import '../services/dock_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with TickerProviderStateMixin {
  final GlobalKey _dockKey = GlobalKey();
  AnimationController? _dockShakeController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final GlobalKey<ConfettiOverlayState> _confettiKey = GlobalKey<ConfettiOverlayState>();

  // Inventory items loaded from Firestore
  List<InventoryItem> _inventoryItems = [];
  final _productRepo = ProductRepository();
  
  // Cache the last loaded purchased items to avoid rebuilding
  Map<String, PurchasedItem>? _cachedPurchasedItems;

  @override
  void initState() {
    super.initState();
    _dockShakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    DockService.instance.addListener(_onDockChanged);
  }

  @override
  void dispose() {
    DockService.instance.removeListener(_onDockChanged);
    _dockShakeController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onDockChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  List<InventoryItem> get _filteredItems {
    // Calculate quantities in dock for each item
    final dockQuantities = <String, int>{};
    for (final dockItem in DockService.instance.dockItems) {
      if (dockItem != null) {
        dockQuantities[dockItem.id] = (dockQuantities[dockItem.id] ?? 0) + dockItem.quantity;
      }
    }
    
    // Adjust inventory items by subtracting dock quantities
    final adjustedItems = _inventoryItems.map((item) {
      final inDock = dockQuantities[item.id] ?? 0;
      final availableQty = item.quantity - inDock;
      
      if (availableQty <= 0) {
        return null; // Don't show items that are fully in dock
      }
      
      return InventoryItem(
        id: item.id,
        name: item.name,
        quantity: availableQty,
        description: item.description,
        value: item.value,
        imageUrl: item.imageUrl,
        productPngUrl: item.productPngUrl,
      );
    }).whereType<InventoryItem>().toList();
    
    if (_searchQuery.isEmpty) {
      return adjustedItems;
    }
    return adjustedItems
        .where(
          (item) =>
              item.name.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  bool _hasDataChanged(Map<String, PurchasedItem> oldData, Map<String, PurchasedItem> newData) {
    // Check if keys are different
    if (oldData.keys.length != newData.keys.length) return true;
    if (!oldData.keys.every((key) => newData.containsKey(key))) return true;
    
    // Check if any quantities or sacrificed counts changed
    for (final key in oldData.keys) {
      final oldItem = oldData[key]!;
      final newItem = newData[key];
      if (newItem == null) return true;
      if (oldItem.quantity != newItem.quantity) return true;
      if (oldItem.sacrificedCount != newItem.sacrificedCount) return true;
    }
    
    return false;
  }

  Future<List<InventoryItem>> _loadInventoryItems(Map<String, PurchasedItem> purchasedItems) async {
    if (purchasedItems.isEmpty) {
      return [];
    }

    try {
      // Get all unique product IDs
      final productIds = purchasedItems.values.map((item) => item.productId).toList();
      
      debugPrint('[Inventory] Loading ${productIds.length} products: $productIds');
      
      // Fetch product details from Firestore
      final products = await _productRepo.getByIds(productIds, onlyActive: false);
      
      debugPrint('[Inventory] Fetched ${products.length} products from Firestore');
      
      // Create a map for quick lookup
      final productMap = {for (var p in products) p.id: p};
      
      // Convert to inventory items
      return purchasedItems.values.map((item) {
        final product = productMap[item.productId];
        
        // Calculate available quantity: total - sacrificed
        final availableQuantity = item.quantity - item.sacrificedCount;
        
        if (availableQuantity <= 0) {
          return null; // Skip items that are fully sacrificed
        }
        
        if (product == null) {
          // Product not found, use placeholder
          debugPrint('[Inventory] Product not found: ${item.productId}');
          return InventoryItem(
            id: item.productId,
            name: 'Unknown Item',
            quantity: availableQuantity,
            description: 'Product no longer available',
            value: 0,
            imageUrl: null,
          );
        }
        
        final imageUrl = product.imageUrls.isNotEmpty ? product.imageUrls.first : null;
        debugPrint('[Inventory] Product ${product.title} imageUrl: $imageUrl');
        
        return InventoryItem(
          id: product.id,
          name: product.title,
          quantity: availableQuantity,
          description: product.description,
          value: product.price.toInt(),
          imageUrl: imageUrl,
          productPngUrl: product.productPNGurl,
        );
      }).whereType<InventoryItem>().toList();
    } catch (e, stackTrace) {
      debugPrint('[Inventory] Error loading inventory items: $e');
      debugPrint('[Inventory] Stack trace: $stackTrace');
      rethrow;
    }
  }

  void _showDockFullMessage() {
    // Shake animation
    _dockShakeController?.reset();
    _dockShakeController?.forward();

    // Show message near dock
    final RenderBox? dockBox =
        _dockKey.currentContext?.findRenderObject() as RenderBox?;
    if (dockBox != null) {
      final dockPosition = dockBox.localToGlobal(Offset.zero);
      final overlay = Overlay.of(context);
      late OverlayEntry overlayEntry;

      overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          left: 20,
          top: dockPosition.dy + dockBox.size.height + 10,
          right: 20,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2416),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD4AF37), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Text(
                'Dock is full.',
                style: GoogleFonts.cinzel(
                  color: const Color(0xFFD4AF37),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );

      overlay.insert(overlayEntry);
      Future.delayed(const Duration(seconds: 2), () {
        overlayEntry.remove();
      });
    }
  }

  Future<void> _addItemToDock(
    InventoryItem item,
    int quantity,
    Offset startPosition,
  ) async {
    // Check if item already exists in dock
    final existingIndex = DockService.instance.dockItems.indexWhere((slot) => slot?.id == item.id);

    // Check if dock is full (only if item not already in dock)
    if (existingIndex == -1 && DockService.instance.isFull) {
      _showDockFullMessage();
      return;
    }

    // Get dock position - target the specific empty slot
    final RenderBox? dockBox =
        _dockKey.currentContext?.findRenderObject() as RenderBox?;
    if (dockBox == null) return;

    final dockPosition = dockBox.localToGlobal(Offset.zero);

    // Calculate position of the specific slot
    // If exists, use that index. If not, use first empty.
    final targetIndex = existingIndex != -1 
        ? existingIndex 
        : DockService.instance.dockItems.indexWhere((slot) => slot == null);
        
    final slotWidth = dockBox.size.width / DockService.instance.capacity;
    final targetSlotOffset = Offset(
      dockPosition.dx + (slotWidth * targetIndex) + (slotWidth / 2) - 40,
      dockPosition.dy + 20,
    );

    // Show flying animation
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => FlyingItemAnimation(
        startPosition: startPosition,
        endPosition: targetSlotOffset,
        itemName: item.name,
        quantity: quantity,
        onComplete: () {
          try {
            DockService.instance.addItem(item, quantity);
          } catch (e) {
             ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  e.toString().replaceAll('Exception: ', ''),
                  style: GoogleFonts.lato(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                backgroundColor: const Color(0xFF2C2416),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Colors.red, width: 1),
                ),
              ),
            );
          }
        },
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }

  void _showItemActions(InventoryItem item, Offset tapPosition) {
    showDialog(
      context: context,
      builder: (context) => ItemActionDialog(
        item: item,
        onSacrifice: (quantity) async {
          Navigator.pop(context);
          await _addItemToDock(item, quantity, tapPosition);
        },
        onSell: (quantity) async {
          Navigator.pop(context);
          await _sellItem(item, quantity);
        },
      ),
    );
  }

  Future<void> _performSacrifice() async {
    // Check if dock has any items
    final dockHasItems = !DockService.instance.isEmpty;
    if (!dockHasItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Add items to the dock first',
            style: GoogleFonts.lato(color: const Color(0xFFD4AF37)),
            textAlign: TextAlign.center,
          ),
          backgroundColor: const Color(0xFF2C2416),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFD4AF37), width: 1),
          ),
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1410),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFD4AF37), width: 2),
        ),
        title: Text(
          'Perform Sacrifice?',
          style: GoogleFonts.cinzel(
            color: const Color(0xFFD4AF37),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will permanently sacrifice the items in the dock.',
          style: GoogleFonts.lato(
            color: const Color(0xFFD4AF37),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.lato(color: const Color(0xFFD4AF37).withValues(alpha: 0.6)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Sacrifice',
              style: GoogleFonts.lato(
                color: const Color(0xFFD4AF37),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Perform sacrifice for each item in dock
    bool allSuccess = true;
    for (final dockItem in DockService.instance.dockItems) {
      if (dockItem != null) {
        final success = await PurchaseService.instance.sacrificeItem(
          dockItem.id,
          dockItem.quantity,
        );
        if (!success) {
          allSuccess = false;
          debugPrint('[Inventory] Failed to sacrifice ${dockItem.name}');
        }
      }
    }

    if (!mounted) return;

    if (allSuccess) {
      // Clear the dock
      DockService.instance.clearDock();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sacrifice completed!',
            style: GoogleFonts.lato(
              color: const Color(0xFFD4AF37),
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          backgroundColor: const Color(0xFF2C2416),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFD4AF37), width: 2),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Some items failed to sacrifice',
            style: GoogleFonts.lato(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          backgroundColor: const Color(0xFF2C2416),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Colors.red, width: 1),
          ),
        ),
      );
    }
  }

  Future<void> _sellItem(InventoryItem item, int quantity) async {
    // Show loading indicator
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Selling ${item.name}...',
          style: GoogleFonts.lato(color: const Color(0xFFD4AF37)),
          textAlign: TextAlign.center,
        ),
        backgroundColor: const Color(0xFF2C2416),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFFD4AF37), width: 1),
        ),
      ),
    );

    // Sell the item
    final success = await PurchaseService.instance.sellItem(
      item.id,
      quantity,
      item.value,
    );

    if (!mounted) return;

    if (success) {
      // Trigger confetti celebration!
      debugPrint('🎊 Inventory: Triggering confetti! Key state: ${_confettiKey.currentState}');
      _confettiKey.currentState?.celebrate();
      
      final totalRings = quantity * item.value;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Sold ${quantity}x ${item.name} for ',
                style: GoogleFonts.lato(color: const Color(0xFFD4AF37)),
              ),
              Image.asset(
                'assets/icon/ring_img.png',
                width: 16,
                height: 16,
              ),
              const SizedBox(width: 4),
              Text(
                '$totalRings',
                style: GoogleFonts.lato(
                  color: const Color(0xFFD4AF37),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2C2416),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFD4AF37), width: 1),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to sell ${item.name}',
            style: GoogleFonts.lato(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          backgroundColor: const Color(0xFF2C2416),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Colors.red, width: 1),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConfettiOverlay(
      key: _confettiKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1410),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: const Padding(
            padding: EdgeInsets.only(left: 6),
            child: BackNavButton(),
          ),
          title: Image.asset(
            'assets/inventory/inventory_header.png',
            height: 40,
            fit: BoxFit.contain,
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const StoreShellPage()),
                  );
                },
                child: Image.asset(
                  'assets/inventory/store_logo.png',
                  height: 40,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              _buildDockSection(),
              Expanded(
                child: StreamBuilder<Map<String, PurchasedItem>>(
                  stream: PurchaseService.instance.getAggregatedInventoryStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && _cachedPurchasedItems == null) {
                      return const Center(
                        child: AnimatedLoadingIndicator(
                          color: Color(0xFFD4AF37),
                          message: 'Loading Inventory...',
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading inventory',
                          style: GoogleFonts.cinzel(
                            color: const Color(0xFFD4AF37),
                            fontSize: 16,
                          ),
                        ),
                      );
                    }

                    final purchasedItems = snapshot.data ?? _cachedPurchasedItems ?? {};
                    
                    // Only reload if data actually changed
                    final shouldReload = _cachedPurchasedItems == null || 
                                        _hasDataChanged(_cachedPurchasedItems!, purchasedItems);
                    
                    if (shouldReload) {
                      _cachedPurchasedItems = purchasedItems;
                      
                      // Fetch product details and convert to inventory items
                      return FutureBuilder<List<InventoryItem>>(
                        future: _loadInventoryItems(purchasedItems),
                        builder: (context, futureSnapshot) {
                          if (futureSnapshot.connectionState == ConnectionState.waiting) {
                            // Show existing items while loading if available
                            if (_inventoryItems.isNotEmpty) {
                              return _buildInventoryTab();
                            }
                            return const Center(
                              child: AnimatedLoadingIndicator(
                                color: Color(0xFFD4AF37),
                                message: 'Loading Items...',
                              ),
                            );
                          }

                          if (futureSnapshot.hasError) {
                            debugPrint('[Inventory] Error loading products: ${futureSnapshot.error}');
                            return Center(
                              child: Text(
                                'Error loading product details',
                                style: GoogleFonts.cinzel(
                                  color: const Color(0xFFD4AF37),
                                  fontSize: 16,
                                ),
                              ),
                            );
                          }

                          _inventoryItems = futureSnapshot.data ?? [];
                          return _buildInventoryTab();
                        },
                      );
                    } else {
                      // Data hasn't changed, just rebuild the UI with existing items
                      return _buildInventoryTab();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: GestureDetector(
          onTap: (){

            Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const GameWebView(),
                          ),
                        );
          },
          child: Image.asset(
            'assets/inventory/game_logo.png',
            width: 80,
            height: 80,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildDockSection() {
    return ListenableBuilder(
      listenable: DockService.instance,
      builder: (context, child) {
        return AnimatedBuilder(
          animation: _dockShakeController!,
          builder: (context, child) {
            final shake = _dockShakeController!.value;
            final offset = sin(shake * pi * 4) * 10;
            return Transform.translate(offset: Offset(offset, 0), child: child);
          },
          child: Container(
            key: _dockKey,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF2C2416),
              border: Border(
                bottom: BorderSide(color: Color(0xFFD4AF37), width: 1),
              ),
            ),
            child: Row(
              children: List.generate(
                DockService.instance.capacity,
                (index) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index < DockService.instance.capacity - 1 ? 8 : 0,
                    ),
                    child: _buildDockSlot(index),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDockSlot(int index) {
    final item = DockService.instance.dockItems[index];
    final isEmpty = item == null;

    return GestureDetector(
      onTap: isEmpty ? null : () => _removeFromDock(index),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1410),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Center(
          child: isEmpty
              ? Text(
                  '+',
                  style: GoogleFonts.lato(
                    fontSize: 24,
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                    fontWeight: FontWeight.w300,
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cinzel(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFD4AF37),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'x${item.quantity}',
                      style: GoogleFonts.lato(
                        fontSize: 10,
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  void _removeFromDock(int index) {
    final item = DockService.instance.dockItems[index];
    if (item == null) return;

    DockService.instance.removeItem(index);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Returned ${item.name} to inventory',
          style: GoogleFonts.lato(color: const Color(0xFFD4AF37)),
          textAlign: TextAlign.center,
        ),
        backgroundColor: const Color(0xFF2C2416),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFFD4AF37), width: 1),
        ),
      ),
    );
  }

  Widget _buildInventoryTab() {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(child: _buildSplitScreenInventory()),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2416),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD4AF37), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        style: GoogleFonts.cinzel(
          color: const Color(0xFFD4AF37),
          fontSize: 16,
          fontWeight: FontWeight.w600,
          shadows: [
            Shadow(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
              blurRadius: 8,
            ),
          ],
        ),
        decoration: InputDecoration(
          hintText: 'Search items...',
          hintStyle: GoogleFonts.cinzel(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
            fontSize: 16,
          ),
          border: InputBorder.none,
          icon: Icon(
            Icons.search,
            color: const Color(0xFFD4AF37).withValues(alpha: 0.7),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.7),
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildSplitScreenInventory() {
    final filteredItems = _filteredItems;
    final leftItems = <InventoryItem>[];
    final rightItems = <InventoryItem>[];

    // Fill left column first, then right column
    final halfCount = (filteredItems.length / 2).ceil();
    for (int i = 0; i < filteredItems.length; i++) {
      if (i < halfCount) {
        leftItems.add(filteredItems[i]);
      } else {
        rightItems.add(filteredItems[i]);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildInventoryColumn(leftItems)),
          const SizedBox(width: 12),
          Expanded(child: _buildInventoryColumn(rightItems)),
        ],
      ),
    );
  }

  Widget _buildInventoryColumn(List<InventoryItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2416).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD4AF37), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No items',
                  style: GoogleFonts.cinzel(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                    fontSize: 16,
                  ),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              itemCount: items.length,
              itemBuilder: (context, index) {
                return _buildGlowingInventoryItem(items[index]);
              },
            ),
    );
  }

  Widget _buildGlowingInventoryItem(InventoryItem item) {
    final GlobalKey itemKey = GlobalKey();

    return GestureDetector(
      key: itemKey,
      onTap: () {
        final RenderBox? box =
            itemKey.currentContext?.findRenderObject() as RenderBox?;
        if (box != null) {
          final position = box.localToGlobal(Offset.zero);
          _showItemActions(item, position);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [
                    const Color(0xFFFFD700),
                    const Color(0xFFD4AF37),
                    const Color(0xFFFFD700),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ).createShader(bounds),
                child: Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.tangerine(
                    fontSize: item.name.length > 20 ? 22 : 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                    height: 1.1,
                    shadows: [
                      Shadow(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.9),
                        blurRadius: 12,
                      ),
                      Shadow(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                        blurRadius: 24,
                      ),
                      Shadow(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                        blurRadius: 36,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [const Color(0xFFFFD700), const Color(0xFFD4AF37)],
              ).createShader(bounds),
              child: Text(
                'x${item.quantity}',
                style: GoogleFonts.tangerine(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.7),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
