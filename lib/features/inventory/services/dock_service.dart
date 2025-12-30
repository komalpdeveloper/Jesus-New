import 'package:flutter/foundation.dart';
import '../models/inventory_item.dart';

class DockService extends ChangeNotifier {
  static final DockService instance = DockService._();
  DockService._();

  final int capacity = 3;
  final List<InventoryItem?> _dockItems = [null, null, null];

  List<InventoryItem?> get dockItems => List.unmodifiable(_dockItems);

  bool get isEmpty => _dockItems.every((item) => item == null);
  bool get isFull => _dockItems.every((item) => item != null);

  // Returns true if added successfully, false if dock is full
  // Throws exception if item invalid (e.g. missing PNG)
  void addItem(InventoryItem item, int quantity) {
    // Validation
    if (item.productPngUrl == null || item.productPngUrl!.isEmpty) {
      throw Exception("Item is not ready for altar. will ready soon.");
    }

    // Check if item already exists in dock to stack it
    final existingIndex = _dockItems.indexWhere((element) => element?.id == item.id);
    
    if (existingIndex != -1) {
      // Stack with existing item
      final existingItem = _dockItems[existingIndex]!;
      _dockItems[existingIndex] = InventoryItem(
        id: existingItem.id,
        name: existingItem.name,
        quantity: existingItem.quantity + quantity,
        description: existingItem.description,
        value: existingItem.value,
        imageUrl: existingItem.imageUrl,
        productPngUrl: existingItem.productPngUrl,
      );
      notifyListeners();
      return;
    }

    // Find first empty slot
    final index = _dockItems.indexWhere((element) => element == null);
    if (index != -1) {
      // Create a copy of the item with the specified quantity
      _dockItems[index] = InventoryItem(
        id: item.id,
        name: item.name,
        quantity: quantity,
        description: item.description,
        value: item.value,
        imageUrl: item.imageUrl,
        productPngUrl: item.productPngUrl,
      );
      notifyListeners();
    }
  }

  void removeItem(int index) {
    if (index >= 0 && index < capacity) {
      _dockItems[index] = null;
      notifyListeners();
    }
  }
  
  void clearDock() {
    for (int i = 0; i < capacity; i++) {
      _dockItems[i] = null;
    }
    notifyListeners();
  }
  
  // Helper to get total quantity of an item in dock
  int getQuantityInDock(String itemId) {
    int total = 0;
    for (var item in _dockItems) {
      if (item != null && item.id == itemId) {
        total += item.quantity;
      }
    }
    return total;
  }
}
