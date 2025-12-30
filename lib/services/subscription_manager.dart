import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ChatAccessStatus { allowed, freeLimitReached, proLimitReached }

class SubscriptionManager {
  static const String _entitlementId = 'premium_access';
  static const String _freeMessageCountKey = 'free_message_count';
  static const int _freeMessageLimit = 5;
  static const String _lifetimePremiumKey = 'lifetime_premium_active';

  // Pro limits
  static const String _proMessageCountKey = 'pro_message_count';
  static const String _proLastResetDateKey = 'pro_last_reset_date';
  static const String _topUpBalanceKey = 'pro_top_up_balance';
  static const int _proMonthlyLimit = 500;

  /// Checks if the user has an active premium entitlement.
  /// Also checks for lifetime premium activated via promo code.
  static Future<bool> isPremium() async {
    // First check for lifetime premium via promo code
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_lifetimePremiumKey) == true) {
      return true;
    }

    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all[_entitlementId]?.isActive ?? false;
    } catch (e) {
      // In case of error, assume false or handle loosely
      return false;
    }
  }

  /// Activates lifetime premium access via promo code.
  static Future<void> activateLifetimePremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lifetimePremiumKey, true);
  }

  /// Checks if lifetime premium is active (for display purposes).
  static Future<bool> isLifetimePremium() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_lifetimePremiumKey) == true;
  }

  /// Adds extra messages properly purchased via TopUp
  static Future<void> addTopUp(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    int currentBalance = prefs.getInt(_topUpBalanceKey) ?? 0;
    await prefs.setInt(_topUpBalanceKey, currentBalance + amount);
  }

  /// Determines if the user is allowed to send a message.
  /// Returns ChatAccessStatus to indicate if allowed or why not.
  /// Increments the usage counter if allowed.
  static Future<ChatAccessStatus> canChat() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Check Premium
    bool premium = await isPremium();
    if (premium) {
      // Pro Limit Logic
      final now = DateTime.now();
      final lastResetStr = prefs.getString(_proLastResetDateKey);
      DateTime? lastReset;
      if (lastResetStr != null) {
        lastReset = DateTime.tryParse(lastResetStr);
      }

      // Check if we need to reset monthly limit
      if (lastReset == null ||
          lastReset.month != now.month ||
          lastReset.year != now.year) {
        // Reset for new month
        await prefs.setInt(_proMessageCountKey, 0);
        await prefs.setString(_proLastResetDateKey, now.toIso8601String());
      }

      int used = prefs.getInt(_proMessageCountKey) ?? 0;
      int topUpBalance = prefs.getInt(_topUpBalanceKey) ?? 0;

      if (used < _proMonthlyLimit) {
        // Still within monthly limit
        await prefs.setInt(_proMessageCountKey, used + 1);
        return ChatAccessStatus.allowed;
      } else if (topUpBalance > 0) {
        // Use top up balance
        await prefs.setInt(_topUpBalanceKey, topUpBalance - 1);
        return ChatAccessStatus.allowed;
      } else {
        // Both monthly and top up limits reached
        return ChatAccessStatus.proLimitReached;
      }
    }

    // 2. Check Free Count
    int count = prefs.getInt(_freeMessageCountKey) ?? 0;

    if (count < _freeMessageLimit) {
      // Increment and allow
      await prefs.setInt(_freeMessageCountKey, count + 1);
      return ChatAccessStatus.allowed;
    } else {
      // Limit reached
      return ChatAccessStatus.freeLimitReached;
    }
  }
}
