import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage chat message persistence
/// Messages are stored during app session and cleared when app closes
class ChatPersistenceService {
  static const List<String> _chatEndpoints = [
    '/chat/jesus',
    '/chat/word',
    '/chat/god',
  ];

  /// Clear all chat messages from local storage
  static Future<void> clearAllChatMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final endpoint in _chatEndpoints) {
        final key = 'chat_messages_$endpoint';
        await prefs.remove(key);
      }
    } catch (e) {
      // Silently fail - this is cleanup code
    }
  }
}
