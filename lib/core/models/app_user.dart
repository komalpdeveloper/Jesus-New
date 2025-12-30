import 'package:cloud_firestore/cloud_firestore.dart';

/// App user model stored in Firestore under `users/{uid}`.
class AppUser {
  final String id; // auth uid (document id)
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final DateTime? createdAt;
  final int ringCount;
  final int altarRings; // Rings progress towards next level
  final int altarLevel; // Current Altar Level (1M rings = 1 level)
  final List<String> boughtItems; // Array of purchased item IDs

  const AppUser({
    required this.id,
    this.email,
    this.displayName,
    this.photoUrl,
    this.createdAt,
    this.ringCount = 0,
    this.altarRings = 0,
    this.altarLevel = 0,
    this.boughtItems = const [],
  });

  AppUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    DateTime? createdAt,
    int? ringCount,
    int? altarRings,
    int? altarLevel,
    List<String>? boughtItems,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      ringCount: ringCount ?? this.ringCount,
      altarRings: altarRings ?? this.altarRings,
      altarLevel: altarLevel ?? this.altarLevel,
      boughtItems: boughtItems ?? this.boughtItems,
    );
  }

  Map<String, dynamic> toJson({bool includeId = false}) {
    return {
      if (includeId) 'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'ringCount': ringCount,
      'altarRings': altarRings,
      'altarLevel': altarLevel,
      'boughtItems': boughtItems,
    };
  }

  static AppUser fromJson(String id, Map<String, dynamic> json) {
    final ts = json['createdAt'];
    DateTime? created;
    if (ts is Timestamp) created = ts.toDate();
    return AppUser(
      id: id,
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      createdAt: created,
      ringCount: (json['ringCount'] as num?)?.toInt() ?? 0,
      altarRings: (json['altarRings'] as num?)?.toInt() ?? 0,
      altarLevel: (json['altarLevel'] as num?)?.toInt() ?? 0,
      boughtItems:
          (json['boughtItems'] as List?)?.whereType<String>().toList() ??
          const [],
    );
  }

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppUser(
      id: doc.id,
      email: data['email'],
      displayName: data['displayName'],
      photoUrl: data['photoUrl'],
      createdAt: _tsToDate(data['createdAt']),
      ringCount: (data['ringCount'] ?? 0) as int,
      altarRings: (data['altarRings'] ?? 0) as int,
      altarLevel: (data['altarLevel'] ?? 0) as int,
      boughtItems: List<String>.from(data['boughtItems'] ?? []),
    );
  }

  static DateTime? _tsToDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}
