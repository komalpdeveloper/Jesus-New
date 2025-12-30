import 'package:cloud_firestore/cloud_firestore.dart';

/// Extended user model for chat with presence info
class UserChatUser {
  final String id;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool isOnline;
  final DateTime? lastSeen;
  final String? pushToken;

  const UserChatUser({
    required this.id,
    this.email,
    this.displayName,
    this.photoUrl,
    this.isOnline = false,
    this.lastSeen,
    this.pushToken,
  });

  UserChatUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    bool? isOnline,
    DateTime? lastSeen,
    String? pushToken,
  }) {
    return UserChatUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      pushToken: pushToken ?? this.pushToken,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'isOnline': isOnline,
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
      'pushToken': pushToken,
    };
  }

  static UserChatUser fromJson(String id, Map<String, dynamic> json) {
    final lastSeenTs = json['lastSeen'];
    DateTime? lastSeenDate;
    if (lastSeenTs is Timestamp) lastSeenDate = lastSeenTs.toDate();

    return UserChatUser(
      id: id,
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      isOnline: json['isOnline'] as bool? ?? false,
      lastSeen: lastSeenDate,
      pushToken: json['pushToken'] as String?,
    );
  }
}
