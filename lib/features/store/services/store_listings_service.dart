import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service to fetch curated product listings from Firestore
/// - Hot and Clearance: Reads from store_listings/fornewandhot document
/// - New Arrivals: Fetches 8 latest products based on createdAt timestamp
class StoreListingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch product IDs for the "hot" section
  Future<List<String>> getHotProductIds() async {
    try {
      final doc = await _firestore
          .collection('store_listings')
          .doc('fornewandhot')
          .get();

      if (!doc.exists) {
        debugPrint(
          '[StoreListingsService] fornewandhot document does not exist',
        );
        return [];
      }

      final data = doc.data();
      if (data == null) return [];

      final hot = data['hot'];
      if (hot is List) {
        return hot.cast<String>();
      }

      return [];
    } catch (e) {
      debugPrint('[StoreListingsService] Error fetching hot products: $e');
      return [];
    }
  }

  /// Fetch product IDs for the "new" section (New Arrivals)
  /// Now fetches the 8 latest products based on createdAt timestamp
  Future<List<String>> getNewProductIds() async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(8)
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint('[StoreListingsService] Error fetching new products: $e');
      return [];
    }
  }

  /// Fetch product IDs for the "clearance" section
  Future<List<String>> getClearanceProductIds() async {
    try {
      final doc = await _firestore
          .collection('store_listings')
          .doc('fornewandhot')
          .get();

      if (!doc.exists) {
        debugPrint(
          '[StoreListingsService] fornewandhot document does not exist',
        );
        return [];
      }

      final data = doc.data();
      if (data == null) return [];

      final clearance = data['clearance'];
      if (clearance is List) {
        return clearance.cast<String>();
      }

      return [];
    } catch (e) {
      debugPrint(
        '[StoreListingsService] Error fetching clearance products: $e',
      );
      return [];
    }
  }

  /// Fetch all curated lists at once for efficiency
  /// New arrivals now fetches the 8 latest products based on createdAt timestamp
  Future<CuratedLists> getAllCuratedLists() async {
    try {
      // Fetch hot and clearance from the curated document
      final doc = await _firestore
          .collection('store_listings')
          .doc('fornewandhot')
          .get();

      final data = doc.data();
      final hot = (data != null && data['hot'] is List) ? (data['hot'] as List).cast<String>() : <String>[];
      final clearance = (data != null && data['clearance'] is List) ? (data['clearance'] as List).cast<String>() : <String>[];

      // Fetch new arrivals based on createdAt timestamp
      final newArrivals = await getNewProductIds();

      return CuratedLists(
        hot: hot,
        newArrivals: newArrivals,
        clearance: clearance,
      );
    } catch (e) {
      debugPrint('[StoreListingsService] Error fetching curated lists: $e');
      return CuratedLists.empty();
    }
  }
}

/// Model for curated product lists
class CuratedLists {
  final List<String> hot;
  final List<String> newArrivals;
  final List<String> clearance;

  CuratedLists({
    required this.hot,
    required this.newArrivals,
    required this.clearance,
  });

  factory CuratedLists.empty() {
    return CuratedLists(hot: [], newArrivals: [], clearance: []);
  }

  bool get isEmpty => hot.isEmpty && newArrivals.isEmpty && clearance.isEmpty;
}
