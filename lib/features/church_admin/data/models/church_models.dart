import 'package:cloud_firestore/cloud_firestore.dart';

class ChurchMainItem {
  final String id;
  final String title;
  final String? thumbnailUrl;
  final String? audioUrl; // if set, subitems are disabled for this item
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChurchMainItem({
    required this.id,
    required this.title,
    this.thumbnailUrl,
    this.audioUrl,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson({bool forCreate = false}) => {
    if (!forCreate) 'id': id,
    'title': title,
    if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    if (audioUrl != null) 'audioUrl': audioUrl,
    if (description != null) 'description': description,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  factory ChurchMainItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ChurchMainItem(
      id: doc.id,
      title: (d['title'] ?? '') as String,
      thumbnailUrl: d['thumbnailUrl'] as String?,
      audioUrl: d['audioUrl'] as String?,
      description: d['description'] as String?,
      createdAt:
          _tsToDate(d['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _tsToDate(d['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static DateTime? _tsToDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}

class ChurchSubItem {
  final String id;
  final String title;
  final String audioUrl;
  final String? thumbnailUrl;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChurchSubItem({
    required this.id,
    required this.title,
    required this.audioUrl,
    this.thumbnailUrl,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson({bool forCreate = false}) => {
    if (!forCreate) 'id': id,
    'title': title,
    'audioUrl': audioUrl,
    if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    if (description != null) 'description': description,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  factory ChurchSubItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ChurchSubItem(
      id: doc.id,
      title: (d['title'] ?? '') as String,
      audioUrl: (d['audioUrl'] ?? '') as String,
      thumbnailUrl: d['thumbnailUrl'] as String?,
      description: d['description'] as String?,
      createdAt:
          _tsToDate(d['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _tsToDate(d['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static DateTime? _tsToDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}

enum ChurchSection { sermons, stories, sacraments }

extension ChurchSectionX on ChurchSection {
  String get key => switch (this) {
    ChurchSection.sermons => 'sermons',
    ChurchSection.stories => 'stories',
    ChurchSection.sacraments => 'sacraments',
  };
  String get label => switch (this) {
    ChurchSection.sermons => 'Sermons',
    ChurchSection.stories => 'Stories',
    ChurchSection.sacraments => 'Sacraments',
  };
}

/// Radio track audio for Church Radio feature
class ChurchRadioTrack {
  final String id;
  final String title;
  final String audioUrl;
  final int order; // for sorting
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChurchRadioTrack({
    required this.id,
    required this.title,
    required this.audioUrl,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson({bool forCreate = false}) => {
    if (!forCreate) 'id': id,
    'title': title,
    'audioUrl': audioUrl,
    'order': order,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  factory ChurchRadioTrack.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ChurchRadioTrack(
      id: doc.id,
      title: (d['title'] ?? '') as String,
      audioUrl: (d['audioUrl'] ?? '') as String,
      order: (d['order'] ?? 0) as int,
      createdAt:
          _tsToDate(d['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _tsToDate(d['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static DateTime? _tsToDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}

/// Radio snippet audio (plays initially and after every 3 tracks)
class ChurchRadioSnippet {
  final String id;
  final String title;
  final String audioUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChurchRadioSnippet({
    required this.id,
    required this.title,
    required this.audioUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson({bool forCreate = false}) => {
    if (!forCreate) 'id': id,
    'title': title,
    'audioUrl': audioUrl,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  factory ChurchRadioSnippet.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return ChurchRadioSnippet(
      id: doc.id,
      title: (d['title'] ?? '') as String,
      audioUrl: (d['audioUrl'] ?? '') as String,
      createdAt:
          _tsToDate(d['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _tsToDate(d['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static DateTime? _tsToDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}
