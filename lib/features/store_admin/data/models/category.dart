import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryModel {
  final String id; // Firestore doc id
  final String name; // Display name
  final String slug; // URL/lookup safe unique key
  final String? description;
  final int order; // ordering in UI (0..5)
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.order = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson({bool forCreate = false}) {
    return {
      if (!forCreate) 'id': id,
      'name': name,
      'slug': slug,
      if (description != null) 'description': description,
      'order': order,
      'isActive': isActive,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory CategoryModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    int _parseOrder(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) {
        final n = int.tryParse(v);
        if (n != null) return n;
      }
      return 0;
    }
    return CategoryModel(
      id: doc.id,
      name: d['name'] ?? '',
      slug: d['slug'] ?? '',
      description: d['description'],
      order: _parseOrder(d['order']),
      isActive: (d['isActive'] ?? true) as bool,
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
