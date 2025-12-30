import 'package:clientapp/core/services/user_service.dart';
import 'package:clientapp/core/models/chat_models.dart';
import 'package:flutter/foundation.dart';

/// Handles rewards for Chat features:
/// - Divine/Bot Chats (God, Jesus, Word): 50 Rings per message sent.
class ChatRewardService {
  // Singleton instance
  static final ChatRewardService _instance = ChatRewardService._internal();
  static ChatRewardService get instance => _instance;

  ChatRewardService._internal();

  // Constants
  static const int _messageRewardRings = 50;

  /// Award rings for sending a message to a Divine/Bot persona.
  Future<void> rewardMessageSent(BiblicalPersona persona) async {
    // Verify it is one of the divine personas (though currently all are)
    if (persona == BiblicalPersona.jesus || 
        persona == BiblicalPersona.god || 
        persona == BiblicalPersona.livingWord) {
      await _giveReward(_messageRewardRings, 'Message to ${persona.displayName}');
    }
  }

  Future<void> _giveReward(int amount, String reason) async {
    try {
      debugPrint('[ChatRewardService] Awarding $amount rings for $reason');
      await UserService.instance.incrementRings(amount);
    } catch (e) {
      debugPrint('[ChatRewardService] Failed to award rings: $e');
    }
  }
}
