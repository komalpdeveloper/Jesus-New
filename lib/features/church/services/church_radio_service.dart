import 'dart:async';
import 'dart:math';
import 'package:just_audio/just_audio.dart';
import 'package:clientapp/features/church/data/church_repository_user.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:clientapp/core/reward/church/church_reward_service.dart';

/// Service to manage Church Radio feature:
/// 
/// Radio Rotation Logic (~708 songs):
/// - All songs are randomized into a shuffled playlist
/// - Plays through the entire playlist with NO repeats
/// - When all songs have been played, re-randomize and start again
/// 
/// Additional features:
/// - Starts with 1 local snippet
/// - After every 3 Firebase songs, plays 1 local snippet
/// - Caches for speed
class ChurchRadioService {
  final AudioPlayer _player;
  final ChurchUserRepository _repository;
  final Random _random = Random();

  // Firebase audio URLs (tracks)
  List<String> _firebaseAudios = [];
  
  // Firebase snippet URLs (play at start and after every 3 songs)
  List<String> _firebaseSnippets = [];

  // Shuffled playlist (no repeats until all played)
  List<String> _shuffledPlaylist = [];
  int _currentIndex = 0;

  // Counter for local snippets
  int _songsPlayedCount = 0;

  bool _isRadioMode = false;
  bool _isPlayingLocalSnippet = false;
  bool _isProcessingNext = false; // Prevent double-triggering
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _playingSubscription;

  ChurchRadioService(this._player, {ChurchUserRepository? repository})
    : _repository = repository ?? ChurchUserRepository() {
      // Listen to playing state to track rewards
      _playingSubscription = _player.playingStream.listen((playing) {
        if (_isRadioMode && playing) {
          ChurchRewardService.instance.startTrackingMusic();
        } else {
          ChurchRewardService.instance.stopTrackingMusic();
        }
      });
    }

  bool get isRadioMode => _isRadioMode;

  /// Initialize and start radio mode
  Future<void> startRadio() async {
    if (_isRadioMode) {
      print('Radio already in mode, skipping');
      return;
    }

    print('Starting Church Radio...');
    _isRadioMode = true;
    _songsPlayedCount = 0;
    _currentIndex = 0;
    _isProcessingNext = false;

    // Fetch radio tracks and snippets from Firebase
    try {
      print('Fetching radio content from Firebase...');
      final tracks = await _repository.listRadioTracks();
      final snippets = await _repository.listRadioSnippets();

      if (tracks.isEmpty) {
        print('No tracks in Firebase, cannot start radio');
        _isRadioMode = false;
        throw Exception('No radio tracks available');
      }

      if (snippets.isEmpty) {
        print('No snippets in Firebase, cannot start radio');
        _isRadioMode = false;
        throw Exception('No radio snippets available');
      }

      _firebaseAudios = tracks.map((s) => s.audioUrl).toList();
      _firebaseSnippets = snippets.map((s) => s.audioUrl).toList();
      
      print('Loaded ${_firebaseAudios.length} tracks and ${_firebaseSnippets.length} snippets from Firebase');

      // Create shuffled playlist
      _shufflePlaylist();
    } catch (e) {
      print('Error fetching content from Firebase: $e');
      _isRadioMode = false;
      rethrow;
    }

    // Listen to player completion - use playerStateCompleted stream
    _playerStateSubscription?.cancel();
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      print('🎵 Player state: ${state.processingState} | playing: ${state.playing} | radioMode: $_isRadioMode | processing: $_isProcessingNext');
      
      // When track completes, play next
      if (state.processingState == ProcessingState.completed && _isRadioMode) {
        print('✓✓✓ Track COMPLETED - Auto-playing next track');
        if (!_isProcessingNext) {
          _playNext().catchError((e) {
            print('❌ Error in auto-play next: $e');
            _isProcessingNext = false;
          });
        } else {
          print('⚠️ Already processing next, skipping');
        }
      }
    });

    // Start with a local snippet first
    print('🎬 Starting with local snippet...');
    await _playLocalSnippet();
    print('✅ Church Radio started successfully!');
  }

  /// Shuffle the playlist (no repeats until all played)
  /// This implements the radio rotation: randomize all ~708 songs,
  /// play through the entire list, then re-randomize when complete.
  void _shufflePlaylist() {
    _shuffledPlaylist = List.from(_firebaseAudios);
    _shuffledPlaylist.shuffle(_random);
    _currentIndex = 0;
    print('🔀 Playlist shuffled: ${_shuffledPlaylist.length} songs ready to play (no repeats until all played)');
  }

  /// Play next audio (Firebase or local snippet)
  Future<void> _playNext() async {
    if (!_isRadioMode) {
      print('⚠️ Not in radio mode, skipping playNext');
      return;
    }
    
    if (_isProcessingNext) {
      print('⚠️ Already processing next track, skipping');
      return;
    }

    print('▶️ _playNext called (songs played: $_songsPlayedCount, isLocalSnippet: $_isPlayingLocalSnippet)');
    _isProcessingNext = true;

    try {
      // Check if we should play a local snippet
      if (_songsPlayedCount >= 3 && !_isPlayingLocalSnippet) {
        print('🔄 Time for local snippet (played $_songsPlayedCount songs)');
        await _playLocalSnippet();
      } else {
        // Play next Firebase audio
        print('🎵 Playing next Firebase track');
        await _playFirebaseAudio();
      }
    } catch (e) {
      print('❌ Error in _playNext: $e');
    } finally {
      _isProcessingNext = false;
      print('✓ _playNext completed, flag reset');
    }
  }

  /// Play a Firebase audio
  Future<void> _playFirebaseAudio() async {
    if (_shuffledPlaylist.isEmpty) {
      print('❌ Playlist is empty!');
      return;
    }

    _isPlayingLocalSnippet = false;

    // Check if we need to reshuffle (all songs have been played)
    if (_currentIndex >= _shuffledPlaylist.length) {
      print('🔄 All ${_shuffledPlaylist.length} songs played! Reshuffling for new rotation...');
      _shufflePlaylist();
    }

    try {
      final audioUrl = _shuffledPlaylist[_currentIndex];
      print('🎵 Playing track ${_currentIndex + 1} of ${_shuffledPlaylist.length} (${_shuffledPlaylist.length - _currentIndex - 1} remaining in rotation)');
      print('   URL: $audioUrl');

      // Increment counters FIRST
      _currentIndex++;
      _songsPlayedCount++;

      // Set the new URL and play
      final audioSource = AudioSource.uri(
        Uri.parse(audioUrl),
        tag: MediaItem(
          id: audioUrl,
          album: "Church Radio",
          title: "Uplifting Christian Music",
          artist: "Live from the Church",
          // Set duration to null to simulate live stream (hides seek bar on some platforms)
          duration: null, 
        ),
      );
      await _player.setAudioSource(audioSource);
      await _player.play();

      print('✅ Firebase track loaded & playing (songs played: $_songsPlayedCount)');
    } catch (e) {
      print('❌ Error playing Firebase audio: $e');
      // Skip this track and try next one
      await Future.delayed(const Duration(milliseconds: 800));
      if (_isRadioMode) {
        _isProcessingNext = false;
        await _playNext();
      }
    }
  }

  /// Play a random snippet from Firestore
  Future<void> _playLocalSnippet() async {
    if (_firebaseSnippets.isEmpty) {
      print('❌ No snippets available!');
      return;
    }

    _isPlayingLocalSnippet = true;
    _songsPlayedCount = 0; // Reset counter

    try {
      final snippetUrl = _firebaseSnippets[_random.nextInt(_firebaseSnippets.length)];
      print('📻 Playing random snippet from Firestore: $snippetUrl');

      // Set the snippet URL and play
      final audioSource = AudioSource.uri(
        Uri.parse(snippetUrl),
        tag: MediaItem(
          id: snippetUrl,
          album: "Church Radio",
          title: "A Message from the Church",
          artist: "Church Radio",
          // Set duration to null to simulate live stream
          duration: null,
        ),
      );
      await _player.setAudioSource(audioSource);
      await _player.play();

      print('✅ Snippet loaded & playing');
    } catch (e) {
      print('❌ Error playing snippet: $e');
      _isPlayingLocalSnippet = false;
      // Skip this snippet and try next track
      await Future.delayed(const Duration(milliseconds: 800));
      if (_isRadioMode) {
        _isProcessingNext = false;
        await _playNext();
      }
    }
  }

  /// Stop radio mode
  Future<void> stopRadio() async {
    print('Stopping radio...');
    _isRadioMode = false;
    _isPlayingLocalSnippet = false;
    _isProcessingNext = false;
    ChurchRewardService.instance.stopTrackingMusic();
    await _playerStateSubscription?.cancel();
    _playerStateSubscription = null;
    await _player.stop();
    print('Radio stopped');
  }

  /// Skip to next
  Future<void> skipNext() async {
    if (!_isRadioMode || _isProcessingNext) return;
    print('Skipping to next...');
    await _playNext();
  }

  /// Skip to previous (just play next in this implementation)
  Future<void> skipPrevious() async {
    if (!_isRadioMode || _isProcessingNext) return;
    print('Playing next...');
    await _playNext();
  }

  /// Get current playing title
  String getCurrentTitle() {
    if (_isPlayingLocalSnippet) {
      return 'Church Radio - Station Message';
    }
    return 'Church Radio - Uplifting Christian Music';
  }
  void dispose() {
    _playerStateSubscription?.cancel();
    _playingSubscription?.cancel();
    ChurchRewardService.instance.stopTrackingMusic();
  }
}
