import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:clientapp/core/auth/auth_service.dart';

/// Widget that manages authentication state and provides auth info to children
class AuthStateManager extends StatefulWidget {
  final Widget Function(BuildContext context, User? user, bool isLoading) builder;

  const AuthStateManager({
    super.key,
    required this.builder,
  });

  @override
  State<AuthStateManager> createState() => _AuthStateManagerState();
}

class _AuthStateManagerState extends State<AuthStateManager> {
  bool _isInitializing = true;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    // Check local storage first
    final isLoggedIn = await AuthService.instance.isLoggedIn();
    final cachedInfo = await AuthService.instance.getCachedUserInfo();
    
    debugPrint('[AuthStateManager] Local storage check: isLoggedIn=$isLoggedIn');
    if (cachedInfo['userId'] != null) {
      debugPrint('[AuthStateManager] Cached user: ${cachedInfo['email']} (${cachedInfo['provider']})');
    }
    
    // Get current Firebase user (will be restored from persistence)
    _currentUser = AuthService.instance.currentUser;
    
    if (_currentUser != null) {
      debugPrint('[AuthStateManager] Firebase user restored: ${_currentUser!.uid}');
    } else {
      debugPrint('[AuthStateManager] No Firebase user found');
    }
    
    setState(() {
      _isInitializing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return widget.builder(context, null, true);
    }

    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges(),
      initialData: _currentUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _currentUser == null) {
          return widget.builder(context, null, true);
        }
        
        final user = snapshot.data;
        
        // Log auth state changes
        if (user != null && _currentUser?.uid != user.uid) {
          debugPrint('[AuthStateManager] User signed in: ${user.uid}');
        } else if (user == null && _currentUser != null) {
          debugPrint('[AuthStateManager] User signed out');
        }
        
        _currentUser = user;
        return widget.builder(context, user, false);
      },
    );
  }
}
