import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';

class UserProfileService {
  UserProfileService._();
  static final instance = UserProfileService._();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return UserProfile.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('[UserProfile] Error fetching profile: $e');
      return null;
    }
  }

  Future<void> createUserProfile(
    String uid,
    String? email,
    String? displayName,
  ) async {
    try {
      final now = DateTime.now();
      final profile = UserProfile(
        uid: uid,
        email: email,
        displayName: displayName,
        createdAt: now,
        updatedAt: now,
      );
      await _firestore.collection('users').doc(uid).set(profile.toJson());
      debugPrint(
        '[UserProfile] Created profile for $uid with name: $displayName',
      );
    } catch (e) {
      debugPrint('[UserProfile] Error creating profile: $e');
      rethrow;
    }
  }

  /// Generate a suggested username from display name
  String generateSuggestedUsername(String? displayName) {
    if (displayName == null || displayName.trim().isEmpty) {
      return 'user${_generateRandomSuffix()}';
    }

    // Clean the name: remove spaces, special chars, convert to lowercase
    String cleaned = displayName.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );

    // If cleaned name is too short, use 'user' prefix
    if (cleaned.length < 3) {
      cleaned = 'user';
    }

    // Limit to 9 chars to leave room for 3-digit suffix (total = 12)
    if (cleaned.length > 9) {
      cleaned = cleaned.substring(0, 9);
    }

    return '$cleaned${_generateRandomSuffix()}';
  }

  String _generateRandomSuffix() {
    final random = Random();
    // Generate 3-digit suffix (100-999) to keep total length <= 12
    return (random.nextInt(900) + 100).toString();
  }

  Future<void> updateUsername(String username, {String? displayName}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('No user logged in');

    // Check if username already exists in usernames collection
    final usernameDoc = await _firestore
        .collection('usernames')
        .doc(username)
        .get();
    if (usernameDoc.exists) {
      throw Exception('Username already taken');
    }

    try {
      // Use batch write to ensure atomicity
      final batch = _firestore.batch();

      final updates = <String, dynamic>{
        'username': username,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (displayName != null && displayName.isNotEmpty) {
        updates['displayName'] = displayName;

        // Also update Auth profile
        await _auth.currentUser?.updateDisplayName(displayName);
      }

      // Update user profile
      batch.update(_firestore.collection('users').doc(uid), updates);

      // Create username document linking to user
      batch.set(_firestore.collection('usernames').doc(username), {
        'uid': uid,
        'createdAt': DateTime.now().toIso8601String(),
      });

      await batch.commit();
      debugPrint(
        '[UserProfile] Updated username to $username ${displayName != null ? "and displayName to $displayName" : ""} and created username doc',
      );
    } catch (e) {
      debugPrint('[UserProfile] Error updating username: $e');
      rethrow;
    }
  }

  Future<void> updateGender(String gender) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('No user logged in');

    try {
      await _firestore.collection('users').doc(uid).update({
        'gender': gender,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      debugPrint('[UserProfile] Updated gender to $gender');
    } catch (e) {
      debugPrint('[UserProfile] Error updating gender: $e');
      rethrow;
    }
  }

  /// Check if username is available using the usernames collection
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final doc = await _firestore.collection('usernames').doc(username).get();
      return !doc.exists;
    } catch (e) {
      debugPrint('[UserProfile] Error checking username: $e');
      return false;
    }
  }
}
