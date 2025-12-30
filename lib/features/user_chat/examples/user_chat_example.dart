import 'package:flutter/material.dart';
import '../user_chat.dart';

/// Example usage of the User Chat feature
class UserChatExample {
  final UserChatService _chatService = UserChatService();

  /// Example 1: Start a chat with a specific user
  Future<void> startChatWithUser(BuildContext context, String userId) async {
    try {
      // Get or create a private chat
      final chatId = await _chatService.getOrCreatePrivateChat(userId);
      
      // Navigate to the chat screen
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserChatScreen(chatId: chatId),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error starting chat: $e');
    }
  }

  /// Example 2: Send a message programmatically
  Future<void> sendQuickMessage(String chatId, String message) async {
    try {
      await _chatService.sendMessage(
        chatId: chatId,
        text: message,
      );
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  /// Example 3: Listen to new messages
  void listenToMessages(String chatId) {
    _chatService.getChatMessages(chatId).listen((messages) {
      debugPrint('Received ${messages.length} messages');
      for (var message in messages) {
        debugPrint('${message.senderId}: ${message.text}');
      }
    });
  }

  /// Example 4: Get user info
  Future<void> getUserInfo(String userId) async {
    final user = await _chatService.getUser(userId);
    if (user != null) {
      debugPrint('User: ${user.displayName}');
      debugPrint('Online: ${user.isOnline}');
      debugPrint('Last seen: ${user.lastSeen}');
    }
  }

  /// Example 5: Search for users
  Future<List<UserChatUser>> searchForUsers(String query) async {
    try {
      final users = await _chatService.searchUsers(query);
      debugPrint('Found ${users.length} users');
      return users;
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }

  /// Example 6: Custom chat list widget
  Widget buildCustomChatList() {
    return StreamBuilder<List<UserChat>>(
      stream: _chatService.getUserChats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final chats = snapshot.data ?? [];
        
        return ListView.builder(
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index];
            return ListTile(
              title: Text(chat.lastMessage ?? 'No messages'),
              subtitle: Text(chat.lastMessageTime?.toString() ?? ''),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserChatScreen(chatId: chat.chatId),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Example 7: Handle presence updates
  Future<void> handlePresence({required bool isOnline}) async {
    await _chatService.updateUserPresence(isOnline: isOnline);
  }

  /// Example 8: Mark messages as read
  Future<void> markChatAsRead(String chatId) async {
    await _chatService.markMessagesAsSeen(chatId);
  }
}

/// Example widget showing how to integrate chat into your app
class ChatIntegrationExample extends StatelessWidget {
  const ChatIntegrationExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat Integration Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserChatListScreen(),
                  ),
                );
              },
              child: const Text('Open Chat List'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserChatSearchScreen(),
                  ),
                );
              },
              child: const Text('Search Users'),
            ),
          ],
        ),
      ),
    );
  }
}
