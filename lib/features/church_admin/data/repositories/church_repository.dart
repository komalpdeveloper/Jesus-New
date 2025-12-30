import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../store_admin/data/services/storage_service.dart';
import '../models/church_models.dart';

class ChurchRepository {
  final FirebaseFirestore _db;
  final StorageService _storage;
  ChurchRepository({FirebaseFirestore? db, StorageService? storage})
      : _db = db ?? FirebaseFirestore.instance,
        _storage = storage ?? StorageService();

  CollectionReference<Map<String, dynamic>> _mainCol(ChurchSection section) =>
      _db.collection('churchSections').doc(section.key).collection('items');

  // Create main item (thumbnail optional, audio optional)
  Future<ChurchMainItem> createMain({
    required ChurchSection section,
    required String title,
    String? description,
    File? thumbnailFile,
  Uint8List? audioBytes,
  void Function(double progress)? onAudioProgress,
    String audioContentType = 'audio/mpeg',
  }) async {
    final col = _mainCol(section);
    final docRef = await col.add({
      'title': title.trim(),
      if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    String? thumbUrl;
    String? audioUrl;
    if (thumbnailFile != null) {
      try {
        thumbUrl = await _storage.uploadChurchThumbnail(sectionKey: section.key, mainId: docRef.id, file: thumbnailFile);
      } catch (_) {}
    }
    if (audioBytes != null) {
      try {
        final audioId = const Uuid().v4();
        audioUrl = await _storage.uploadChurchAudio(sectionKey: section.key, mainId: docRef.id, audioId: audioId, bytes: audioBytes, contentType: audioContentType, onProgress: onAudioProgress);
      } catch (_) {}
    }
    final upd = <String, dynamic>{
      if (thumbUrl != null) 'thumbnailUrl': thumbUrl,
      if (audioUrl != null) 'audioUrl': audioUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (upd.isNotEmpty) await docRef.update(upd);
    final snap = await docRef.get();
    return ChurchMainItem.fromDoc(snap);
  }

  Future<List<ChurchMainItem>> listMain(ChurchSection section) async {
    final qs = await _mainCol(section).orderBy('createdAt', descending: true).get();
    return qs.docs.map((d) => ChurchMainItem.fromDoc(d)).toList();
  }

  Future<ChurchMainItem?> getMain(ChurchSection section, String id) async {
    final snap = await _mainCol(section).doc(id).get();
    if (!snap.exists) return null;
    return ChurchMainItem.fromDoc(snap);
  }

  Future<void> deleteMain(ChurchSection section, String id) async {
    // delete any storage under this folder, then doc and subitems collection
    try { await _storage.deleteChurchMainFolder(sectionKey: section.key, mainId: id); } catch (_) {}
    // delete subitems docs
    final subCol = _mainCol(section).doc(id).collection('subitems');
    final subs = await subCol.get();
    for (final d in subs.docs) { await d.reference.delete(); }
    await _mainCol(section).doc(id).delete();
  }

  Future<ChurchMainItem> updateMain({
    required ChurchSection section,
    required String id,
    String? title,
    String? description,
    File? newThumbnail,
  Uint8List? newAudioBytes,
  void Function(double progress)? onAudioProgress,
    bool? removeAudio,
    String audioContentType = 'audio/mpeg',
  }) async {
    final docRef = _mainCol(section).doc(id);
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title.trim();
    if (description != null) {
      data['description'] = description.trim();
    }
    if (newThumbnail != null) {
      try {
        final url = await _storage.uploadChurchThumbnail(sectionKey: section.key, mainId: id, file: newThumbnail);
        data['thumbnailUrl'] = url;
      } catch (_) {}
    }
    if (removeAudio == true) {
      data['audioUrl'] = FieldValue.delete();
    } else if (newAudioBytes != null) {
      final audioId = const Uuid().v4();
      try {
        final url = await _storage.uploadChurchAudio(sectionKey: section.key, mainId: id, audioId: audioId, bytes: newAudioBytes, contentType: audioContentType, onProgress: onAudioProgress);
        data['audioUrl'] = url;
      } catch (_) {}
    }
    data['updatedAt'] = FieldValue.serverTimestamp();
    if (data.isNotEmpty) await docRef.update(data);
    final snap = await docRef.get();
    return ChurchMainItem.fromDoc(snap);
  }

  // Subitems (only allowed when main has no audioUrl)
  CollectionReference<Map<String, dynamic>> _subCol(ChurchSection section, String mainId) =>
      _mainCol(section).doc(mainId).collection('subitems');

  Future<ChurchSubItem> addSubItem({
    required ChurchSection section,
    required String mainId,
    required String title,
    String? description,
    File? thumbnailFile,
  required Uint8List audioBytes,
  void Function(double progress)? onAudioProgress,
    String audioContentType = 'audio/mpeg',
  }) async {
    final subCol = _subCol(section, mainId);
    final docRef = await subCol.add({
      'title': title.trim(),
      if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final audioId = const Uuid().v4();
  final url = await _storage.uploadChurchAudio(sectionKey: section.key, mainId: mainId, audioId: audioId, bytes: audioBytes, contentType: audioContentType, onProgress: onAudioProgress);
    String? thumbUrl;
    if (thumbnailFile != null) {
      try {
        thumbUrl = await _storage.uploadChurchSubThumbnail(sectionKey: section.key, mainId: mainId, subId: docRef.id, file: thumbnailFile);
      } catch (_) {}
    }
    await docRef.update({
      'audioUrl': url,
      if (thumbUrl != null) 'thumbnailUrl': thumbUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final snap = await docRef.get();
    return ChurchSubItem.fromDoc(snap);
  }

  Future<List<ChurchSubItem>> listSubItems(ChurchSection section, String mainId) async {
    final qs = await _subCol(section, mainId).orderBy('createdAt', descending: true).get();
    return qs.docs.map((d) => ChurchSubItem.fromDoc(d)).toList();
  }

  Future<void> deleteSubItem(ChurchSection section, String mainId, String id) async {
    await _subCol(section, mainId).doc(id).delete();
  }

  Future<ChurchSubItem> updateSubItem({
    required ChurchSection section,
    required String mainId,
    required String id,
    String? title,
    String? description,
    File? newThumbnail,
  Uint8List? newAudioBytes,
  void Function(double progress)? onAudioProgress,
    bool? removeAudio,
    String audioContentType = 'audio/mpeg',
  }) async {
    final docRef = _subCol(section, mainId).doc(id);
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title.trim();
    if (description != null) data['description'] = description.trim();
    if (newThumbnail != null) {
      try {
        final url = await _storage.uploadChurchSubThumbnail(sectionKey: section.key, mainId: mainId, subId: id, file: newThumbnail);
        data['thumbnailUrl'] = url;
      } catch (_) {}
    }
    if (removeAudio == true) {
      data['audioUrl'] = FieldValue.delete();
    } else if (newAudioBytes != null) {
      final audioId = const Uuid().v4();
      try {
        final url = await _storage.uploadChurchAudio(sectionKey: section.key, mainId: mainId, audioId: audioId, bytes: newAudioBytes, contentType: audioContentType, onProgress: onAudioProgress);
        data['audioUrl'] = url;
      } catch (_) {}
    }
    data['updatedAt'] = FieldValue.serverTimestamp();
    if (data.isNotEmpty) await docRef.update(data);
    final snap = await docRef.get();
    return ChurchSubItem.fromDoc(snap);
  }

  // ========== Radio Tracks ==========
  
  CollectionReference<Map<String, dynamic>> _radioTracksCol() =>
      _db.collection('churchRadioTracks');

  /// Create a new radio track
  Future<ChurchRadioTrack> createRadioTrack({
    required String title,
    required Uint8List audioBytes,
    void Function(double progress)? onProgress,
    String audioContentType = 'audio/mpeg',
  }) async {
    final col = _radioTracksCol();
    
    // Get current count for order
    final count = (await col.get()).docs.length;
    
    // Create document
    final docRef = await col.add({
      'title': title.trim(),
      'order': count,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    // Upload audio to Firebase Storage
    final audioId = const Uuid().v4();
    final audioUrl = await _storage.uploadChurchRadioTrack(
      trackId: docRef.id,
      audioId: audioId,
      bytes: audioBytes,
      contentType: audioContentType,
      onProgress: onProgress,
    );
    
    // Update with audio URL
    await docRef.update({
      'audioUrl': audioUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    final snap = await docRef.get();
    return ChurchRadioTrack.fromDoc(snap);
  }

  /// List all radio tracks
  Future<List<ChurchRadioTrack>> listRadioTracks() async {
    final qs = await _radioTracksCol().orderBy('order').get();
    return qs.docs.map((d) => ChurchRadioTrack.fromDoc(d)).toList();
  }

  /// Delete a radio track
  Future<void> deleteRadioTrack(String id) async {
    try {
      await _storage.deleteChurchRadioTrack(trackId: id);
    } catch (_) {}
    await _radioTracksCol().doc(id).delete();
  }

  /// Update radio track
  Future<ChurchRadioTrack> updateRadioTrack({
    required String id,
    String? title,
    Uint8List? newAudioBytes,
    void Function(double progress)? onProgress,
    String audioContentType = 'audio/mpeg',
  }) async {
    final docRef = _radioTracksCol().doc(id);
    final data = <String, dynamic>{};
    
    if (title != null) data['title'] = title.trim();
    
    if (newAudioBytes != null) {
      final audioId = const Uuid().v4();
      try {
        final url = await _storage.uploadChurchRadioTrack(
          trackId: id,
          audioId: audioId,
          bytes: newAudioBytes,
          contentType: audioContentType,
          onProgress: onProgress,
        );
        data['audioUrl'] = url;
      } catch (_) {}
    }
    
    data['updatedAt'] = FieldValue.serverTimestamp();
    if (data.isNotEmpty) await docRef.update(data);
    
    final snap = await docRef.get();
    return ChurchRadioTrack.fromDoc(snap);
  }

  /// Reorder radio tracks
  Future<void> reorderRadioTracks(List<String> orderedIds) async {
    final batch = _db.batch();
    for (var i = 0; i < orderedIds.length; i++) {
      final docRef = _radioTracksCol().doc(orderedIds[i]);
      batch.update(docRef, {
        'order': i,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  // ========== Radio Snippets ==========
  
  CollectionReference<Map<String, dynamic>> _radioSnippetsCol() =>
      _db.collection('churchRadioSnippets');

  /// Create a new radio snippet
  Future<ChurchRadioSnippet> createRadioSnippet({
    required String title,
    required Uint8List audioBytes,
    void Function(double progress)? onProgress,
    String audioContentType = 'audio/mpeg',
  }) async {
    final col = _radioSnippetsCol();
    
    // Create document
    final docRef = await col.add({
      'title': title.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    // Upload audio to Firebase Storage
    final audioId = const Uuid().v4();
    final audioUrl = await _storage.uploadChurchRadioSnippet(
      snippetId: docRef.id,
      audioId: audioId,
      bytes: audioBytes,
      contentType: audioContentType,
      onProgress: onProgress,
    );
    
    // Update with audio URL
    await docRef.update({
      'audioUrl': audioUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    final snap = await docRef.get();
    return ChurchRadioSnippet.fromDoc(snap);
  }

  /// List all radio snippets
  Future<List<ChurchRadioSnippet>> listRadioSnippets() async {
    final qs = await _radioSnippetsCol().orderBy('createdAt', descending: true).get();
    return qs.docs.map((d) => ChurchRadioSnippet.fromDoc(d)).toList();
  }

  /// Delete a radio snippet
  Future<void> deleteRadioSnippet(String id) async {
    try {
      await _storage.deleteChurchRadioSnippet(snippetId: id);
    } catch (_) {}
    await _radioSnippetsCol().doc(id).delete();
  }

  /// Update radio snippet
  Future<ChurchRadioSnippet> updateRadioSnippet({
    required String id,
    String? title,
    Uint8List? newAudioBytes,
    void Function(double progress)? onProgress,
    String audioContentType = 'audio/mpeg',
  }) async {
    final docRef = _radioSnippetsCol().doc(id);
    final data = <String, dynamic>{};
    
    if (title != null) data['title'] = title.trim();
    
    if (newAudioBytes != null) {
      final audioId = const Uuid().v4();
      try {
        final url = await _storage.uploadChurchRadioSnippet(
          snippetId: id,
          audioId: audioId,
          bytes: newAudioBytes,
          contentType: audioContentType,
          onProgress: onProgress,
        );
        data['audioUrl'] = url;
      } catch (_) {}
    }
    
    data['updatedAt'] = FieldValue.serverTimestamp();
    if (data.isNotEmpty) await docRef.update(data);
    
    final snap = await docRef.get();
    return ChurchRadioSnippet.fromDoc(snap);
  }
}
