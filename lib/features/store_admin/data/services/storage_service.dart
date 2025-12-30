import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class StorageService {
  final FirebaseStorage _storage;
  StorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  // Upload a single image file into products/{productId}/{index}.ext
  // Returns the download URL
  Future<String> uploadProductImage({
    required String productId,
    required File file,
    required int index,
  }) async {
    // Ensure we are authenticated for Storage writes. If not, try to sign in anonymously.
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      try {
        await auth.signInAnonymously();
      } catch (e) {
        // Provide a clearer error for missing auth configuration
        throw FirebaseException(
          plugin: 'firebase_auth',
          message:
              'Failed to authenticate for Storage upload. Enable Anonymous Auth or sign in a user. Original error: $e',
        );
      }
    }

    // Compress and convert to efficient format before upload
    final compressed = await _compressImage(file);
    final ref = _storage
        .ref()
        .child('products')
        .child(productId)
        .child('img_$index.webp');
    final metadata = SettableMetadata(contentType: 'image/webp');
    final task = await ref.putData(compressed, metadata);
    return await task.ref.getDownloadURL();
  }

  // Note: previous extension/content-type helpers removed; we now force WebP uploads

  // Delete all images stored for a product under products/{productId}/
  Future<void> deleteAllProductImages({required String productId}) async {
    final dirRef = _storage.ref().child('products').child(productId);
    try {
      final listResult = await dirRef.listAll();
      for (final item in listResult.items) {
        await item.delete();
      }
    } on FirebaseException {
      // If the folder doesn't exist or permission denied, bubble up for caller to decide
      rethrow;
    }
  }

  // Upload a single PNG file for product icon at products/{productId}/icon.png
  // Returns the download URL
  Future<String> uploadProductPng({
    required String productId,
    required File file,
  }) async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      try {
        await auth.signInAnonymously();
      } catch (e) {
        throw FirebaseException(
          plugin: 'firebase_auth',
          message:
              'Failed to authenticate for Storage upload. Enable Anonymous Auth or sign in a user. Original error: $e',
        );
      }
    }

    final ref = _storage
        .ref()
        .child('products')
        .child(productId)
        .child('icon.png');
    final bytes = await file.readAsBytes();
    final metadata = SettableMetadata(contentType: 'image/png');
    final task = await ref.putData(bytes, metadata);
    return await task.ref.getDownloadURL();
  }

  // Upload PNG from in-memory bytes (useful on iOS/web where path may be null)
  Future<String> uploadProductPngBytes({
    required String productId,
    required Uint8List bytes,
  }) async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      try {
        await auth.signInAnonymously();
      } catch (e) {
        throw FirebaseException(
          plugin: 'firebase_auth',
          message:
              'Failed to authenticate for Storage upload. Enable Anonymous Auth or sign in a user. Original error: $e',
        );
      }
    }
    final ref = _storage
        .ref()
        .child('products')
        .child(productId)
        .child('icon.png');
    final metadata = SettableMetadata(contentType: 'image/png');
    final task = await ref.putData(bytes, metadata);
    return await task.ref.getDownloadURL();
  }

  Future<void> deleteProductPng({required String productId}) async {
    final ref = _storage
        .ref()
        .child('products')
        .child(productId)
        .child('icon.png');
    try {
      await ref.delete();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return; // already gone
      rethrow;
    }
  }

  // ===== Church uploads =====

  Future<String> uploadChurchThumbnail({
    required String sectionKey,
    required String mainId,
    required File file,
  }) async {
    // authenticate
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      try {
        await auth.signInAnonymously();
      } catch (e) {
        throw FirebaseException(
          plugin: 'firebase_auth',
          message: 'Failed auth: $e',
        );
      }
    }
    final data = await _compressImage(
      file,
      maxWidth: 1024,
      maxHeight: 1024,
      quality: 75,
    );
    final ref = _storage
        .ref()
        .child('church')
        .child(sectionKey)
        .child(mainId)
        .child('thumb.webp');
    final task = await ref.putData(
      data,
      SettableMetadata(contentType: 'image/webp'),
    );
    return await task.ref.getDownloadURL();
  }

  Future<String> uploadChurchSubThumbnail({
    required String sectionKey,
    required String mainId,
    required String subId,
    required File file,
  }) async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      try {
        await auth.signInAnonymously();
      } catch (e) {
        throw FirebaseException(
          plugin: 'firebase_auth',
          message: 'Failed auth: $e',
        );
      }
    }
    final data = await _compressImage(
      file,
      maxWidth: 1024,
      maxHeight: 1024,
      quality: 75,
    );
    final ref = _storage
        .ref()
        .child('church')
        .child(sectionKey)
        .child(mainId)
        .child('subs')
        .child(subId)
        .child('thumb.webp');
    final task = await ref.putData(
      data,
      SettableMetadata(contentType: 'image/webp'),
    );
    return await task.ref.getDownloadURL();
  }

  Future<String> uploadChurchAudio({
    required String sectionKey,
    required String mainId,
    required String audioId,
    required Uint8List bytes,
    String contentType = 'audio/mpeg',
    void Function(double progress)? onProgress,
  }) async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      try {
        await auth.signInAnonymously();
      } catch (e) {
        throw FirebaseException(
          plugin: 'firebase_auth',
          message: 'Failed auth: $e',
        );
      }
    }
    final ref = _storage
        .ref()
        .child('church')
        .child(sectionKey)
        .child(mainId)
        .child('$audioId.mp3');
    final uploadTask = ref.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((snap) {
        final total = snap.totalBytes;
        final transferred = snap.bytesTransferred;
        if (total > 0) onProgress((transferred / total).clamp(0.0, 1.0));
      });
    }
    final taskSnap = await uploadTask;
    return await taskSnap.ref.getDownloadURL();
  }

  Future<void> deleteChurchMainFolder({
    required String sectionKey,
    required String mainId,
  }) async {
    final dir = _storage.ref().child('church').child(sectionKey).child(mainId);
    try {
      final res = await dir.listAll();
      for (final it in res.items) {
        await it.delete();
      }
      for (final p in res.prefixes) {
        final pr = await p.listAll();
        for (final it in pr.items) {
          await it.delete();
        }
      }
    } on FirebaseException {
      rethrow;
    }
  }

  // ===== Church Radio Tracks =====

  Future<String> uploadChurchRadioTrack({
    required String trackId,
    required String audioId,
    required Uint8List bytes,
    String contentType = 'audio/mpeg',
    void Function(double progress)? onProgress,
  }) async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      try {
        await auth.signInAnonymously();
      } catch (e) {
        throw FirebaseException(
          plugin: 'firebase_auth',
          message: 'Failed auth: $e',
        );
      }
    }
    final ref = _storage
        .ref()
        .child('church')
        .child('radio')
        .child(trackId)
        .child('$audioId.mp3');
    final uploadTask = ref.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((snap) {
        final total = snap.totalBytes;
        final transferred = snap.bytesTransferred;
        if (total > 0) onProgress((transferred / total).clamp(0.0, 1.0));
      });
    }
    final taskSnap = await uploadTask;
    return await taskSnap.ref.getDownloadURL();
  }

  Future<void> deleteChurchRadioTrack({required String trackId}) async {
    final dir = _storage.ref().child('church').child('radio').child(trackId);
    try {
      final res = await dir.listAll();
      for (final it in res.items) {
        await it.delete();
      }
    } on FirebaseException {
      rethrow;
    }
  }

  // ===== Church Radio Snippets =====

  Future<String> uploadChurchRadioSnippet({
    required String snippetId,
    required String audioId,
    required Uint8List bytes,
    String contentType = 'audio/mpeg',
    void Function(double progress)? onProgress,
  }) async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      try {
        await auth.signInAnonymously();
      } catch (e) {
        throw FirebaseException(
          plugin: 'firebase_auth',
          message: 'Failed auth: $e',
        );
      }
    }
    final ref = _storage
        .ref()
        .child('church')
        .child('radio')
        .child('snippets')
        .child(snippetId)
        .child('$audioId.mp3');
    final uploadTask = ref.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((snap) {
        final total = snap.totalBytes;
        final transferred = snap.bytesTransferred;
        if (total > 0) onProgress((transferred / total).clamp(0.0, 1.0));
      });
    }
    final taskSnap = await uploadTask;
    return await taskSnap.ref.getDownloadURL();
  }

  Future<void> deleteChurchRadioSnippet({required String snippetId}) async {
    final dir = _storage.ref().child('church').child('radio').child('snippets').child(snippetId);
    try {
      final res = await dir.listAll();
      for (final it in res.items) {
        await it.delete();
      }
    } on FirebaseException {
      rethrow;
    }
  }

  // Upload banner image to banners/{placement}/{slot}{ext}
  Future<String> uploadBannerImage({
    required String placement,
    required int slot,
    required File file,
  }) async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      try {
        await auth.signInAnonymously();
      } catch (e) {
        throw FirebaseException(
          plugin: 'firebase_auth',
          message:
              'Failed to authenticate for Storage upload. Enable Anonymous Auth or sign in a user. Original error: $e',
        );
      }
    }
    final data = await _compressImage(
      file,
      maxWidth: 1600,
      maxHeight: 1600,
      quality: 75,
    );
    final ref = _storage
        .ref()
        .child('banners')
        .child(placement)
        .child('slot_$slot.webp');
    final metadata = SettableMetadata(contentType: 'image/webp');
    final task = await ref.putData(data, metadata);
    return await task.ref.getDownloadURL();
  }

  Future<void> deleteBannerImage({
    required String placement,
    required int slot,
  }) async {
    final dir = _storage.ref().child('banners').child(placement);
    final list = await dir.listAll();
    for (final item in list.items) {
      // delete any file for this slot (slot_# with any extension)
      if (item.name.startsWith('slot_$slot')) {
        await item.delete();
      }
    }
  }

  // Compress image file to WebP with sensible defaults
  // Returns bytes suitable for putData
  Future<Uint8List> _compressImage(
    File input, {
    int maxWidth = 1024,
    int maxHeight = 1024,
    int quality = 70,
  }) async {
    // On Web, skip compression to avoid unsupported platform issues.
    if (kIsWeb) {
      return await input.readAsBytes();
    }
    // Try WebP first for best size/quality; fallback to JPEG if not supported
    try {
      final out = await FlutterImageCompress.compressWithFile(
        input.absolute.path,
        minWidth: maxWidth,
        minHeight: maxHeight,
        quality: quality,
        format: CompressFormat.webp,
      );
      if (out != null) return Uint8List.fromList(out);
    } catch (_) {}
    final jpeg = await FlutterImageCompress.compressWithFile(
      input.absolute.path,
      minWidth: maxWidth,
      minHeight: maxHeight,
      quality: quality,
      format: CompressFormat.jpeg,
    );
    if (jpeg == null) {
      // As a last resort, read original bytes (not ideal)
      return await input.readAsBytes();
    }
    return Uint8List.fromList(jpeg);
  }
}
