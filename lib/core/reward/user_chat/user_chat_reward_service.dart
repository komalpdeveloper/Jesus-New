import 'dart:math';
import 'package:clientapp/core/services/user_service.dart';
import 'package:flutter/foundation.dart';

/// Handles rewards for User Chat features:
/// - Friend Chats: 25–50 Rings per message sent.
class UserChatRewardService {
  // Singleton instance
  static final UserChatRewardService _instance = UserChatRewardService._internal();
  static UserChatRewardService get instance => _instance;

  UserChatRewardService._internal();

  final Random _random = Random();

  // Constants
  static const int _minMessageReward = 25;
  static const int _maxMessageReward = 50;

  /// Award rings for sending a message in User Chat.
  /// Amount is random between 25 and 50.
  Future<void> rewardMessageSent() async {
    final amount = _minMessageReward + _random.nextInt(_maxMessageReward - _minMessageReward + 1);
    await _giveReward(amount, 'Friend Chat Message');
  }

  Future<void> _giveReward(int amount, String reason) async {
    try {
      debugPrint('[UserChatRewardService] Awarding $amount rings for $reason');
      await UserService.instance.incrementRings(amount);
    } catch (e) {
      debugPrint('[UserChatRewardService] Failed to award rings: $e');
    }
  }
}
