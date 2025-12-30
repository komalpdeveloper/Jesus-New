import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Helper class to migrate existing users to support chat features
class UserChatMigration {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Update current user with chat-required fields
  static Future<void> updateCurrentUserForChat() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = _firestore.collection('users').doc(user.uid);
    final snapshot = await userDoc.get();

    if (!snapshot.exists) {
      // Create user document if it doesn't exist
      await userDoc.set({
        'email': user.email,
        'displayName': user.displayName ?? 'User',
        'photoUrl': user.photoURL,
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'pushToken': null,
        'createdAt': FieldValue.serverTimestamp(),
        'ringCount': 0,
        'boughtItems': [],
      });
    } else {
      // Update existing user with chat fields if missing
      final data = snapshot.data()!;
      final updates = <String, dynamic>{};

      if (!data.containsKey('isOnline')) {
        updates['isOnline'] = true;
      }
      if (!data.containsKey('lastSeen')) {
        updates['lastSeen'] = FieldValue.serverTimestamp();
      }
      if (!data.containsKey('pushToken')) {
        updates['pushToken'] = null;
      }
      if (!data.containsKey('photoUrl') && user.photoURL != null) {
        updates['photoUrl'] = user.photoURL;
      }
      if (!data.containsKey('displayName') && user.displayName != null) {
        updates['displayName'] = user.displayName;
      }

      if (updates.isNotEmpty) {
        await userDoc.update(updates);
      }
    }
  }

  /// Batch update all users in the system (admin only)
  static Future<void> migrateAllUsers() async {
    final usersSnapshot = await _firestore.collection('users').get();
    final batch = _firestore.batch();
    int count = 0;

    for (var doc in usersSnapshot.docs) {
      final data = doc.data();
      final updates = <String, dynamic>{};

      if (!data.containsKey('isOnline')) {
        updates['isOnline'] = false;
      }
      if (!data.containsKey('lastSeen')) {
        updates['lastSeen'] = FieldValue.serverTimestamp();
      }
      if (!data.containsKey('pushToken')) {
        updates['pushToken'] = null;
      }

      if (updates.isNotEmpty) {
        batch.update(doc.reference, updates);
        count++;
      }

      // Firestore batch limit is 500 operations
      if (count >= 500) {
        await batch.commit();
        count = 0;
      }
    }

    if (count > 0) {
      await batch.commit();
    }
  }
}
