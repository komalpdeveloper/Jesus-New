import 'package:cloud_firestore/cloud_firestore.dart';

/// Chat document model
class UserChat {
  final String chatId;
  final String type; // 'private' or 'group'
  final List<String> participants; // List of user IDs
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? lastMessageSender;
  final Map<String, bool> typing; // {userId: isTyping}
  final bool isApproved; // Whether chat is approved by receiver
  final String? requestedBy; // User ID who initiated the chat
  final List<String> archivedBy; // List of user IDs who archived this chat

  const UserChat({
    required this.chatId,
    required this.type,
    required this.participants,
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageSender,
    this.typing = const {},
    this.isApproved = false,
    this.requestedBy,
    this.archivedBy = const [],
  });

  UserChat copyWith({
    String? chatId,
    String? type,
    List<String>? participants,
    String? lastMessage,
    DateTime? lastMessageTime,
    String? lastMessageSender,
    Map<String, bool>? typing,
    bool? isApproved,
    String? requestedBy,
    List<String>? archivedBy,
  }) {
    return UserChat(
      chatId: chatId ?? this.chatId,
      type: type ?? this.type,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageSender: lastMessageSender ?? this.lastMessageSender,
      typing: typing ?? this.typing,
      isApproved: isApproved ?? this.isApproved,
      requestedBy: requestedBy ?? this.requestedBy,
      archivedBy: archivedBy ?? this.archivedBy,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime != null 
          ? Timestamp.fromDate(lastMessageTime!) 
          : FieldValue.serverTimestamp(),
      'lastMessageSender': lastMessageSender,
      'typing': typing,
      'isApproved': isApproved,
      'requestedBy': requestedBy,
      'archivedBy': archivedBy,
    };
  }

  static UserChat fromJson(String chatId, Map<String, dynamic> json) {
    final lastMsgTs = json['lastMessageTime'];
    DateTime? lastMsgDate;
    if (lastMsgTs is Timestamp) lastMsgDate = lastMsgTs.toDate();

    return UserChat(
      chatId: chatId,
      type: json['type'] as String? ?? 'private',
      participants: (json['participants'] as List?)?.whereType<String>().toList() ?? [],
      lastMessage: json['lastMessage'] as String?,
      lastMessageTime: lastMsgDate,
      lastMessageSender: json['lastMessageSender'] as String?,
      typing: (json['typing'] as Map?)?.map((k, v) => MapEntry(k.toString(), v as bool)) ?? {},
      isApproved: json['isApproved'] as bool? ?? false,
      requestedBy: json['requestedBy'] as String?,
      archivedBy: (json['archivedBy'] as List?)?.whereType<String>().toList() ?? [],
    );
  }

  // Check if chat is archived by a specific user
  bool isArchivedBy(String userId) => archivedBy.contains(userId);
}
