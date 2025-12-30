import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:clientapp/core/models/app_user.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Firestore-backed user service.
class UserService {
  UserService._();
  static final instance = UserService._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  /// Ensure a user document exists for the signed-in user.
  /// If missing, creates with default ringCount=0 and basic profile info.
  Future<void> ensureUserInitialized() async {
    final user = _auth.currentUser;
    if (user == null) return; // nothing to do
    final docRef = _users.doc(user.uid);
    final snap = await docRef.get();
    if (!snap.exists) {
      final appUser = AppUser(
        id: user.uid,
        email: user.email,
        displayName: user.displayName,
        photoUrl: user.photoURL,
        ringCount: 0,
        createdAt: DateTime.now(),
      );
      await docRef.set(appUser.toJson());
      debugPrint('[UserService] Created user document for ${user.uid}');
    } else {
      // Optionally backfill missing fields without overwriting ringCount if present
      final data = snap.data() ?? {};
      final update = <String, dynamic>{};
      if (!data.containsKey('ringCount')) update['ringCount'] = 0;
      if (!data.containsKey('email')) update['email'] = user.email;
      if (!data.containsKey('displayName'))
        update['displayName'] = user.displayName;
      if (!data.containsKey('photoUrl')) update['photoUrl'] = user.photoURL;
      if (update.isNotEmpty) {
        await docRef.set(update, SetOptions(merge: true));
        debugPrint(
          '[UserService] Backfilled user fields for ${user.uid}: ${update.keys.toList()}',
        );
      }
    }
  }

  /// Stream just the ringCount as an int for the current user.
  Stream<int> ringCountStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream<int>.empty();
    return _users.doc(user.uid).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return 0;
      final rc = data['ringCount'];
      return (rc is num) ? rc.toInt() : 0;
    });
  }

  /// Get ringCount once (may be used for non-reactive UI).
  Future<int> getRingCountOnce() async {
    final user = _auth.currentUser;
    if (user == null) return 0;
    final snap = await _users.doc(user.uid).get();
    final data = snap.data();
    final rc = data?['ringCount'];
    return (rc is num) ? rc.toInt() : 0;
  }

  /// Add rings (or subtract if negative). Uses atomic increment.
  Future<void> incrementRings(int delta) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _users.doc(user.uid).update({
      'ringCount': FieldValue.increment(delta),
    });
  }

  /// Process Altar sacrifice: Add rings to progress, handle level up.
  /// Returns true if leveled up.
  Future<bool> processSacrifice(int rings) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final docRef = _users.doc(user.uid);

    return await _db.runTransaction<bool>((tx) async {
      final snap = await tx.get(docRef);
      final data = snap.data() ?? {};

      final currentProgress = (data['altarRings'] as num?)?.toInt() ?? 0;
      final currentLevel = (data['altarLevel'] as num?)?.toInt() ?? 0;

      int newProgress = currentProgress + rings;
      int newLevel = currentLevel;
      bool leveledUp = false;

      // Check for level up (1,110,000 Rings = 1 Level)
      const int ringsPerLevel = 1110000;
      if (newProgress >= ringsPerLevel) {
        final levelsGained = newProgress ~/ ringsPerLevel;
        newLevel += levelsGained;
        newProgress = newProgress % ringsPerLevel;
        leveledUp = true;
      }

      tx.update(docRef, {'altarRings': newProgress, 'altarLevel': newLevel});

      return leveledUp;
    });
  }

  /// Get current user stats including Altar progress.
  Future<AppUser?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final snap = await _users.doc(user.uid).get();
    if (!snap.exists) return null;
    return AppUser.fromDoc(snap);
  }

  /// Spend rings atomically, preventing negative balances.
  /// Returns true if the spend succeeded, or false if insufficient balance.
  Future<bool> spendRings(int amount) async {
    assert(amount >= 0, 'amount must be non-negative');
    final user = _auth.currentUser;
    if (user == null) return false;

    final docRef = _users.doc(user.uid);
    return _db.runTransaction<bool>((tx) async {
      final snap = await tx.get(docRef);
      final data = snap.data();
      final current = (data?['ringCount'] is num)
          ? (data!['ringCount'] as num).toInt()
          : 0;
      if (current < amount) {
        return false;
      }
      final newValue = current - amount;
      tx.update(docRef, {'ringCount': newValue});
      return true;
    });
  }

  /// Update user profile data (displayName, photoUrl).
  Future<void> updateProfile({String? displayName, String? photoUrl}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final updates = <String, dynamic>{};
    if (displayName != null) updates['displayName'] = displayName;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;

    if (updates.isNotEmpty) {
      await _users.doc(user.uid).update(updates);
      // Also update Firebase Auth profile for consistency
      if (displayName != null) await user.updateDisplayName(displayName);
      if (photoUrl != null) await user.updatePhotoURL(photoUrl);
    }
  }

  /// Upload profile image to Firebase Storage and return the URL.
  Future<String?> uploadProfileImage(File file) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final ref = FirebaseStorage.instance.ref().child(
        'user_profiles/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      // Upload task
      final task = await ref.putFile(file);

      // Get URL
      final url = await task.ref.getDownloadURL();
      return url;
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      return null;
    }
  }
}
