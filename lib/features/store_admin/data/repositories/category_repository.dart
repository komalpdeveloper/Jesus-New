import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category.dart';

class CategoryRepository {
  final FirebaseFirestore _db;
  CategoryRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('categories');

  Future<CategoryModel> create({
    required String name,
    String? description,
    int order = 0,
    bool isActive = true,
  }) async {
    final slug = _slugify(name);

    // Enforce unique slug
    final existing = await _col.where('slug', isEqualTo: slug).limit(1).get();
    if (existing.docs.isNotEmpty) {
      throw Exception('Category already exists');
    }

    final docRef = await _col.add({
      'name': name.trim(),
      'slug': slug,
      if (description != null) 'description': description.trim(),
      'order': order,
      'isActive': isActive,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final snap = await docRef.get();
    return CategoryModel.fromDoc(snap);
  }

  Future<CategoryModel> getOrCreateByName(String name) async {
    final slug = _slugify(name);
    final existing = await _col.where('slug', isEqualTo: slug).limit(1).get();
    if (existing.docs.isNotEmpty) {
      return CategoryModel.fromDoc(existing.docs.first);
    }
    return create(name: name);
  }

  Future<CategoryModel?> findByName(String name) async {
    final slug = _slugify(name);
    final existing = await _col.where('slug', isEqualTo: slug).limit(1).get();
    if (existing.docs.isEmpty) return null;
    return CategoryModel.fromDoc(existing.docs.first);
  }

  Future<void> deleteByName(String name) async {
    final slug = _slugify(name);
    final qs = await _col.where('slug', isEqualTo: slug).get();
    for (final d in qs.docs) {
      await d.reference.delete();
    }
  }

  Future<List<CategoryModel>> listActive() async {
    // Fetch all to include docs missing 'order' or 'isActive' and sort/filter in memory
    final qs = await _col.get();
    final list = qs.docs.map((d) => CategoryModel.fromDoc(d)).where((m) => m.isActive).toList();
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  String _slugify(String input) {
    final s = input.trim().toLowerCase();
    final only = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'-+'), '-');
    return only.endsWith('-') ? only.substring(0, only.length - 1) : only;
  }
}
