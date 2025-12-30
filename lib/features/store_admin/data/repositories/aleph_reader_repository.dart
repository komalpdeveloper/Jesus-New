import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/verse.dart';

class AlephReaderRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int _pageSize = 20;

  Future<List<Verse>> fetchAllVerses(String collectionPath) async {
    final querySnapshot = await _firestore.collectionGroup(collectionPath)
        .orderBy('global_id', descending: false)
        .get();
    return querySnapshot.docs.map((doc) => Verse.fromFirestore(doc)).toList();
  }

  Future<List<Verse>> fetchVerses({DocumentSnapshot? lastDocument, required String collectionPath}) async {
    Query query = _firestore.collectionGroup(collectionPath)
        .orderBy('global_id', descending: false)
        .limit(_pageSize);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final querySnapshot = await query.get();
    return querySnapshot.docs.map((doc) => Verse.fromFirestore(doc)).toList();
  }

  Future<QuerySnapshot> fetchVersesSnapshot({DocumentSnapshot? lastDocument, required String collectionPath}) async {
    debugPrint('Fetching verses from $collectionPath... lastDoc: ${lastDocument?.id}');
    Query query = _firestore.collectionGroup(collectionPath)
        .orderBy('global_id', descending: false)
        .limit(_pageSize);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return await query.get().timeout(const Duration(seconds: 10));
  }
}
