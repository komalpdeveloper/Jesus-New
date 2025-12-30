import 'dart:async';
import 'package:clientapp/core/services/user_service.dart';
import 'package:flutter/foundation.dart';

/// Handles rewards for Church features:
/// - Church Audio (Sermons, Stories, Sacraments): 3,000 Rings every 5 mins.
/// - Music/Songs (Radio): 1,500 Rings every 2.5 mins.
class ChurchRewardService {
  // Singleton instance
  static final ChurchRewardService _instance = ChurchRewardService._internal();
  static ChurchRewardService get instance => _instance;

  ChurchRewardService._internal();

  // Constants
  static const int _audioRewardRings = 3000;
  static const Duration _audioRewardInterval = Duration(minutes: 5);

  static const int _musicRewardRings = 1500;
  static const Duration _musicRewardInterval = Duration(
    minutes: 2,
    seconds: 30,
  );

  // State
  Timer? _audioTimer;
  Timer? _musicTimer;

  int _audioSecondsAccumulated = 0;
  int _musicSecondsAccumulated = 0;

  bool _isTrackingAudio = false;
  bool _isTrackingMusic = false;

  // Stream to notify UI of rewards
  final _rewardStreamController = StreamController<void>.broadcast();
  Stream<void> get onRewardEarned => _rewardStreamController.stream;

  /// Start tracking time for Church Audio (Sermons, Stories, Sacraments)
  void startTrackingAudio() {
    if (_isTrackingAudio) return;
    _isTrackingAudio = true;
    _stopMusicTracking(); // Ensure we don't track both simultaneously if that's the rule, or keep independent.
    // Based on app logic, usually one plays at a time.
    // But to be safe, let's allow independent tracking but usually UI enforces one.

    debugPrint('[ChurchRewardService] Started tracking Audio');
    _audioTimer?.cancel();
    _audioTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _audioSecondsAccumulated++;
      _checkAudioReward();
    });
  }

  /// Stop tracking time for Church Audio
  void stopTrackingAudio() {
    if (!_isTrackingAudio) return;
    _isTrackingAudio = false;
    _audioTimer?.cancel();
    _audioTimer = null;
    debugPrint(
      '[ChurchRewardService] Stopped tracking Audio. Accumulated: $_audioSecondsAccumulated s',
    );
  }

  /// Start tracking time for Music/Songs (Radio)
  void startTrackingMusic() {
    if (_isTrackingMusic) return;
    _isTrackingMusic = true;
    _stopAudioTracking(); // Ensure we don't track both simultaneously

    debugPrint('[ChurchRewardService] Started tracking Music');
    _musicTimer?.cancel();
    _musicTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _musicSecondsAccumulated++;
      _checkMusicReward();
    });
  }

  /// Stop tracking time for Music/Songs
  void stopTrackingMusic() {
    if (!_isTrackingMusic) return;
    _isTrackingMusic = false;
    _musicTimer?.cancel();
    _musicTimer = null;
    debugPrint(
      '[ChurchRewardService] Stopped tracking Music. Accumulated: $_musicSecondsAccumulated s',
    );
  }

  void _stopAudioTracking() {
    if (_isTrackingAudio) stopTrackingAudio();
  }

  void _stopMusicTracking() {
    if (_isTrackingMusic) stopTrackingMusic();
  }

  Future<void> _checkAudioReward() async {
    if (_audioSecondsAccumulated >= _audioRewardInterval.inSeconds) {
      _audioSecondsAccumulated -= _audioRewardInterval.inSeconds;
      await _giveReward(_audioRewardRings, 'Church Audio (5 mins)');
    }
  }

  Future<void> _checkMusicReward() async {
    if (_musicSecondsAccumulated >= _musicRewardInterval.inSeconds) {
      _musicSecondsAccumulated -= _musicRewardInterval.inSeconds;
      await _giveReward(_musicRewardRings, 'Music/Songs (2.5 mins)');
    }
  }

  Future<void> _giveReward(int amount, String reason) async {
    try {
      debugPrint('[ChurchRewardService] Awarding $amount rings for $reason');
      await UserService.instance.incrementRings(amount);
      _rewardStreamController.add(null);
    } catch (e) {
      debugPrint('[ChurchRewardService] Failed to award rings: $e');
    }
  }

  /// Call this when disposing the feature or app
  void dispose() {
    stopTrackingAudio();
    stopTrackingMusic();
    _rewardStreamController.close();
  }
}
