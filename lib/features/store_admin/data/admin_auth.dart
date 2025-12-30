import 'package:shared_preferences/shared_preferences.dart';

/// Very simple, temporary admin auth.
/// - Uses an in-memory email/password pair for validation
/// - Persists a boolean flag in SharedPreferences: `admin_logged_in`
/// - NOT secure. Replace with Firebase Auth or a backend later.
class AdminAuth {
  static const _loggedInKey = 'admin_logged_in';
  static const _emailKey = 'admin_email';

  // Temporary credentials – replace with real auth later
  static const String demoEmail = 'admin@demo.com';
  static const String demoPassword = 'admin123';

  AdminAuth._();

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_loggedInKey) ?? false;
  }

  static Future<String?> currentEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  static Future<bool> login(String email, String password) async {
    // naive check
    if (email.trim().toLowerCase() == demoEmail && password == demoPassword) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_loggedInKey, true);
      await prefs.setString(_emailKey, email.trim());
      return true;
    }
    return false;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_loggedInKey);
    await prefs.remove(_emailKey);
  }
}
