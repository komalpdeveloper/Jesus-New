import 'package:clientapp/core/services/user_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles Daily Login Rewards:
/// - Normal Day: 1,000 Rings.
/// - Sunday: 2,000 Rings.
class DailyRewardService {
  // Singleton instance
  static final DailyRewardService _instance = DailyRewardService._internal();
  static DailyRewardService get instance => _instance;

  DailyRewardService._internal();

  // Constants
  static const int _normalDayReward = 1000;
  static const int _sundayReward = 2000;
  static const String _lastLoginKey = 'last_login_reward_date';

  /// Check and award daily login reward if not already claimed today.
  Future<bool> checkDailyReward() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastLoginStr = prefs.getString(_lastLoginKey);
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month}-${now.day}';

      // If already claimed today, skip
      if (lastLoginStr == todayStr) {
        debugPrint(
          '[DailyRewardService] Daily reward already claimed for $todayStr',
        );
        return false;
      }

      // Determine reward amount
      final isSunday = now.weekday == DateTime.sunday;
      final amount = isSunday ? _sundayReward : _normalDayReward;
      final reason = isSunday ? 'Sunday Login Bonus' : 'Daily Login Bonus';

      // Award rings
      debugPrint('[DailyRewardService] Awarding $amount rings for $reason');
      await UserService.instance.incrementRings(amount);

      // Mark as claimed
      await prefs.setString(_lastLoginKey, todayStr);

      return true;
    } catch (e) {
      debugPrint('[DailyRewardService] Failed to process daily reward: $e');
      return false;
    }
  }
}
