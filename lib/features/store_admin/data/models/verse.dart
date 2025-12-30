import 'package:cloud_firestore/cloud_firestore.dart';

class Verse {
  final String id;
  final int globalId;
  final int revelationNumber;
  final String content;

  Verse({
    required this.id,
    required this.globalId,
    required this.revelationNumber,
    required this.content,
  });

  factory Verse.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Verse(
      id: doc.id,
      globalId: data['global_id'] as int? ?? 0,
      revelationNumber: data['revelation'] as int? ?? 0,
      content: data['text'] as String? ?? '',
    );
  }
}
