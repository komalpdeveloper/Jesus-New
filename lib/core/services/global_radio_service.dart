import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:clientapp/features/church/services/church_radio_service.dart';
import 'package:audio_session/audio_session.dart';

/// Global singleton service for Church Radio that persists across the app
class GlobalRadioService extends ChangeNotifier {
  static final GlobalRadioService _instance = GlobalRadioService._internal();
  factory GlobalRadioService() => _instance;
  GlobalRadioService._internal();

  static GlobalRadioService get instance => _instance;

  AudioPlayer? _player;
  ChurchRadioService? _radioService;
  bool _isInitialized = false;
  bool _isMuted = false;
  double _volumeBeforeMute = 1.0;

  bool get isRadioPlaying => _radioService?.isRadioMode ?? false;
  bool get isMuted => _isMuted;
  bool get isInitialized => _isInitialized;

  /// Initialize the radio service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Configure audio session for background playback
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
      avAudioSessionMode: AVAudioSessionMode.spokenAudio,
      avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: false,
    ));
    
    _player = AudioPlayer();
    _radioService = ChurchRadioService(_player!);
    _isInitialized = true;
    
    // Listen to player state changes
    _player!.playingStream.listen((_) {
      notifyListeners();
    });
    
    notifyListeners();
  }

  /// Start the radio
  Future<void> startRadio() async {
    if (!_isInitialized) await initialize();
    
    try {
      await _radioService!.startRadio();
      notifyListeners();
    } catch (e) {
      debugPrint('Error starting radio: $e');
      rethrow;
    }
  }

  /// Stop the radio
  Future<void> stopRadio() async {
    if (!_isInitialized || _radioService == null) return;
    
    await _radioService!.stopRadio();
    _isMuted = false;
    notifyListeners();
  }

  /// Mute the radio (for chat screens)
  Future<void> mute() async {
    if (!_isInitialized || _player == null || !isRadioPlaying) return;
    
    _volumeBeforeMute = _player!.volume;
    await _player!.setVolume(0.0);
    _isMuted = true;
    notifyListeners();
  }

  /// Unmute the radio
  Future<void> unmute() async {
    if (!_isInitialized || _player == null || !isRadioPlaying) return;
    
    await _player!.setVolume(_volumeBeforeMute);
    _isMuted = false;
    notifyListeners();
  }

  /// Get current radio title
  String getCurrentTitle() {
    if (!isRadioPlaying) return 'Church Radio';
    return _radioService?.getCurrentTitle() ?? 'Church Radio';
  }

  /// Dispose resources
  @override
  void dispose() {
    _radioService?.dispose();
    _player?.dispose();
    super.dispose();
  }
}
