import 'package:cloud_firestore/cloud_firestore.dart';
import 'haptic_pattern_model.dart';

/// Link preview data model
class LinkPreview {
  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;

  const LinkPreview({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
    };
  }

  static LinkPreview fromJson(Map<String, dynamic> json) {
    return LinkPreview(
      url: json['url'] as String,
      title: json['title'] as String?,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }
}

/// Message model
class UserChatMessage {
  final String messageId;
  final String senderId;
  final String text;
  final String? imageUrl;
  final HapticPattern? hapticPattern; // Haptic pattern data
  final LinkPreview? linkPreview; // Link preview data
  final DateTime timestamp;
  final String status; // 'sent', 'delivered', 'seen'
  final List<String> seenBy; // List of user IDs who have seen the message

  const UserChatMessage({
    required this.messageId,
    required this.senderId,
    required this.text,
    this.imageUrl,
    this.hapticPattern,
    this.linkPreview,
    required this.timestamp,
    this.status = 'sent',
    this.seenBy = const [],
  });

  UserChatMessage copyWith({
    String? messageId,
    String? senderId,
    String? text,
    String? imageUrl,
    HapticPattern? hapticPattern,
    LinkPreview? linkPreview,
    DateTime? timestamp,
    String? status,
    List<String>? seenBy,
  }) {
    return UserChatMessage(
      messageId: messageId ?? this.messageId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      hapticPattern: hapticPattern ?? this.hapticPattern,
      linkPreview: linkPreview ?? this.linkPreview,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      seenBy: seenBy ?? this.seenBy,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'text': text,
      'imageUrl': imageUrl,
      'hapticPattern': hapticPattern?.toJson(),
      'linkPreview': linkPreview?.toJson(),
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status,
      'seenBy': seenBy,
    };
  }

  static UserChatMessage fromJson(String messageId, Map<String, dynamic> json) {
    final ts = json['timestamp'];
    DateTime timestamp = DateTime.now();
    if (ts is Timestamp) timestamp = ts.toDate();

    HapticPattern? hapticPattern;
    if (json['hapticPattern'] != null) {
      hapticPattern = HapticPattern.fromJson(json['hapticPattern'] as Map<String, dynamic>);
    }

    LinkPreview? linkPreview;
    if (json['linkPreview'] != null) {
      linkPreview = LinkPreview.fromJson(json['linkPreview'] as Map<String, dynamic>);
    }

    return UserChatMessage(
      messageId: messageId,
      senderId: json['senderId'] as String? ?? '',
      text: json['text'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      hapticPattern: hapticPattern,
      linkPreview: linkPreview,
      timestamp: timestamp,
      status: json['status'] as String? ?? 'sent',
      seenBy: (json['seenBy'] as List?)?.whereType<String>().toList() ?? [],
    );
  }
}
