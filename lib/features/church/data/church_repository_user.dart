import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clientapp/features/church_admin/data/models/church_models.dart' as admin;

class ChurchUserRepository {
  final FirebaseFirestore _db;
  ChurchUserRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _mainCol(admin.ChurchSection section) =>
      _db.collection('churchSections').doc(section.key).collection('items');

  Future<List<admin.ChurchMainItem>> listMain(admin.ChurchSection section) async {
    final qs = await _mainCol(section).orderBy('createdAt', descending: true).get();
    return qs.docs.map((d) => admin.ChurchMainItem.fromDoc(d)).toList();
  }

  Future<List<admin.ChurchSubItem>> listSub(admin.ChurchSection section, String mainId) async {
    final qs = await _mainCol(section).doc(mainId).collection('subitems').orderBy('createdAt', descending: true).get();
    return qs.docs.map((d) => admin.ChurchSubItem.fromDoc(d)).toList();
  }

  /// Fetch radio tracks for Church Radio feature
  Future<List<admin.ChurchRadioTrack>> listRadioTracks() async {
    final qs = await _db.collection('churchRadioTracks').orderBy('order').get();
    return qs.docs.map((d) => admin.ChurchRadioTrack.fromDoc(d)).toList();
  }

  /// Fetch radio snippets for Church Radio feature
  Future<List<admin.ChurchRadioSnippet>> listRadioSnippets() async {
    final qs = await _db.collection('churchRadioSnippets').orderBy('createdAt', descending: true).get();
    return qs.docs.map((d) => admin.ChurchRadioSnippet.fromDoc(d)).toList();
  }
}
