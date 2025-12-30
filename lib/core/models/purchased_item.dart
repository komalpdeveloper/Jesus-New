import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clientapp/features/inventory/models/inventory_item.dart';

/// Model for items purchased from the store.
/// Stored in Firestore under `purchasedItems/{purchaseId}`.
class PurchasedItem {
  final String id; // Firestore document id
  final String userId; // Reference to the user who bought this
  final String productId; // Reference to the product
  final int quantity;
  final int sacrificedCount; // How many have been sacrificed
  final DateTime purchasedAt;

  const PurchasedItem({
    required this.id,
    required this.userId,
    required this.productId,
    required this.quantity,
    this.sacrificedCount = 0,
    required this.purchasedAt,
  });

  Map<String, dynamic> toJson({bool includeId = false}) {
    return {
      if (includeId) 'id': id,
      'userId': userId,
      'productId': productId,
      'quantity': quantity,
      'sacrificedCount': sacrificedCount,
      'purchasedAt': Timestamp.fromDate(purchasedAt),
    };
  }

  factory PurchasedItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return PurchasedItem(
      id: doc.id,
      userId: data['userId'] ?? '',
      productId: data['productId'] ?? '',
      quantity: (data['quantity'] ?? 0) as int,
      sacrificedCount: (data['sacrificedCount'] ?? 0) as int,
      purchasedAt: _tsToDate(data['purchasedAt']),
    );
  }

  static DateTime _tsToDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.now();
  }

  /// Convert to InventoryItem for display in inventory screen
  /// Note: This requires fetching product details from the products collection
  InventoryItem toInventoryItem({
    required String name,
    required String description,
    required int value,
  }) {
    return InventoryItem(
      id: productId,
      name: name,
      quantity: quantity,
      description: description,
      value: value,
    );
  }
}
