import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_chat_model.dart';
import '../models/user_chat_message.dart';
import '../models/user_chat_user.dart';
import 'package:clientapp/core/reward/user_chat/user_chat_reward_service.dart';

class UserChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // Get or create a private chat between two users
  Future<String> getOrCreatePrivateChat(String otherUserId) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    final participants = [currentUserId!, otherUserId]..sort();
    
    // Check if chat already exists
    final existingChats = await _firestore
        .collection('chats')
        .where('participants', isEqualTo: participants)
        .where('type', isEqualTo: 'private')
        .limit(1)
        .get();

    if (existingChats.docs.isNotEmpty) {
      return existingChats.docs.first.id;
    }

    // Create new chat
    final chatDoc = await _firestore.collection('chats').add({
      'type': 'private',
      'participants': participants,
      'lastMessage': null,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSender': null,
      'typing': {},
    });

    return chatDoc.id;
  }

  // Stream all chats for current user
  Stream<List<UserChat>> getUserChats() {
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .handleError((error) {
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('🔥 FIRESTORE INDEX REQUIRED 🔥');
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('Error: $error');
      debugPrint('');
      debugPrint('📋 ACTION REQUIRED:');
      debugPrint('Click the link above to create the required Firestore index.');
      debugPrint('Or manually create this index in Firebase Console:');
      debugPrint('');
      debugPrint('Collection: chats');
      debugPrint('Fields:');
      debugPrint('  - participants (Array)');
      debugPrint('  - lastMessageTime (Descending)');
      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════════');
    }).map((snapshot) {
      final allChats = snapshot.docs.map((doc) => UserChat.fromJson(doc.id, doc.data())).toList();
      
      // Filter: Only exclude archived chats, show everything else
      final filteredChats = allChats.where((chat) {
        return !chat.isArchivedBy(currentUserId!);
      }).toList();
      
      return filteredChats;
    });
  }

  // Stream messages for a specific chat with pagination
  Stream<List<UserChatMessage>> getChatMessages(String chatId, {int limit = 50}) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .handleError((error) {
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('🔥 FIRESTORE INDEX REQUIRED 🔥');
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('Error: $error');
      debugPrint('');
      debugPrint('📋 ACTION REQUIRED:');
      debugPrint('Click the link above to create the required Firestore index.');
      debugPrint('Or manually create this index in Firebase Console:');
      debugPrint('');
      debugPrint('Collection Group: messages');
      debugPrint('Fields:');
      debugPrint('  - timestamp (Descending)');
      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════════');
    }).map((snapshot) => snapshot.docs
            .map((doc) => UserChatMessage.fromJson(doc.id, doc.data()))
            .toList());
  }

  // Load more messages for pagination
  Future<List<UserChatMessage>> loadMoreMessages(
    String chatId, 
    DateTime lastMessageTime, 
    {int limit = 20}
  ) async {
    final snapshot = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .where('timestamp', isLessThan: Timestamp.fromDate(lastMessageTime))
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => UserChatMessage.fromJson(doc.id, doc.data()))
        .toList();
  }

  // Send a text message
  Future<void> sendMessage({
    required String chatId,
    required String text,
    String? imageUrl,
    UserChatMessage? hapticPattern,
    LinkPreview? linkPreview,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    final messageData = UserChatMessage(
      messageId: '',
      senderId: currentUserId!,
      text: text,
      imageUrl: imageUrl,
      hapticPattern: hapticPattern?.hapticPattern,
      linkPreview: linkPreview,
      timestamp: DateTime.now(),
      status: 'sent',
      seenBy: [currentUserId!],
    );

    // Add message to subcollection
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(messageData.toJson());

    // Determine last message preview text
    String lastMessagePreview;
    if (text.isNotEmpty) {
      lastMessagePreview = text;
    } else if (linkPreview != null) {
      lastMessagePreview = '🔗 Link';
    } else {
      lastMessagePreview = '🤚 Haptic pattern';
    }

    // Update chat document with last message info
    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': lastMessagePreview,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSender': currentUserId,
    });

    // Award rings for sending a message
    UserChatRewardService.instance.rewardMessageSent();
  }

  // Mark messages as delivered when user opens chat
  Future<void> markMessagesAsDelivered(String chatId) async {
    if (currentUserId == null) return;

    final messages = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('senderId', isNotEqualTo: currentUserId)
        .where('status', isEqualTo: 'sent')
        .get();

    final batch = _firestore.batch();
    for (var doc in messages.docs) {
      batch.update(doc.reference, {'status': 'delivered'});
    }
    await batch.commit();
  }

  // Mark messages as seen when user views them
  Future<void> markMessagesAsSeen(String chatId) async {
    if (currentUserId == null) return;

    final messages = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('senderId', isNotEqualTo: currentUserId)
        .get();

    final batch = _firestore.batch();
    for (var doc in messages.docs) {
      final seenBy = List<String>.from(doc.data()['seenBy'] ?? []);
      if (!seenBy.contains(currentUserId)) {
        seenBy.add(currentUserId!);
        batch.update(doc.reference, {
          'status': 'seen',
          'seenBy': seenBy,
        });
      }
    }
    await batch.commit();
  }

  // Update typing status
  Future<void> updateTypingStatus(String chatId, bool isTyping) async {
    if (currentUserId == null) return;

    await _firestore.collection('chats').doc(chatId).update({
      'typing.$currentUserId': isTyping,
    });
  }

  // Get user info
  Future<UserChatUser?> getUser(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return UserChatUser.fromJson(doc.id, doc.data()!);
  }

  // Stream user info
  Stream<UserChatUser?> streamUser(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? UserChatUser.fromJson(doc.id, doc.data()!) : null);
  }

  // Update user presence
  Future<void> updateUserPresence({required bool isOnline}) async {
    if (currentUserId == null) return;

    await _firestore.collection('users').doc(currentUserId).update({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  // Search users by username
  Future<List<UserChatUser>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    try {
      // Search by username field
      final snapshot = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('username', isLessThanOrEqualTo: '${query.toLowerCase()}\uf8ff')
          .limit(20)
          .get();

      return snapshot.docs
          .map((doc) => UserChatUser.fromJson(doc.id, doc.data()))
          .where((user) => user.id != currentUserId)
          .toList();
    } catch (error) {
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('🔥 FIRESTORE INDEX REQUIRED 🔥');
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('Error: $error');
      debugPrint('');
      debugPrint('📋 ACTION REQUIRED:');
      debugPrint('Click the link above to create the required Firestore index.');
      debugPrint('Or manually create this index in Firebase Console:');
      debugPrint('');
      debugPrint('Collection: users');
      debugPrint('Fields:');
      debugPrint('  - username (Ascending)');
      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════════');
      rethrow;
    }
  }

  // Get username from user document
  Future<String?> getUsername(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data()?['username'] as String?;
    } catch (e) {
      debugPrint('Error getting username: $e');
      return null;
    }
  }

  // Stream a specific chat
  Stream<UserChat?> streamChat(String chatId) {
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .snapshots()
        .map((doc) => doc.exists ? UserChat.fromJson(doc.id, doc.data()!) : null);
  }

  // Get unread message count for a chat
  Stream<int> getUnreadMessageCount(String chatId) {
    if (currentUserId == null) return Stream.value(0);

    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('senderId', isNotEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
      int unreadCount = 0;
      for (var doc in snapshot.docs) {
        final seenBy = List<String>.from(doc.data()['seenBy'] ?? []);
        if (!seenBy.contains(currentUserId)) {
          unreadCount++;
        }
      }
      return unreadCount;
    });
  }

  // Get total unread message count across all chats
  Stream<int> getTotalUnreadCount() {
    if (currentUserId == null) return Stream.value(0);

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .asyncMap((chatsSnapshot) async {
      int totalUnread = 0;
      
      for (var chatDoc in chatsSnapshot.docs) {
        final messagesSnapshot = await _firestore
            .collection('chats')
            .doc(chatDoc.id)
            .collection('messages')
            .where('senderId', isNotEqualTo: currentUserId)
            .get();

        for (var msgDoc in messagesSnapshot.docs) {
          final seenBy = List<String>.from(msgDoc.data()['seenBy'] ?? []);
          if (!seenBy.contains(currentUserId)) {
            totalUnread++;
          }
        }
      }
      
      return totalUnread;
    });
  }

  // Archive a chat
  Future<void> archiveChat(String chatId) async {
    if (currentUserId == null) return;

    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    final archivedBy = List<String>.from(chatDoc.data()?['archivedBy'] ?? []);
    
    if (!archivedBy.contains(currentUserId)) {
      archivedBy.add(currentUserId!);
      await _firestore.collection('chats').doc(chatId).update({
        'archivedBy': archivedBy,
      });
    }
  }

  // Unarchive a chat
  Future<void> unarchiveChat(String chatId) async {
    if (currentUserId == null) return;

    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    final archivedBy = List<String>.from(chatDoc.data()?['archivedBy'] ?? []);
    
    archivedBy.remove(currentUserId);
    await _firestore.collection('chats').doc(chatId).update({
      'archivedBy': archivedBy,
    });
  }

  // Get archived chats
  Stream<List<UserChat>> getArchivedChats() {
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) {
      final allChats = snapshot.docs.map((doc) => UserChat.fromJson(doc.id, doc.data())).toList();
      
      // Filter archived chats
      return allChats.where((chat) => chat.isArchivedBy(currentUserId!)).toList();
    });
  }

  // Approve a message request
  Future<void> approveMessageRequest(String chatId) async {
    await _firestore.collection('chats').doc(chatId).update({
      'isApproved': true,
    });
  }

  // Decline a message request
  Future<void> declineMessageRequest(String chatId) async {
    // Delete the chat and all messages
    final messagesSnapshot = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .get();

    final batch = _firestore.batch();
    for (var doc in messagesSnapshot.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_firestore.collection('chats').doc(chatId));
    await batch.commit();
  }
}
