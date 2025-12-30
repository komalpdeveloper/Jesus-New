import 'package:cloud_firestore/cloud_firestore.dart';

enum BannerPlacementDto { homeMain, homeSub, storeSub }

class BannerDoc {
  final String id; // placement_slot id
  final String placement; // string name
  final int slot;
  final String imageUrl;
  final bool isActive;
  BannerDoc({required this.id, required this.placement, required this.slot, required this.imageUrl, this.isActive = true});
}

class BannerRepository {
  final FirebaseFirestore _db;
  BannerRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('banners');

  String _docId(String placement, int slot) => '${placement}_$slot';

  Future<void> upsert({required String placement, required int slot, required String imageUrl, bool isActive = true}) async {
    final id = _docId(placement, slot);
    await _col.doc(id).set({
      'placement': placement,
      'slot': slot,
      'imageUrl': imageUrl,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> delete({required String placement, required int slot}) async {
    final id = _docId(placement, slot);
    await _col.doc(id).delete();
  }

  Future<bool> exists({required String placement, required int slot}) async {
    final id = _docId(placement, slot);
    final snap = await _col.doc(id).get();
    return snap.exists;
  }

  Future<List<BannerDoc>> listAll() async {
    final qs = await _col.get();
    return qs.docs.map((d) {
      final m = d.data();
      return BannerDoc(
        id: d.id,
        placement: m['placement'] as String? ?? 'homeMain',
        slot: (m['slot'] as num?)?.toInt() ?? 0,
        imageUrl: m['imageUrl'] as String? ?? '',
        isActive: (m['isActive'] as bool?) ?? true,
      );
    }).where((b) => b.isActive && b.imageUrl.isNotEmpty).toList();
  }

  Future<List<BannerDoc>> listByPlacement(String placement) async {
    final qs = await _col.where('placement', isEqualTo: placement).get();
    final list = qs.docs.map((d) {
      final m = d.data();
      return BannerDoc(
        id: d.id,
        placement: m['placement'] as String? ?? 'homeMain',
        slot: (m['slot'] as num?)?.toInt() ?? 0,
        imageUrl: m['imageUrl'] as String? ?? '',
        isActive: (m['isActive'] as bool?) ?? true,
      );
    }).where((b) => b.isActive && b.imageUrl.isNotEmpty).toList();
    list.sort((a, b) => a.slot.compareTo(b.slot));
    return list;
  }
}
