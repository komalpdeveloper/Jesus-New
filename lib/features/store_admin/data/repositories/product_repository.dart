import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../services/storage_service.dart';

class ProductRepository {
  final FirebaseFirestore _db;
  final StorageService _storage;
  ProductRepository({FirebaseFirestore? db, StorageService? storage})
      : _db = db ?? FirebaseFirestore.instance,
        _storage = storage ?? StorageService();

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('products');

  // Create product and upload images. Returns created ProductModel.
  Future<ProductModel> create({
    required String title,
    required String description,
    required double price,
    required List<File> imageFiles,
    File? pngFile,
    Uint8List? pngBytes,
    required String categoryId,
    required String categoryName,
    required int quantity,
    required double rating,
    required int reviews,
    String? note,
    bool isActive = true,
    int order = 0,
  }) async {
    final slug = _slugify(title);

    // Create an empty doc first to get an id
    final docRef = await _col.add({
      'title': title.trim(),
      'slug': slug,
      'description': description.trim(),
      'price': price,
      'imageUrls': [],
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
    });

    final productId = docRef.id;

    // Upload images sequentially (simple + reliable); could be parallelized
    final urls = <String>[];
    for (var i = 0; i < imageFiles.length; i++) {
      try {
        final url = await _storage.uploadProductImage(productId: productId, file: imageFiles[i], index: i);
        urls.add(url);
      } catch (e) {
        // Continue remaining uploads; log the error
        // ignore: avoid_print
        // ignore: avoid_print
        // ignore: avoid_print
        // Project uses debug logging in other places too
        // ignore: avoid_print
        // Using debugPrint from Flutter foundation would require importing flutter foundation
        // Keep it as print for minimal deps in repository layer
        print('[ProductRepository] Upload failed for image index=$i of product=$productId: $e');
      }
    }

    if (urls.isEmpty && imageFiles.isNotEmpty) {
      // If user selected images but none uploaded, consider this a failure
      throw Exception('All image uploads failed. Check auth and Storage rules.');
    }

    // Upload optional PNG
    String? pngUrl;
    if (pngFile != null || pngBytes != null) {
      try {
        if (pngFile != null) {
          pngUrl = await _storage.uploadProductPng(productId: productId, file: pngFile);
        } else if (pngBytes != null) {
          pngUrl = await _storage.uploadProductPngBytes(productId: productId, bytes: pngBytes);
        }
      } catch (e) {
        print('[ProductRepository] Upload PNG failed for product=$productId: $e');
      }
    }

    // Update doc with final URLs and optional png
    final upd = <String, dynamic>{
      'imageUrls': urls,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (pngUrl != null) upd['productPNGurl'] = pngUrl;
    await docRef.update(upd);

    final snap = await docRef.get();
    return ProductModel.fromDoc(snap);
  }

  String _slugify(String input) {
    final s = input.trim().toLowerCase();
    final only = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'-+'), '-');
    return only.endsWith('-') ? only.substring(0, only.length - 1) : only;
  }

  Future<List<ProductModel>> listRecent({int limit = 6}) async {
    final qs = await _col.orderBy('createdAt', descending: true).limit(limit).get();
    return qs.docs.map((d) => ProductModel.fromDoc(d)).toList();
  }

  Future<List<ProductModel>> listAll({int? limit}) async {
    Query<Map<String, dynamic>> q = _col.orderBy('createdAt', descending: true);
    if (limit != null) q = q.limit(limit);
    final qs = await q.get();
    return qs.docs.map((d) => ProductModel.fromDoc(d)).toList();
  }

  /// List products by category slug/id.
  /// Applies optional [onlyActive] filter (default true) and [limit].
  /// Results are sorted in-memory by `order` ascending, then `createdAt` descending
  /// to avoid requiring a composite Firestore index.
  Future<List<ProductModel>> listByCategory(
    String categoryId, {
    bool onlyActive = true,
    int? limit,
  }) async {
    Query<Map<String, dynamic>> q = _col.where('categoryId', isEqualTo: categoryId);
    if (onlyActive) {
      q = q.where('isActive', isEqualTo: true);
    }
    // Fetch without orderBy to avoid composite index; we'll sort in memory
    if (limit != null) q = q.limit(limit);
    final qs = await q.get();
    final list = qs.docs.map((d) => ProductModel.fromDoc(d)).toList();
    list.sort((a, b) {
      final orderCmp = a.order.compareTo(b.order);
      if (orderCmp != 0) return orderCmp;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  Future<int> countActive() async {
    try {
      final agg = await _col.where('isActive', isEqualTo: true).count().get();
      return agg.count ?? 0;
    } catch (_) {
      // fallback: count documents (not ideal but prevents crash if aggregates unsupported)
      final qs = await _col.get();
      return qs.docs.length;
    }
  }

  // Returns true if any product exists with the given categoryId (slug)
  Future<bool> existsInCategory(String categoryId) async {
    final qs = await _col.where('categoryId', isEqualTo: categoryId).limit(1).get();
    return qs.docs.isNotEmpty;
  }

  Future<ProductModel?> getById(String id) async {
    final snap = await _col.doc(id).get();
    if (!snap.exists) return null;
    return ProductModel.fromDoc(snap);
  }

  /// Fetch multiple products by their IDs
  /// Returns products in the same order as the input IDs
  /// Skips any IDs that don't exist or are inactive (if onlyActive is true)
  Future<List<ProductModel>> getByIds(
    List<String> ids, {
    bool onlyActive = true,
  }) async {
    if (ids.isEmpty) return [];

    // Firestore 'in' queries are limited to 10 items, so we batch
    final results = <ProductModel>[];
    const batchSize = 10;

    for (var i = 0; i < ids.length; i += batchSize) {
      final batch = ids.skip(i).take(batchSize).toList();
      Query<Map<String, dynamic>> q = _col.where(FieldPath.documentId, whereIn: batch);
      if (onlyActive) {
        q = q.where('isActive', isEqualTo: true);
      }
      final qs = await q.get();
      results.addAll(qs.docs.map((d) => ProductModel.fromDoc(d)));
    }

    // Sort results to match the order of input IDs
    final idToProduct = {for (var p in results) p.id: p};
    return ids.map((id) => idToProduct[id]).whereType<ProductModel>().toList();
  }

  // Update product fields and optionally replace images
  Future<ProductModel> update({
    required String id,
    String? title,
    String? description,
    double? price,
    List<File>? newImageFiles, // if provided, replaces all images
    File? newPngFile, // if provided, replaces the PNG (uploads and sets productPNGurl)
    Uint8List? newPngBytes,
    bool? removePng, // if true, deletes png from storage and clears field
    String? categoryId,
    String? categoryName,
    int? quantity,
    double? rating,
    int? reviews,
    String? note,
    bool? isActive,
    int? order,
  }) async {
    final docRef = _col.doc(id);
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title.trim();
    if (title != null) data['slug'] = _slugify(title);
    if (description != null) data['description'] = description.trim();
    if (price != null) data['price'] = price;
    if (categoryId != null) data['categoryId'] = categoryId;
    if (categoryName != null) data['categoryName'] = categoryName;
    if (quantity != null) data['quantity'] = quantity;
    if (rating != null) data['rating'] = rating;
    if (reviews != null) data['reviews'] = reviews;
    if (note != null) data['note'] = note;
    if (isActive != null) data['isActive'] = isActive;
    if (order != null) data['order'] = order;

    // If new images provided: delete old, upload new, set imageUrls
    if (newImageFiles != null) {
      try { await _storage.deleteAllProductImages(productId: id); } catch (_) {}
      final urls = <String>[];
      for (var i = 0; i < newImageFiles.length; i++) {
        try {
          final url = await _storage.uploadProductImage(productId: id, file: newImageFiles[i], index: i);
          urls.add(url);
        } catch (e) {
          print('[ProductRepository] Upload failed for image index=$i of product=$id: $e');
        }
      }
      data['imageUrls'] = urls;
    }

    // Handle PNG updates
    if (removePng == true) {
      try { await _storage.deleteProductPng(productId: id); } catch (_) {}
      data['productPNGurl'] = FieldValue.delete();
    } else if (newPngFile != null || newPngBytes != null) {
      try {
        final url = newPngFile != null
            ? await _storage.uploadProductPng(productId: id, file: newPngFile)
            : await _storage.uploadProductPngBytes(productId: id, bytes: newPngBytes!);
        data['productPNGurl'] = url;
      } catch (e) {
        print('[ProductRepository] Upload PNG failed for product=$id: $e');
      }
    }

    data['updatedAt'] = FieldValue.serverTimestamp();
    await docRef.update(data);
    final snap = await docRef.get();
    return ProductModel.fromDoc(snap);
  }

  // Delete product by id: removes all images from Storage and deletes the Firestore document
  Future<void> delete({required String productId}) async {
    // Best-effort delete images first
    try {
      await _storage.deleteAllProductImages(productId: productId);
    } catch (_) {
      // Ignore storage errors to avoid blocking document deletion
    }
    // Delete Firestore document
    await _col.doc(productId).delete();
  }
}
