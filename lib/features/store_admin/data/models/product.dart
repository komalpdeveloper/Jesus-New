import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id; // Firestore doc id
  final String title; // name/title
  final String slug; // slug for lookup
  final String description;
  final double price; // base price in your currency ("rings")
  final List<String> imageUrls; // Firebase Storage URLs
  final String? svgUrl; // Optional SVG icon URL (legacy, not used)
  final String? productPNGurl; // Optional PNG icon URL
  final String categoryId; // ref to category
  final String categoryName; // denorm for easy query/UI
  final int quantity; // stock count
  final double rating; // aggregate rating
  final int reviews; // aggregate review count
  final String? note; // optional note
  final bool isActive;
  final int order; // optional ordering
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductModel({
    required this.id,
    required this.title,
    required this.slug,
    required this.description,
    required this.price,
    required this.imageUrls,
    this.svgUrl,
    this.productPNGurl,
    required this.categoryId,
    required this.categoryName,
    required this.quantity,
    required this.rating,
    required this.reviews,
    this.note,
    this.isActive = true,
    this.order = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson({bool forCreate = false}) {
    return {
      if (!forCreate) 'id': id,
      'title': title,
      'slug': slug,
      'description': description,
      'price': price,
      'imageUrls': imageUrls,
      if (svgUrl != null) 'svgUrl': svgUrl,
      if (productPNGurl != null) 'productPNGurl': productPNGurl,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'quantity': quantity,
      'rating': rating,
      'reviews': reviews,
      if (note != null) 'note': note,
      'isActive': isActive,
      'order': order,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory ProductModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ProductModel(
      id: doc.id,
      title: d['title'] ?? '',
      slug: d['slug'] ?? '',
      description: d['description'] ?? '',
      price: (d['price'] is int) ? (d['price'] as int).toDouble() : (d['price'] ?? 0.0),
      imageUrls: (d['imageUrls'] as List?)?.whereType<String>().toList() ?? const [],
      svgUrl: d['svgUrl'] as String?,
      productPNGurl: d['productPNGurl'] as String?,
      categoryId: d['categoryId'] ?? '',
      categoryName: d['categoryName'] ?? '',
      quantity: (d['quantity'] ?? 0) as int,
      rating: (d['rating'] is int) ? (d['rating'] as int).toDouble() : (d['rating'] ?? 0.0),
      reviews: (d['reviews'] ?? 0) as int,
      note: d['note'],
      isActive: (d['isActive'] ?? true) as bool,
      order: (d['order'] ?? 0) as int,
      createdAt: _tsToDate(d['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: _tsToDate(d['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static DateTime? _tsToDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}
