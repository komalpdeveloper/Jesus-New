import 'dart:convert';
import 'dart:math';
import 'dart:io' show Platform;
import 'package:clientapp/features/auth/services/user_profile_service.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple abstraction for authentication flows (Google / Apple)
class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final _auth = FirebaseAuth.instance;
  
  // Local storage keys
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserId = 'user_id';
  static const String _keyUserEmail = 'user_email';
  static const String _keyLoginProvider = 'login_provider';
  static const String _keyLastLoginTime = 'last_login_time';

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  
  /// Check if user is logged in (from local storage)
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }
  
  /// Get cached user info from local storage
  Future<Map<String, String?>> getCachedUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'userId': prefs.getString(_keyUserId),
      'email': prefs.getString(_keyUserEmail),
      'provider': prefs.getString(_keyLoginProvider),
      'lastLogin': prefs.getString(_keyLastLoginTime),
    };
  }
  
  /// Save auth state to local storage
  Future<void> _saveAuthState(User user, String provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyUserId, user.uid);
    await prefs.setString(_keyUserEmail, user.email ?? '');
    await prefs.setString(_keyLoginProvider, provider);
    await prefs.setString(_keyLastLoginTime, DateTime.now().toIso8601String());
    debugPrint('[Auth] Saved auth state to local storage (provider=$provider)');
  }
  
  /// Clear auth state from local storage
  Future<void> _clearAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsLoggedIn);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyLoginProvider);
    await prefs.remove(_keyLastLoginTime);
    debugPrint('[Auth] Cleared auth state from local storage');
  }

  static const String iosGoogleClientIdPlaceholder = '757106583943-7jnu5j0gsnecbemnkq8e3eli96uo6vgt.apps.googleusercontent.com';

  Future<UserCredential> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        debugPrint('[Auth] Web Google sign-in start');
        return _auth.signInWithPopup(googleProvider);
      }
      // On iOS we sometimes need to explicitly pass the clientId if multiple are present.
      // (Leave null on Android so default config from google-services.json is used.)
      final resolvedClientId = const String.fromEnvironment('IOS_GOOGLE_CLIENT_ID', defaultValue: '').isNotEmpty
          ? const String.fromEnvironment('IOS_GOOGLE_CLIENT_ID')
          : (iosGoogleClientIdPlaceholder.startsWith('<') ? null : iosGoogleClientIdPlaceholder);
      // Fail fast with a helpful error on iOS if no clientId is provided and GoogleService-Info.plist is likely missing
      if (!kIsWeb && Platform.isIOS && (resolvedClientId == null)) {
        throw Exception('iOS Google Sign-In not configured. Add GoogleService-Info.plist to ios/Runner and URL Scheme (REVERSED_CLIENT_ID) in Xcode, or pass --dart-define=IOS_GOOGLE_CLIENT_ID=YOUR_CLIENT_ID.apps.googleusercontent.com');
      }
      final googleSignIn = GoogleSignIn(clientId: resolvedClientId);
      debugPrint('[Auth] Google sign-in launching (clientId=${googleSignIn.clientId})');
      final account = await googleSignIn.signIn();
      if (account == null) throw Exception('Google sign in aborted');
      final auth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: auth.idToken,
        accessToken: auth.accessToken,
      );
      debugPrint('[Auth] Google credential obtained, proceeding with Firebase credential sign-in');
      final result = await _auth.signInWithCredential(credential);
      
      // Save auth state to local storage
      if (result.user != null) {
        await _saveAuthState(result.user!, 'google');
      }
      
      return result;
    } catch (e) {
      debugPrint('[Auth][Error] Google sign-in failed: $e');
      throw Exception('Google sign-in failed: $e');
    }
  }

  /// Nonce utility for Apple Sign-In per Firebase docs
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<UserCredential> signInWithApple() async {
    try {
      debugPrint('[Auth] Apple sign-in start');
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
      debugPrint('[Auth] Apple ID credential received (has email=${credential.email != null})');

      // Extract display name from Apple credential
      String? displayName;
      if (credential.givenName != null || credential.familyName != null) {
        final parts = [
          credential.givenName,
          credential.familyName,
        ].where((part) => part != null && part.isNotEmpty);
        displayName = parts.join(' ');
        debugPrint('[Auth] Display name from Apple: $displayName');
      }

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: credential.identityToken,
        rawNonce: rawNonce,
        accessToken: credential.authorizationCode,
      );

      final result = await _auth.signInWithCredential(oauthCredential);
      debugPrint('[Auth] Apple Firebase sign-in success (uid=${result.user?.uid})');
      
      // Save auth state to local storage and create user profile
      if (result.user != null) {
        await _saveAuthState(result.user!, 'apple');
        
        // Create user profile if it doesn't exist
        final existingProfile = await UserProfileService.instance.getUserProfile(result.user!.uid);
        if (existingProfile == null) {
          await UserProfileService.instance.createUserProfile(
            result.user!.uid,
            result.user!.email,
            displayName,
          );
          debugPrint('[Auth] Created new user profile with display name: $displayName');
        }
      }
      
      return result;
    } on SignInWithAppleAuthorizationException catch (e) {
      debugPrint('[Auth][Apple][Error] code=${e.code} message=${e.message}');
      switch (e.code) {
        case AuthorizationErrorCode.canceled:
          throw Exception('Apple sign-in cancelled');
        case AuthorizationErrorCode.failed:
          throw Exception('Apple sign-in failed');
        case AuthorizationErrorCode.invalidResponse:
          throw Exception('Invalid response from Apple ID servers');
        case AuthorizationErrorCode.notHandled:
          throw Exception('Apple sign-in not handled');
        case AuthorizationErrorCode.unknown:
        default:
          throw Exception('Unknown Apple sign-in error (${e.message})');
      }
    } catch (e) {
      debugPrint('[Auth][Apple][Error] General failure: $e');
      throw Exception('Apple sign-in failed: $e');
    }
  }

  Future<void> signOut() async {
    try {
      debugPrint('[Auth] Signing out user');
      
      // Clear local storage first
      await _clearAuthState();
      
      // Sign out from Firebase
      await _auth.signOut();
      
      // Sign out from Google if previously used
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      
      debugPrint('[Auth] Sign out complete');
    } catch (e) {
      debugPrint('[Auth][Error] Sign out error: $e');
    }
  }
}
