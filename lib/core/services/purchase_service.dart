import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:clientapp/core/models/purchased_item.dart';
import 'package:clientapp/features/store/services/cart_service.dart';

/// Service for managing purchased items in Firestore.
class PurchaseService {
  PurchaseService._();
  static final instance = PurchaseService._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _purchases =>
      _db.collection('purchasedItems');

  /// Save purchased items to Firestore after successful checkout.
  /// Takes cart items and creates purchase records.
  /// Also updates the user's boughtItems array with the purchase IDs.
  Future<void> savePurchase(List<CartItemModel> items) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('[PurchaseService] No user logged in, cannot save purchase');
      return;
    }

    final batch = _db.batch();
    final now = DateTime.now();
    final purchaseIds = <String>[];

    for (final item in items) {
      final docRef = _purchases.doc();
      final purchase = PurchasedItem(
        id: docRef.id,
        userId: user.uid,
        productId: item.productId,
        quantity: item.qty,
        purchasedAt: now,
      );
      batch.set(docRef, purchase.toJson());
      purchaseIds.add(docRef.id);
    }

    // Update user's boughtItems array
    final userRef = _db.collection('users').doc(user.uid);
    batch.update(userRef, {'boughtItems': FieldValue.arrayUnion(purchaseIds)});

    await batch.commit();
    debugPrint(
      '[PurchaseService] Saved ${items.length} purchased items for user ${user.uid}',
    );
  }

  /// Get all purchased items for the current user.
  Stream<List<PurchasedItem>> getUserPurchasesStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream<List<PurchasedItem>>.empty();

    return _purchases
        .where('userId', isEqualTo: user.uid)
        .orderBy('purchasedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => PurchasedItem.fromDoc(doc))
              .toList();
        });
  }

  /// Get purchased items once (non-reactive).
  Future<List<PurchasedItem>> getUserPurchasesOnce() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await _purchases
        .where('userId', isEqualTo: user.uid)
        .orderBy('purchasedAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => PurchasedItem.fromDoc(doc)).toList();
  }

  /// Get aggregated inventory items (combining quantities of same product).
  Stream<Map<String, PurchasedItem>> getAggregatedInventoryStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream<Map<String, PurchasedItem>>.empty();

    return _purchases.where('userId', isEqualTo: user.uid).snapshots().map((
      snapshot,
    ) {
      final Map<String, PurchasedItem> aggregated = {};

      for (final doc in snapshot.docs) {
        try {
          final item = PurchasedItem.fromDoc(doc);
          
          // Skip items with invalid productId (old format with | in it)
          if (item.productId.contains('|')) {
            debugPrint('[PurchaseService] Skipping old format item: ${doc.id}');
            continue;
          }
          
          final key = item.productId;

          if (aggregated.containsKey(key)) {
            final existing = aggregated[key]!;
            // Combine quantities and sacrificed counts
            aggregated[key] = PurchasedItem(
              id: existing.id,
              userId: existing.userId,
              productId: existing.productId,
              quantity: existing.quantity + item.quantity,
              sacrificedCount: existing.sacrificedCount + item.sacrificedCount,
              purchasedAt: existing.purchasedAt,
            );
          } else {
            aggregated[key] = item;
          }
        } catch (e) {
          debugPrint('[PurchaseService] Error parsing document ${doc.id}: $e');
        }
      }

      return aggregated;
    });
  }

  /// Sacrifice items - increments the sacrificedCount in Firestore.
  /// Returns true if successful, false if item not found or insufficient quantity.
  Future<bool> sacrificeItem(
    String productId,
    int quantityToSacrifice,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('[PurchaseService] No user logged in, cannot sacrifice item');
      return false;
    }

    try {
      // Get all purchase records for this product
      final snapshot = await _purchases
          .where('userId', isEqualTo: user.uid)
          .where('productId', isEqualTo: productId)
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint(
          '[PurchaseService] No items found with productId: $productId',
        );
        return false;
      }

      // Calculate total available quantity (quantity - sacrificedCount)
      int totalAvailable = 0;
      for (final doc in snapshot.docs) {
        final item = PurchasedItem.fromDoc(doc);
        final available = item.quantity - item.sacrificedCount;
        totalAvailable += available;
      }

      if (totalAvailable < quantityToSacrifice) {
        debugPrint(
          '[PurchaseService] Insufficient quantity. Available: $totalAvailable, Requested: $quantityToSacrifice',
        );
        return false;
      }

      // Use batch to update sacrificed counts
      final batch = _db.batch();
      int remainingToSacrifice = quantityToSacrifice;

      // Process each purchase record
      for (final doc in snapshot.docs) {
        if (remainingToSacrifice <= 0) break;

        final item = PurchasedItem.fromDoc(doc);
        final available = item.quantity - item.sacrificedCount;

        if (available <= 0) continue; // Skip if nothing available

        final toSacrificeFromThis = available < remainingToSacrifice ? available : remainingToSacrifice;
        final newSacrificedCount = item.sacrificedCount + toSacrificeFromThis;

        batch.update(doc.reference, {'sacrificedCount': newSacrificedCount});
        remainingToSacrifice -= toSacrificeFromThis;

        debugPrint(
          '[PurchaseService] Updating purchase record ${doc.id}: sacrificedCount ${item.sacrificedCount} -> $newSacrificedCount',
        );
      }

      await batch.commit();
      debugPrint(
        '[PurchaseService] Sacrificed $quantityToSacrifice items',
      );
      return true;
    } catch (e) {
      debugPrint('[PurchaseService] Error sacrificing item: $e');
      return false;
    }
  }


  /// Sell an item from inventory - reduces quantity or removes item, and adds rings to user.
  /// Returns true if successful, false if item not found or insufficient quantity.
  Future<bool> sellItem(
    String productId,
    int quantityToSell,
    int valuePerItem,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('[PurchaseService] No user logged in, cannot sell item');
      return false;
    }

    try {
      // Get all purchase records for this product
      final snapshot = await _purchases
          .where('userId', isEqualTo: user.uid)
          .where('productId', isEqualTo: productId)
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint(
          '[PurchaseService] No items found with productId: $productId',
        );
        return false;
      }

      // Calculate total available quantity
      int totalAvailable = 0;
      for (final doc in snapshot.docs) {
        final item = PurchasedItem.fromDoc(doc);
        totalAvailable += item.quantity;
      }

      if (totalAvailable < quantityToSell) {
        debugPrint(
          '[PurchaseService] Insufficient quantity. Available: $totalAvailable, Requested: $quantityToSell',
        );
        return false;
      }

      // Calculate total rings to add
      final totalRings = quantityToSell * valuePerItem;

      // Use batch to update/delete items and add rings
      final batch = _db.batch();
      int remainingToSell = quantityToSell;

      // Process each purchase record
      for (final doc in snapshot.docs) {
        if (remainingToSell <= 0) break;

        final item = PurchasedItem.fromDoc(doc);

        if (item.quantity <= remainingToSell) {
          // Delete this entire record
          batch.delete(doc.reference);
          remainingToSell -= item.quantity;
          debugPrint(
            '[PurchaseService] Deleting purchase record ${doc.id} with quantity ${item.quantity}',
          );
        } else {
          // Reduce quantity
          final newQuantity = item.quantity - remainingToSell;
          batch.update(doc.reference, {'quantity': newQuantity});
          debugPrint(
            '[PurchaseService] Reducing purchase record ${doc.id} from ${item.quantity} to $newQuantity',
          );
          remainingToSell = 0;
        }
      }

      // Update user's ring count
      final userRef = _db.collection('users').doc(user.uid);
      batch.update(userRef, {'ringCount': FieldValue.increment(totalRings)});

      await batch.commit();
      debugPrint(
        '[PurchaseService] Sold $quantityToSell items for $totalRings rings',
      );
      return true;
    } catch (e) {
      debugPrint('[PurchaseService] Error selling item: $e');
      return false;
    }
  }
}
