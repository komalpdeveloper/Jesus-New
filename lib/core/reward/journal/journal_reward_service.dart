import 'dart:math';
import 'package:clientapp/core/services/user_service.dart';
import 'package:flutter/foundation.dart';

/// Handles rewards for Journal, Notes, and Chat saving features:
/// - Highlights/Notes/Journal Entries: 150–200 Rings.
/// - Saving a Chat: 200 Rings.
class JournalRewardService {
  // Singleton instance
  static final JournalRewardService _instance = JournalRewardService._internal();
  static JournalRewardService get instance => _instance;

  JournalRewardService._internal();

  final Random _random = Random();

  // Constants
  static const int _minEntryReward = 150;
  static const int _maxEntryReward = 200;
  static const int _chatSaveReward = 200;

  /// Award rings for saving a Journal Entry, Note, or Highlight.
  /// Amount is random between 150 and 200.
  Future<void> rewardEntrySaved() async {
    final amount = _minEntryReward + _random.nextInt(_maxEntryReward - _minEntryReward + 1);
    await _giveReward(amount, 'Journal/Note Entry Saved');
  }

  /// Award rings for saving a Chat conversation.
  /// Amount is fixed at 200.
  Future<void> rewardChatSaved() async {
    await _giveReward(_chatSaveReward, 'Chat Conversation Saved');
  }

  Future<void> _giveReward(int amount, String reason) async {
    try {
      debugPrint('[JournalRewardService] Awarding $amount rings for $reason');
      await UserService.instance.incrementRings(amount);
    } catch (e) {
      debugPrint('[JournalRewardService] Failed to award rings: $e');
    }
  }
}
