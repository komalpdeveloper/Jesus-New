import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:clientapp/core/theme/palette.dart';
import 'package:clientapp/shared/widgets/cosmic_background.dart';
import 'package:clientapp/shared/widgets/royal_ring.dart';
import 'package:clientapp/features/notes/presentation/notes_list_screen.dart';
import 'package:clientapp/features/notes/models/note.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:clientapp/core/services/user_service.dart';

const Duration kInhaleDuration = Duration(seconds: 4);
const Duration kExhaleDuration = Duration(seconds: 4);

class PrayerMode extends StatefulWidget {
  const PrayerMode({super.key});
  @override
  State<PrayerMode> createState() => _PrayerModeState();
}

enum PrayerModeType { regular, fire, golden }

class _PrayerModeState extends State<PrayerMode> with TickerProviderStateMixin {
  late _Verse verse;

  // User adjustable  // Mode state
  PrayerModeType _mode = PrayerModeType.regular;

  // Settings
  int breathsPerSet = 4;
  // inhale+exhale pairs before hold+pray
  int holdSeconds = 5;
  int praySeconds = 15;

  // Phase state
  _Phase phase = _Phase.idle;
  int breathsDoneInCurrentSet = 0;
  // Generation counter to control restarting of async breathing loop
  int _sequenceGeneration = 0;

  // Animations
  late final AnimationController breatheCtrl; // inhale/exhale scaling
  late final AnimationController auraCtrl; // gentle aura pulse
  late final AnimationController prayCtrl; // subtle rotation/glow during prayer
  late final AnimationController expandCtrl; // for expanding controls panel
  late final AnimationController
  glitterCtrl; // golden glitter drift/flicker during Firebreath
  bool running = false;
  bool controlsExpanded = false;
  // Audio & voice settings
  late final AudioPlayer
  _bgPlayer; // background music with just_audio_background support
  late final ap.AudioPlayer _voicePlayer; // voice cues using audioplayers
  bool _musicOn = true; // background music toggle
  bool _voiceOn = true; // voice guidance toggle
  bool _firebreathEnabled =
      false; // FireBreath master toggle (temporarily disabled)
  _VoiceGender _gender = _VoiceGender.female;
  bool _settingsDirty = false;

  // Persisted prayer settings keys & dirty flag (restored)
  static const String _prefsKeyBreaths = 'prayer_breaths_per_set';
  static const String _prefsKeyHold = 'prayer_hold_seconds';
  static const String _prefsKeyPray = 'prayer_pray_seconds';

  // Regular session timer state (restored)
  DateTime? _sessionStart;
  Timer? _sessionTicker;
  Duration get _sessionElapsed => _sessionStart == null
      ? Duration.zero
      : DateTime.now().difference(_sessionStart!);

  // --- Firebreath feature state -------------------------------------------
  // Cycle: 15 min normal (countdown) -> 5 min Firebreath active -> repeat.
  // Pausing/stopping session resets the cycle.
  // TESTING: shortened countdown to 40s (was 15 min). Active window remains 5 min.
  static const Duration _firebreathCountdown = Duration(seconds: 900);
  static const Duration _firebreathActiveWindow = Duration(
    seconds: 300,
  ); // TESTING: was 5 minutes
  DateTime?
  _cycleStart; // when current 15+5 cycle began (or null if not running)
  DateTime? _firebreathStarted; // when active window began
  Timer? _firebreathTicker;
  // New precise timers to eliminate delay at activation/end boundaries
  Timer? _firebreathActivationTimer; // fires exactly when countdown elapses
  Timer? _firebreathEndTimer; // fires exactly when active window ends

  bool get _firebreathActive => _firebreathStarted != null;

  Duration get _firebreathCountdownRemaining {
    if (_firebreathActive || _cycleStart == null) return Duration.zero;
    final now = DateTime.now();
    final elapsed = now.difference(_cycleStart!);
    if (elapsed >= _firebreathCountdown) return Duration.zero;
    return _firebreathCountdown - elapsed;
  }

  Duration get _firebreathActiveRemaining {
    if (!_firebreathActive) return Duration.zero;
    final now = DateTime.now();
    final elapsed = now.difference(_firebreathStarted!);
    if (elapsed >= _firebreathActiveWindow) return Duration.zero;
    return _firebreathActiveWindow - elapsed;
  }

  void _startFirebreathCycle() {
    // Reset any existing timers
    _firebreathTicker?.cancel();
    _firebreathActivationTimer?.cancel();
    _firebreathEndTimer?.cancel();

    _cycleStart = DateTime.now();
    _firebreathStarted = null;

    // UI ticker for countdown display (higher frequency for snappier UI)
    _firebreathTicker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });

    // Schedule precise activation
    _firebreathActivationTimer = Timer(_firebreathCountdown, () {
      if (!mounted || !running || !_firebreathEnabled) return;
      // Assign and repaint immediately so background switches with zero delay.
      setState(() {
        _firebreathStarted = DateTime.now();
      });
      // Play activation first; restart prayer AFTER the "FireBreath" cue finishes.
      _onFirebreathActivated(restartAfterCue: true);

      // Schedule end of active window precisely
      _firebreathEndTimer = Timer(_firebreathActiveWindow, () {
        if (!mounted || !running || !_firebreathEnabled) return;
        setState(() {
          _firebreathStarted = null;
          _cycleStart = DateTime.now();
        });
        _onFirebreathEnded();
        // Automatically start next cycle
        _startFirebreathCycle();
      });
    });
  }

  void _stopFirebreathCycle() {
    _firebreathTicker?.cancel();
    _firebreathTicker = null;
    _firebreathActivationTimer?.cancel();
    _firebreathActivationTimer = null;
    _firebreathEndTimer?.cancel();
    _firebreathEndTimer = null;
    _cycleStart = null;
    _firebreathStarted = null;
    _onFirebreathEnded(); // revert bg if needed
  }

  Future<void> _playBg(String asset, {bool loop = true}) async {
    if (!_musicOn) return; // music disabled
    try {
      await _bgPlayer.setAudioSource(
        AudioSource.asset(
          asset,
          tag: MediaItem(
            id: asset,
            title: 'Prayer Background',
            album: 'Prayer Mode',
          ),
        ),
      );
      await _bgPlayer.setLoopMode(loop ? LoopMode.one : LoopMode.off);
      await _bgPlayer.play();
    } catch (e) {
      if (kDebugMode) debugPrint('BG audio error: $e');
    }
  }

  Future<void> _stopBg() async {
    try {
      await _bgPlayer.stop();
    } catch (_) {}
  }

  Future<void> _onFirebreathActivated({bool restartAfterCue = false}) async {
    // Play activation cue using audioplayers
    try {
      final fbGender = _gender == _VoiceGender.male ? 'male' : 'female';
      final asset = 'sounds/meditation/fire_breath_${fbGender}.mp3';

      await _voicePlayer.play(ap.AssetSource(asset));

      if (restartAfterCue && running) {
        // Wait for completion, then restart sequence and play background
        _voicePlayer.onPlayerComplete.listen((_) {
          // Restart the breathing/prayer sequence
          _sequenceGeneration++;
          breathsDoneInCurrentSet = 0;
          phase = _Phase.inhale;
          try {
            breatheCtrl.stop();
          } catch (_) {}
          try {
            prayCtrl.stop();
          } catch (_) {}
          if (running) {
            _runSequence();
            // Start firebreath background music
            if (_musicOn)
              _playBg('assets/sounds/meditation/fire_breath_bg.mp3');
          }
        });
      } else {
        // Just switch to firebreath background after cue
        _voicePlayer.onPlayerComplete.listen((_) {
          if (_musicOn) _playBg('assets/sounds/meditation/fire_breath_bg.mp3');
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Activation SFX error: $e');
    }
  }

  Future<void> _onFirebreathEnded() async {
    if (!running) {
      // session stopped; stop bg entirely
      await _stopBg();
      return;
    }
    // Session still running; go back to normal bg
    if (_musicOn) {
      await _playBg('assets/sounds/meditation/normal_bg.mp3');
    }
    // Trigger Flame Reward for completing a Fire Breath/Golden cycle
    if (mounted) {
      RoyalRing.show(
        context,
        glowColor: Colors.purpleAccent,
        size: 80,
        behavior: RoyalRingBehavior.meditation,
      );
    }
  }

  // Intro dialog dismissal keys (new + legacy for migration)
  static const String _prefsKeyIntroDismissed = 'prayer_intro_dismissed_v2';
  static const String _legacyPrefsKeyIntroDismissed = 'isVisitedPrayerMode';
  static const String _prefsKeyMusicOn = 'prayer_music_on';
  static const String _prefsKeyVoiceOn = 'prayer_voice_on';
  static const String _prefsKeyFirebreathEnabled = 'prayer_firebreath_enabled';
  static const String _prefsKeyVoiceGender = 'voiceGender'; // 'male' | 'female'

  @override
  void initState() {
    super.initState();
    verse = _VerseRotation.next(_mode);
    breatheCtrl = AnimationController(vsync: this, duration: kInhaleDuration);
    auraCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    prayCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    glitterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
    // Show tutorial dialog first time user visits this screen
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTutorial());

    _initAudioSession();

    _bgPlayer = AudioPlayer(); // This one uses just_audio_background
    _voicePlayer = ap.AudioPlayer(); // This one uses audioplayers

    // Configure audioplayers to mix with others
    ap.AudioPlayer.global.setAudioContext(
      ap.AudioContext(
        iOS: ap.AudioContextIOS(
          category: ap.AVAudioSessionCategory.playback,
          options: {ap.AVAudioSessionOptions.mixWithOthers},
        ),
        android: ap.AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: ap.AndroidContentType.music,
          usageType: ap.AndroidUsageType.media,
          audioFocus: ap.AndroidAudioFocus.none,
        ),
      ),
    );
    _loadVoicePrefs();
    _loadPrayerSettingsPrefs();
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ),
    );
  }

  @override
  void dispose() {
    breatheCtrl.dispose();
    auraCtrl.dispose();
    prayCtrl.dispose();
    expandCtrl.dispose();
    glitterCtrl.dispose();
    _bgPlayer.dispose();
    _voicePlayer.dispose();
    _firebreathTicker?.cancel();
    super.dispose();
  }

  Future<void> _maybeShowTutorial() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Migration: if legacy key was set, copy to new key.
      final legacy = prefs.getBool(_legacyPrefsKeyIntroDismissed) ?? false;
      final dismissed = prefs.getBool(_prefsKeyIntroDismissed) ?? legacy;
      if (legacy && !(prefs.containsKey(_prefsKeyIntroDismissed))) {
        await prefs.setBool(_prefsKeyIntroDismissed, true);
      }
      if (dismissed || !mounted) return;

      // Local dialog-scoped state (persist across StatefulBuilder rebuilds)
      bool dontShowAgain = false;

      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Dialog(
                backgroundColor: kRoyalBlue.withValues(alpha: 0.82),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: kRoyalBlue, width: 1),
                ),
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                child: StatefulBuilder(
                  builder: (dCtx, setDState) {
                    void apply({
                      bool? music,
                      bool? voice,
                      _VoiceGender? gender,
                      bool? firebreath,
                      bool? skip,
                    }) {
                      if (skip != null) dontShowAgain = skip;
                      final changed =
                          music != null ||
                          voice != null ||
                          gender != null ||
                          firebreath != null;
                      if (changed) {
                        setState(() {
                          if (music != null) _musicOn = music;
                          if (voice != null) _voiceOn = voice;
                          if (gender != null) _gender = gender;
                          if (firebreath != null) {
                            _firebreathEnabled = firebreath;
                            if (running) {
                              if (_firebreathEnabled) {
                                _startFirebreathCycle();
                              } else {
                                _stopFirebreathCycle();
                              }
                            }
                          }
                        });
                        _saveVoicePrefs();
                        // Adjust background music immediately if music state or firebreath state changed while running.
                        if (!_musicOn) {
                          _stopBg();
                        } else if (running) {
                          _firebreathActive
                              ? _playBg(
                                  'assets/sounds/meditation/fire_breath_bg.mp3',
                                )
                              : _playBg(
                                  'assets/sounds/meditation/normal_bg.mp3',
                                );
                        }
                      }
                      setDState(() {}); // rebuild dialog UI
                    }

                    return Container(
                      padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xAA0F1520), Color(0xAA101826)],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.self_improvement_rounded,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Prayer Mode Intro',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => Navigator.of(ctx).maybePop(),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Divider(color: Colors.white10, height: 1),
                          const SizedBox(height: 18),
                          const _TutorialSteps(shorter: true),
                          const SizedBox(height: 18),
                          _AudioSettingsInline(
                            musicOn: _musicOn,
                            voiceOn: _voiceOn,
                            firebreathEnabled: _firebreathEnabled,
                            gender: _gender,
                            onMusicChanged: (v) => apply(music: v),
                            onVoiceChanged: (v) => apply(voice: v),
                            onGenderChanged: (g) => apply(gender: g),
                            onFirebreathChanged: (v) => apply(firebreath: v),
                            centered: true,
                            firebreathSecondRow: true,
                          ),
                          const SizedBox(height: 14),
                          // Don't show again checkbox
                          InkWell(
                            onTap: () => apply(skip: !dontShowAgain),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                  value: dontShowAgain,
                                  onChanged: (v) => apply(skip: v ?? false),
                                  activeColor: kPurple,
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  "Don't show this again",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Center(
                            child: Text(
                              'You can change these settings later.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.favorite_border_rounded),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPurple,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 18,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                                elevation: 0,
                              ),
                              onPressed: () async {
                                if (dontShowAgain) {
                                  await prefs.setBool(
                                    _prefsKeyIntroDismissed,
                                    true,
                                  );
                                } else {
                                  await prefs.remove(
                                    _prefsKeyIntroDismissed,
                                  ); // ensure will show next time
                                }
                                if (mounted) Navigator.of(ctx).pop();
                              },
                              label: const Text('Begin'),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      // Non-critical: ignore errors
    }
  }

  // Removed legacy voice settings dialog – integrated into settings panel.

  Future<void> _runSequence() async {
    final int gen = ++_sequenceGeneration; // new generation
    setState(() {
      running = true;
      phase = _Phase.inhale;
      breathsDoneInCurrentSet = 0;
    });

    while (mounted && running && gen == _sequenceGeneration) {
      // Breath set: inhale+exhale pairs
      while (mounted &&
          running &&
          gen == _sequenceGeneration &&
          breathsDoneInCurrentSet < breathsPerSet) {
        await _doInhale();
        if (!mounted || !running || gen != _sequenceGeneration) return;
        await _doExhale();
        breathsDoneInCurrentSet++;
      }
      if (!mounted || !running || gen != _sequenceGeneration) return;

      await _doHold(holdSeconds);
      if (!mounted || !running || gen != _sequenceGeneration) return;

      await _doPray(praySeconds);
      if (!mounted || !running || gen != _sequenceGeneration) return;

      breathsDoneInCurrentSet = 0;
    }
  }

  Future<void> _doInhale() async {
    setState(() => phase = _Phase.inhale);
    breatheCtrl.duration = kInhaleDuration;
    _playPhaseSound(_Phase.inhale);
    // Don't await the animation controller as it pauses in background (no vsync).
    // Instead, fire the animation and await a real timer.
    try {
      breatheCtrl.forward(from: 0);
    } catch (_) {}
    await Future.delayed(kInhaleDuration);
  }

  Future<void> _doExhale() async {
    setState(() => phase = _Phase.exhale);
    breatheCtrl.duration = kExhaleDuration;
    _playPhaseSound(_Phase.exhale);
    // Don't await the animation controller as it pauses in background.
    try {
      breatheCtrl.reverse(from: 1);
    } catch (_) {}
    await Future.delayed(kExhaleDuration);
  }

  Future<void> _doHold(int seconds) async {
    setState(() => phase = _Phase.hold);
    _playPhaseSound(_Phase.hold);
    await Future.delayed(Duration(seconds: math.max(0, seconds)));
  }

  Future<void> _doPray(int seconds) async {
    setState(() => phase = _Phase.pray);
    prayCtrl
      ..reset()
      ..repeat(period: const Duration(seconds: 10));
    _playPhaseSound(_Phase.pray);
    await Future.delayed(Duration(seconds: math.max(1, seconds)));
    prayCtrl.stop();
  }

  Future<void> _loadVoicePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _musicOn = prefs.getBool(_prefsKeyMusicOn) ?? true;
      _voiceOn = prefs.getBool(_prefsKeyVoiceOn) ?? true;
      // Temporarily disable FireBreath regardless of saved preference
      _firebreathEnabled = false;
      final rawGender = prefs.getString(_prefsKeyVoiceGender);
      if (rawGender == 'male')
        _gender = _VoiceGender.male;
      else
        _gender = _VoiceGender.female;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _saveVoicePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyMusicOn, _musicOn);
      await prefs.setBool(_prefsKeyVoiceOn, _voiceOn);
      await prefs.setBool(_prefsKeyFirebreathEnabled, _firebreathEnabled);
      await prefs.setString(_prefsKeyVoiceGender, _gender.name);
    } catch (_) {}
  }

  Future<void> _loadPrayerSettingsPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      breathsPerSet = prefs.getInt(_prefsKeyBreaths) ?? breathsPerSet;
      holdSeconds = prefs.getInt(_prefsKeyHold) ?? holdSeconds;
      praySeconds = prefs.getInt(_prefsKeyPray) ?? praySeconds;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _savePrayerSettingsPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKeyBreaths, breathsPerSet);
      await prefs.setInt(_prefsKeyHold, holdSeconds);
      await prefs.setInt(_prefsKeyPray, praySeconds);
      if (mounted) {
        setState(() => _settingsDirty = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prayer settings saved for next time.')),
        );
      }
    } catch (_) {}
  }

  Future<void> _playPhaseSound(_Phase phase) async {
    if (!_voiceOn) return; // voice disabled
    String? asset;
    final g = _gender == _VoiceGender.male ? 'male' : 'female';
    switch (phase) {
      case _Phase.inhale:
        asset = 'sounds/meditation/breathin_${g}.mp3';
        break;
      case _Phase.exhale:
        asset = 'sounds/meditation/breathout_${g}.mp3';
        break;
      case _Phase.hold:
        asset = _gender == _VoiceGender.male
            ? 'sounds/meditation/hold_male.mp3'
            : 'sounds/meditation/hold_female.mp3';
        break;
      case _Phase.pray:
        asset = 'sounds/meditation/breathandpray_${g}.mp3';
        break;
      case _Phase.idle:
        return;
    }
    try {
      if (kDebugMode) debugPrint('Attempting to play: $asset');
      // Use audioplayers for voice cues
      await _voicePlayer.play(ap.AssetSource(asset));
    } catch (e) {
      if (kDebugMode) debugPrint('Audio play error for $asset: $e');
    }
  }

  // ignore: unused_element
  Future<void> _clearPrayerPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyIntroDismissed);
    await prefs.remove(_legacyPrefsKeyIntroDismissed);
    await prefs.remove(_prefsKeyMusicOn);
    await prefs.remove(_prefsKeyVoiceOn);
    await prefs.remove(_prefsKeyFirebreathEnabled);
    await prefs.remove(_prefsKeyVoiceGender);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prayer prefs cleared. Restart screen.')),
      );
    }
  }

  void _start() {
    if (running) return;
    // Automatically minimize controls when starting
    setState(() {
      controlsExpanded = false;
    });
    expandCtrl.reverse();
    // Start or resume session timer
    _sessionStart ??= DateTime.now();
    _sessionTicker?.cancel();
    _sessionTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    if (_firebreathEnabled) _startFirebreathCycle();
    if (_musicOn) _playBg('assets/sounds/meditation/normal_bg.mp3');
    _runSequence();
  }

  void _pause() {
    final elapsed = _sessionElapsed; // Capture duration before reset
    setState(() {
      running = false;
      // Automatically expand controls when stopping
      controlsExpanded = true;
      // Reset session start so next Start begins a fresh session timer.
      _sessionStart = null;
    });
    expandCtrl.forward();
    if (_firebreathEnabled) _stopFirebreathCycle();
    _stopBg();
    _playWellDoneCue(elapsed);
    _sessionTicker?.cancel();
    _sessionTicker = null;
  }

  void _nextVerse() {
    setState(() => verse = _VerseRotation.next(_mode));
  }

  void _toggleControls() {
    setState(() {
      controlsExpanded = !controlsExpanded;
      if (controlsExpanded) {
        expandCtrl.forward();
      } else {
        expandCtrl.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepBlack,
      appBar: AppBar(
        title: Text(_getModeTitle()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'New Verse',
            onPressed: _nextVerse,
            icon: const Icon(Icons.autorenew_rounded, color: Colors.white70),
          ),
          IconButton(
            icon: const Icon(Icons.note_alt_outlined, color: Colors.white70),
            tooltip: 'Notes',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const NotesListScreen(noteType: NoteType.meditation),
                ),
              );
            },
          ),
          // FireBreath ring indicator (animated gif) shown only while active
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(scale: anim, child: child),
            ),
            child: (_firebreathEnabled && _firebreathActive)
                ? ClipOval(
                    child: Image.asset(
                      'assets/ring/ring.gif',
                      height: 75,
                      width: 75,
                      fit: BoxFit.cover,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background Layer
          if (_mode == PrayerModeType.fire)
            Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF0F0404), // Deep Black Red
                            Color(0xFF1F0808),
                            Color(0xFF330C0C),
                            Color(0xFF241005),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Fire Sparks
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: glitterCtrl,
                      builder: (_, __) => CustomPaint(
                        painter: _AtmospherePainter(
                          progress: glitterCtrl.value,
                          mode: _mode,
                        ),
                      ),
                    ),
                  ),
                ),
                // Radial Glow
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 0.9,
                          colors: [const Color(0x22FF5722), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else if (_mode == PrayerModeType.golden)
            Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF0C0A04),
                            Color(0xFF1F1C12),
                            Color(0xFF302B18),
                            Color(0xFF26210A),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Gold Glitter
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: glitterCtrl,
                      builder: (_, __) => CustomPaint(
                        painter: _AtmospherePainter(
                          progress: glitterCtrl.value,
                          mode: _mode,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 0.9,
                          colors: [
                            kGold.withValues(alpha: 0.15),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _RoyalSpecklePainter()),
                  ),
                ),
              ],
            )
          else
            CosmicBackground(
              accent: kPurple,
              child: const SizedBox.shrink(), // Render only background here
            ),

          // Main Content Layer
          Column(
            children: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _mode == PrayerModeType.fire
                            ? 'Ignite your spirit.'
                            : (_mode == PrayerModeType.golden
                                  ? 'Bathe in His Glory.'
                                  : 'Focus your breath. Invite His Presence.'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _VerseCard(verse: verse, mode: _mode),
                    const SizedBox(height: 12),
                    const SizedBox.shrink(),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Sacred stage with guidance text
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: _SacredStage(
                        phase: phase,
                        breatheCtrl: breatheCtrl,
                        auraCtrl: auraCtrl,
                        prayCtrl: prayCtrl,
                        verse: verse,
                        mode: _mode,
                      ),
                    ),
                    // Guidance text below the bubble
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getGuidanceText(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 1.2,
                              fontFamily: 'serif',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Builder(
                            builder: (_) {
                              final sess = _sessionElapsed;
                              final smm = sess.inMinutes
                                  .remainder(60)
                                  .toString()
                                  .padLeft(2, '0');
                              final sss = (sess.inSeconds.remainder(
                                60,
                              )).toString().padLeft(2, '0');

                              // In Fire Mode, always show Fire count (even if implied same as session unless custom logic)
                              if (_mode == PrayerModeType.fire) {
                                // If we assume fire breath cycle is running, we can show that timer
                                // or just the session timer styled with FIRE
                                return Text(
                                  'FIRE SESSION  $smm:$sss',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 14,
                                    letterSpacing: 1.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }

                              return Text(
                                'SESSION  $smm:$sss',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                  letterSpacing: 1.0,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom padding for arrow button
              const SizedBox(height: 80),
            ],
          ),

          // Expandable controls panel
          _ExpandableControlsPanel(
            mode: _mode,
            onModeChanged: (m) {
              setState(() {
                _mode = m;
                // Update verse to match the new mode
                verse = _VerseRotation.next(_mode);

                // Apply presets based on mode
                if (_mode == PrayerModeType.fire) {
                  // Fire presets
                  breathsPerSet = 30; // High repetition for fire breath
                  holdSeconds = 0;
                  praySeconds = 10;
                  _firebreathEnabled = true;
                  if (running) _startFirebreathCycle();
                } else if (_mode == PrayerModeType.golden) {
                  // Golden presets
                  breathsPerSet = 4;
                  holdSeconds = 20; // Long hold
                  praySeconds = 30;
                  _firebreathEnabled = false;
                  _stopFirebreathCycle();
                } else {
                  // Regular presets (reset to defaults or last saved? we'll use defaults)
                  breathsPerSet = 4;
                  holdSeconds = 10;
                  praySeconds = 10;
                  _firebreathEnabled = false;
                  _stopFirebreathCycle();
                }
                _settingsDirty = true;
              });
            },
            isExpanded: controlsExpanded,
            expandCtrl: expandCtrl,
            breathsPerSet: breathsPerSet,
            holdSeconds: holdSeconds,
            praySeconds: praySeconds,
            musicOn: _musicOn,
            voiceOn: _voiceOn,
            gender: _gender,
            firebreathEnabled: _firebreathEnabled,
            onMusicChanged: (v) => setState(() {
              _musicOn = v;
              _saveVoicePrefs();
              if (!_musicOn) {
                _stopBg();
              } else if (running) {
                (_firebreathEnabled && _firebreathActive)
                    ? _playBg('assets/sounds/meditation/fire_breath_bg.mp3')
                    : _playBg('assets/sounds/meditation/normal_bg.mp3');
              }
            }),
            onVoiceChanged: (v) => setState(() {
              _voiceOn = v;
              _saveVoicePrefs();
            }),
            onGenderChanged: (g) => setState(() {
              _gender = g;
              _saveVoicePrefs();
            }),
            onFirebreathEnableChanged: (v) => setState(() {
              _firebreathEnabled = v;
              _saveVoicePrefs();
              if (!_firebreathEnabled) {
                _stopFirebreathCycle();
              } else if (running) {
                _startFirebreathCycle();
              }
            }),
            onBreathsChanged: (v) => setState(() {
              breathsPerSet = v.round();
              _settingsDirty = true;
            }),
            onHoldChanged: (v) => setState(() {
              holdSeconds = v.round();
              _settingsDirty = true;
            }),
            onPrayChanged: (v) => setState(() {
              praySeconds = v.round();
              _settingsDirty = true;
            }),
            onStart: _start,
            onPause: _pause,
            phase: phase,
            running: running,
            firebreathActive: _firebreathEnabled && _firebreathActive,
            nextFirebreath: (_firebreathEnabled && _firebreathActive)
                ? _firebreathActiveRemaining
                : (_firebreathCountdownRemaining == Duration.zero
                      ? Duration.zero
                      : _firebreathCountdownRemaining),
            onSaveSettings: _savePrayerSettingsPrefs,
            settingsDirty: _settingsDirty,
          ),

          // Settings toggle button at bottom
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _toggleControls,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: (_firebreathEnabled && _firebreathActive)
                        ? kGold.withValues(alpha: 0.65)
                        : kRoyalBlue.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (_firebreathEnabled && _firebreathActive)
                          ? kGold
                          : kRoyalBlue,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Settings',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        turns: controlsExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.keyboard_arrow_up,
                          color: Colors.white70,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Removed floating sound toggle – granular controls now inside settings panel

          // Golden overlay for active Firebreath – soft glow & vignette
          // Removed previous semi-transparent golden overlay; full golden theme now handled above.
        ],
      ),
    );
  }

  String _getGuidanceText() {
    switch (phase) {
      case _Phase.idle:
        return 'Ready';
      case _Phase.inhale:
        return 'Breathe In';
      case _Phase.exhale:
        return 'Breathe Out';
      case _Phase.hold:
        return 'Hold';
      case _Phase.pray:
        return 'Pray';
    }
  }

  Future<void> _playWellDoneCue(Duration elapsed) async {
    // Reward logic based on active time
    int rings = 0;
    if (elapsed.inMinutes >= 1) {
      switch (_mode) {
        case PrayerModeType.fire:
          // Fire: High intensity, ~5 mins to max
          rings = (elapsed.inMinutes * 300).clamp(0, 1500);
          break;
        case PrayerModeType.golden:
          // Golden: Highest value, ~5 mins to max
          rings = (elapsed.inMinutes * 1000).clamp(0, 5000);
          break;
        case PrayerModeType.regular:
          // Regular: Base 500 + 50/min, max 1000
          rings = (500 + ((elapsed.inMinutes - 1) * 50)).clamp(500, 1000);
          break;
      }
    } else {
      rings = 0;
    }

    if (rings > 0) {
      try {
        await UserService.instance.incrementRings(rings);
      } catch (e) {
        debugPrint('Failed to save meditation reward: $e');
      }
    }

    // 1. Play "Well Done" voice if enabled
    if (_voiceOn) {
      final g = _gender == _VoiceGender.male ? 'male' : 'female';
      final asset = 'sounds/meditation/welldone_${g}.mp3';
      try {
        await _voicePlayer.play(ap.AssetSource(asset));
        // Hard wait to guaranteed execution order:
        // Clip duration (~1.5s) + Pause (~2.5s) = 4 seconds total wait.
        // This avoids any stream listener issues.
        await Future.delayed(const Duration(seconds: 4));
      } catch (e) {
        if (kDebugMode) debugPrint('WellDone audio error: $e');
      }
    }

    // 2. Trigger the Flame Reward Overlay (Orange Ring + SFX) AFTER voice finishes
    if (mounted && rings > 0) {
      RoyalRing.show(
        context,
        glowColor: Colors.purpleAccent,
        size: 80,
        behavior: RoyalRingBehavior.meditation,
      );
    }
  }

  String _getModeTitle() {
    switch (_mode) {
      case PrayerModeType.fire:
        return 'Fire Meditation';
      case PrayerModeType.golden:
        return 'Golden Meditation';
      case PrayerModeType.regular:
        return 'Prayer Mode';
    }
  }
}

enum _Phase { idle, inhale, exhale, hold, pray }

/// Lightweight painter for subtle royal speckle particles.
class _RoyalSpecklePainter extends CustomPainter {
  static final List<Offset> _points = [];
  static bool _initialized = false;
  static void _init(Size size) {
    if (_initialized) return;
    final rand = math.Random(1337);
    final count = 90; // sparse
    for (int i = 0; i < count; i++) {
      _points.add(
        Offset(rand.nextDouble() * size.width, rand.nextDouble() * size.height),
      );
    }
    _initialized = true;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _init(size);
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < _points.length; i++) {
      final p = _points[i];
      final t = (i % 13) / 13.0;
      final alpha = (60 + 80 * t).toInt();
      paint.color = Color.lerp(
        const Color(0xFF6C2BD9),
        const Color(0xFFFFD700),
        t,
      )!.withAlpha(alpha);
      final radius = 0.6 + 1.4 * t;
      canvas.drawCircle(p, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _VerseRotation {
  static int _regIdx = -1;
  static int _fireIdx = -1;
  static int _goldIdx = -1;

  static final List<_Verse> _regularVerses = [
    _Verse(
      '"Come to me, all you who are weary and burdened, and I will give you rest."',
      'Matthew 11:28',
    ),
    _Verse('"Peace I leave with you; my peace I give you."', 'John 14:27'),
    _Verse('"Be still, and know that I am God."', 'Psalm 46:10'),
    _Verse(
      '"Cast all your anxiety on Him because He cares for you."',
      '1 Peter 5:7',
    ),
    _Verse('"The LORD is my shepherd; I shall not want."', 'Psalm 23:1'),
    _Verse(
      '"Ask and it will be given to you; seek and you will find."',
      'Matthew 7:7',
    ),
    _Verse('"The LORD is near to the brokenhearted."', 'Psalm 34:18'),
    _Verse('"In quietness and trust is your strength."', 'Isaiah 30:15'),
    _Verse(
      '"Your word is a lamp to my feet and a light to my path."',
      'Psalm 119:105',
    ),
    _Verse(
      '"Rejoice in hope, be patient in tribulation, be constant in prayer."',
      'Romans 12:12',
    ),
  ];

  static final List<_Verse> _fireVerses = [
    _Verse(
      '"When thou walkest through the fire, thou shalt not be burned; neither shall the flame kindle upon thee."',
      'Isaiah 43:2',
    ),
    _Verse(
      '"I will be unto her a wall of fire round about, and will be the glory in the midst of her."',
      'Zechariah 2:5',
    ),
    _Verse(
      '"Did not our heart burn within us, while he talked with us by the way?"',
      'Luke 24:32',
    ),
    _Verse(
      '"He shall baptize you with the Holy Ghost, and with fire."',
      'Matthew 3:11',
    ),
    _Verse(
      '"For the Lord thy God is a consuming fire, even a jealous God."',
      'Deuteronomy 4:24',
    ),
    _Verse('"Our God is a consuming fire."', 'Hebrews 12:29'),
    _Verse(
      '"Is not my word like as a fire? saith the Lord."',
      'Jeremiah 23:29',
    ),
    _Verse(
      '"The fire shall ever be burning upon the altar; it shall never go out."',
      'Leviticus 6:13',
    ),
    _Verse('"And the Lord answered him by fire."', '1 Kings 18:38'),
    _Verse(
      '"And the glory of the Lord was like devouring fire on the top of the mount."',
      'Exodus 24:17',
    ),
    _Verse(
      '"The Lord went before them by night in a pillar of fire, to give them light."',
      'Exodus 13:21',
    ),
    _Verse(
      '"The angel of the Lord appeared unto him in a flame of fire out of the midst of a bush."',
      'Exodus 3:2',
    ),
  ];

  static final List<_Verse> _goldenVerses = [
    _Verse(
      '"Holy, holy, holy, is the Lord of hosts: the whole earth is full of his glory."',
      'Isaiah 6:3',
    ),
    _Verse(
      '"And the city had no need of the sun, neither of the moon, to shine in it: for the glory of God did lighten it."',
      'Revelation 21:23',
    ),
    _Verse('"The Lord reigneth; he is clothed with majesty."', 'Psalm 93:1'),
    _Verse(
      '"And they shall see his face; and his name shall be in their foreheads."',
      'Revelation 22:4',
    ),
    _Verse(
      '"Blessing, and honour, and glory, and power, be unto him that sitteth upon the throne."',
      'Revelation 5:13',
    ),
    _Verse(
      '"The heavens declare the glory of God; and the firmament sheweth his handywork."',
      'Psalm 19:1',
    ),
    _Verse(
      '"Who coverest thyself with light as with a garment."',
      'Psalm 104:2',
    ),
    _Verse(
      '"And the Lord shall be unto thee an everlasting light, and thy God thy glory."',
      'Isaiah 60:19',
    ),
    _Verse(
      '"Thine, O Lord, is the greatness, and the power, and the glory."',
      '1 Chronicles 29:11',
    ),
    _Verse(
      '"And Jesus was transfigured before them: and his face did shine as the sun."',
      'Matthew 17:2',
    ),
  ];

  static _Verse next(PrayerModeType mode) {
    switch (mode) {
      case PrayerModeType.fire:
        _fireIdx = (_fireIdx + 1) % _fireVerses.length;
        return _fireVerses[_fireIdx];
      case PrayerModeType.golden:
        _goldIdx = (_goldIdx + 1) % _goldenVerses.length;
        return _goldenVerses[_goldIdx];
      case PrayerModeType.regular:
        _regIdx = (_regIdx + 1) % _regularVerses.length;
        return _regularVerses[_regIdx];
    }
  }
}

/// Animated atmosphere painter for Fire (sparks) and Golden (glitter).
class _AtmospherePainter extends CustomPainter {
  final double progress; // 0..1 looping
  final PrayerModeType mode;
  static const int _count = 140;
  static final List<Offset> _basePositions = [];
  static bool _inited = false;

  _AtmospherePainter({required this.progress, required this.mode});

  void _init(Size size) {
    if (_inited) return;
    final rand = math.Random(90421);
    for (int i = 0; i < _count; i++) {
      _basePositions.add(
        Offset(rand.nextDouble() * size.width, rand.nextDouble() * size.height),
      );
    }
    _inited = true;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _init(size);
    final time = progress * 2 * math.pi;
    final paint = Paint()..style = PaintingStyle.fill;

    // Config based on mode
    final bool isFire = mode == PrayerModeType.fire;

    for (int i = 0; i < _count; i++) {
      final base = _basePositions[i];

      // Fire sparks rise faster, Gold dust floats gently
      final double driftSpeed = isFire ? 2.5 : 0.6;
      final driftY = (time * 6 + i) * driftSpeed;

      // Lateral wave
      final waveX = math.sin(time * 1.2 + i * 0.35) * (isFire ? 2 : 4);

      final pos = Offset(
        (base.dx + waveX) % size.width,
        (base.dy - driftY) % size.height,
      );

      // Flicker
      final flicker = (math.sin(time * 3.0 + i * 0.9) + 1) * 0.5;
      final twinkle = math.pow(flicker, 1.5).toDouble();
      final alpha = (70 + 150 * twinkle).clamp(0, 255).toInt();

      // Color Logic
      Color color;
      if (isFire) {
        // Fire: Red -> Orange -> Yellow
        final hueShift = (math.sin(i * 0.5 + time) + 1) * 0.5;
        color = Color.lerp(
          Colors.deepOrange,
          Colors.amber,
          hueShift,
        )!.withAlpha(alpha);
      } else {
        // Golden: Gold -> Amber
        final hueShift = (math.sin(i * 0.37 + time) + 1) * 0.5;
        final Color baseGold = const Color(0xFFFFD670);
        final Color deepGold = const Color(0xFFFFB020);
        color = Color.lerp(deepGold, baseGold, hueShift)!.withAlpha(alpha);
      }

      paint.color = color;

      // Size: Fire sparks are smaller/sharper? Or variable.
      final radius = 0.8 + 1.9 * twinkle;
      canvas.drawCircle(pos, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AtmospherePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.mode != mode;
}

class _Verse {
  final String text;
  final String ref;
  const _Verse(this.text, this.ref);
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min, max;
  final int? divisions;
  final String display;
  final ValueChanged<double> onChanged;
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
    this.divisions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  label: display,
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            display,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerseCard extends StatelessWidget {
  final _Verse verse;
  final PrayerModeType mode;
  const _VerseCard({required this.verse, required this.mode});

  @override
  Widget build(BuildContext context) {
    List<Color> gradientColors;
    Color borderColor;

    switch (mode) {
      case PrayerModeType.fire:
        gradientColors = [
          const Color(0x44FF3D00), // Red/Orange
          const Color(0x333E0B0B),
          const Color(0x33FF9100),
        ];
        borderColor = const Color(0x44FF5722);
        break;
      case PrayerModeType.golden:
        gradientColors = [
          const Color(0x33FFD700), // Gold
          const Color(0x332D1504),
          const Color(0x33FFA000),
        ];
        borderColor = const Color(0x33FFC107);
        break;
      case PrayerModeType.regular:
        gradientColors = [
          const Color(0x336C2BD9), // Purple
          const Color(0x330B1A3A),
          const Color(0x33FFD700),
        ];
        borderColor = const Color(0x33162031);
        break;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            verse.text,
            key: ValueKey(verse.text),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            verse.ref,
            key: ValueKey(verse.ref),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

/// Steps list used inside the one-time tutorial dialog.
class _TutorialSteps extends StatelessWidget {
  final bool shorter;
  const _TutorialSteps({this.shorter = false});

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: kPurple,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (shorter) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bullet('1 Breathe IN while reading the verse.'),
          _bullet('2 Breathe OUT while reading it again.'),
          _bullet('3 HOLD in stillness (sacred pause).'),
          _bullet('4 PRAY on release – gratitude or surrender.'),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bullet(
          '1 Breathe IN while reading the verse, letting it enter your heart.',
        ),
        _bullet(
          '2 Breathe OUT while reading it again, releasing tension into His care.',
        ),
        _bullet('3 HOLD in stillness – a sacred pause of quiet awareness.'),
        _bullet(
          '4 PRAY as you release – gratitude, simple request, or surrender.',
        ),
        _bullet(
          'The cycle repeats. Adjust breath/hold/pray timings in settings.',
        ),
        const SizedBox(height: 4),
        const Text(
          'Tip: You can change breaths, hold, and prayer length any time.',
          style: TextStyle(color: Colors.white38, fontSize: 12.5),
        ),
      ],
    );
  }
}

enum _VoiceGender { male, female }

class _AudioSettingsInline extends StatelessWidget {
  final bool musicOn;
  final bool voiceOn;
  final bool firebreathEnabled;
  final _VoiceGender gender;
  final ValueChanged<bool> onMusicChanged;
  final ValueChanged<bool> onVoiceChanged;
  final ValueChanged<_VoiceGender> onGenderChanged;
  final ValueChanged<bool> onFirebreathChanged;
  // Temporarily hide FireBreath UI; keep wiring for future use.
  final bool showFirebreath = false;
  final bool centered;
  // Renders FireBreath pill on its own second centered row when true.
  final bool firebreathSecondRow;
  const _AudioSettingsInline({
    required this.musicOn,
    required this.voiceOn,
    required this.firebreathEnabled,
    required this.gender,
    required this.onMusicChanged,
    required this.onVoiceChanged,
    required this.onGenderChanged,
    required this.onFirebreathChanged,
    this.centered = false,
    this.firebreathSecondRow = false,
  });

  @override
  Widget build(BuildContext context) {
    final primaryChildren = <Widget>[
      _iconToggle(
        tooltip: musicOn ? 'Music On' : 'Music Off',
        icon: Icons.music_note_rounded,
        active: musicOn,
        onTap: () => onMusicChanged(!musicOn),
      ),
      const SizedBox(width: 8),
      _iconToggle(
        tooltip: voiceOn ? 'Voice On' : 'Voice Off',
        icon: Icons.record_voice_over_rounded,
        active: voiceOn,
        onTap: () => onVoiceChanged(!voiceOn),
      ),
      const SizedBox(width: 16),
      Opacity(
        opacity: voiceOn ? 1 : 0.35,
        child: Row(
          children: [
            _genderDot(
              label: 'M',
              selected: gender == _VoiceGender.male && voiceOn,
              onTap: voiceOn ? () => onGenderChanged(_VoiceGender.male) : null,
            ),
            const SizedBox(width: 6),
            _genderDot(
              label: 'F',
              selected: gender == _VoiceGender.female && voiceOn,
              onTap: voiceOn
                  ? () => onGenderChanged(_VoiceGender.female)
                  : null,
            ),
          ],
        ),
      ),
    ];

    if (showFirebreath && firebreathSecondRow) {
      final firstRow = Row(
        mainAxisAlignment: centered
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: primaryChildren,
      );
      final secondRow = Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [_firebreathPill(context)],
        ),
      );
      final column = Column(
        mainAxisSize: MainAxisSize.min,
        children: [firstRow, secondRow],
      );
      return centered
          ? Align(alignment: Alignment.center, child: column)
          : column;
    }

    final row = Row(
      mainAxisAlignment: centered
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        ...primaryChildren,
        if (showFirebreath) ...[
          const SizedBox(width: 14),
          _firebreathPill(context),
        ],
      ],
    );
    return centered ? Align(alignment: Alignment.center, child: row) : row;
  }

  Widget _iconToggle({
    required IconData icon,
    required bool active,
    required String tooltip,
    List<Color>? activeGradient,
    VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: active
                ? LinearGradient(
                    colors:
                        activeGradient ??
                        [kPurple, kPurple.withValues(alpha: 0.65)],
                  )
                : null,
            color: active ? null : const Color(0x18162031),
            border: Border.all(
              color: active
                  ? (activeGradient == null ? kPurple : kGold)
                  : Colors.white12,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: (activeGradient == null ? kPurple : kGold)
                          .withValues(alpha: 0.45),
                      blurRadius: 14,
                      spreadRadius: 1,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 22,
            color: active ? Colors.black : Colors.white54,
          ),
        ),
      ),
    );
  }

  Widget _genderDot({
    required String label,
    required bool selected,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: selected
              ? LinearGradient(
                  colors: [kPurple, kPurple.withValues(alpha: 0.7)],
                )
              : null,
          color: selected ? null : const Color(0x14162031),
          border: Border.all(color: selected ? kPurple : Colors.white12),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: kPurple.withValues(alpha: 0.4),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white54,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  Widget _firebreathPill(BuildContext context) {
    return GestureDetector(
      onTap: () => onFirebreathChanged(!firebreathEnabled),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: firebreathEnabled
              ? const LinearGradient(
                  colors: [kGold, Color(0xFFE7C75A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: firebreathEnabled ? null : const Color(0x18162031),
          border: Border.all(color: firebreathEnabled ? kGold : Colors.white12),
          boxShadow: firebreathEnabled
              ? [
                  BoxShadow(
                    color: kGold.withValues(alpha: 0.45),
                    blurRadius: 16,
                    spreadRadius: 1,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              size: 18,
              color: firebreathEnabled ? Colors.black : kGold,
            ),
            const SizedBox(width: 6),
            Text(
              'FireBreath',
              style: TextStyle(
                color: firebreathEnabled ? Colors.black : Colors.white70,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sacred stage visuals: breathing bubble with aura and prayer halo.
class _SacredStage extends StatelessWidget {
  final _Phase phase;
  final AnimationController breatheCtrl;
  final AnimationController auraCtrl;
  final AnimationController prayCtrl;
  final _Verse verse;
  final PrayerModeType mode;

  const _SacredStage({
    required this.phase,
    required this.breatheCtrl,
    required this.auraCtrl,
    required this.prayCtrl,
    required this.verse,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    final baseScale = 0.82;
    final breatheScale = Tween<double>(begin: baseScale, end: 1.06).animate(
      CurvedAnimation(parent: breatheCtrl, curve: Curves.easeInOutCubic),
    );
    final aura = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: auraCtrl, curve: Curves.easeInOut));
    final spin = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(parent: prayCtrl, curve: Curves.linear));

    Color mainAuraColor;
    Color secondaryAuraColor;
    Color bubbleStart;
    Color bubbleEnd;
    Color haloColor;

    switch (mode) {
      case PrayerModeType.fire:
        mainAuraColor = const Color(0xFFFF3D00); // Deep Orange
        secondaryAuraColor = const Color(0x22FF9100);
        bubbleStart = const Color(0xFF2D0E0E);
        bubbleEnd = const Color(0xFF3E1212);
        haloColor = const Color(0xFFFF5722);
        break;
      case PrayerModeType.golden:
        mainAuraColor = kGold;
        secondaryAuraColor = const Color(0x22FFB300);
        bubbleStart = const Color(0xFF1F1605);
        bubbleEnd = const Color(0xFF291F0A);
        haloColor = kGold;
        break;
      case PrayerModeType.regular:
        mainAuraColor = const Color(0xFF6C2BD9); // Purple
        secondaryAuraColor = const Color(0x11000000);
        bubbleStart = const Color(0xFF0F1520);
        bubbleEnd = const Color(0xFF101826);
        haloColor = Colors.white24;
        break;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.shortestSide * 0.78;
        return Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([breatheCtrl, auraCtrl, prayCtrl]),
            builder: (context, _) {
              final scale = () {
                switch (phase) {
                  case _Phase.inhale:
                  case _Phase.exhale:
                    return breatheScale.value;
                  case _Phase.hold:
                    return baseScale;
                  case _Phase.pray:
                    return baseScale * 1.02;
                  case _Phase.idle:
                    return baseScale;
                }
              }();

              final haloOpacity = () {
                switch (phase) {
                  case _Phase.hold:
                    return 0.35 + 0.25 * aura.value;
                  case _Phase.pray:
                    return 0.45;
                  default:
                    return 0.25 * aura.value;
                }
              }();

              return Stack(
                alignment: Alignment.center,
                children: [
                  // Aura
                  Opacity(
                    opacity: mode == PrayerModeType.regular ? 0.35 : 0.5,
                    child: Container(
                      width: size * 1.25,
                      height: size * 1.25,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            mainAuraColor.withValues(
                              alpha: mode == PrayerModeType.regular ? 1.0 : 0.4,
                            ),
                            secondaryAuraColor,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Spinning Halo Ring
                  AnimatedBuilder(
                    animation: spin,
                    builder: (_, __) {
                      return Transform.rotate(
                        angle: phase == _Phase.pray ? spin.value : 0,
                        child: Container(
                          width: size * 1.05,
                          height: size * 1.05,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: haloColor.withValues(alpha: 0.1),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: haloColor.withValues(alpha: haloOpacity),
                                blurRadius: 22,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Main breathing bubble
                  SizedBox(
                    width: size,
                    height: size,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.scale(
                          scale: scale,
                          child: Container(
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [bubbleStart, bubbleEnd],
                              ),
                              border: Border.fromBorderSide(
                                BorderSide(
                                  color: bubbleStart.withValues(alpha: 1.2),
                                ),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black54,
                                  blurRadius: 16,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(18),
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeIn,
                                child: const SizedBox.shrink(
                                  key: ValueKey('empty'),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// Expandable controls panel that slides up from the bottom
class _ExpandableControlsPanel extends StatelessWidget {
  final bool isExpanded;
  final AnimationController expandCtrl;
  final int breathsPerSet;
  final int holdSeconds;
  final int praySeconds;
  final bool musicOn;
  final bool voiceOn;
  final _VoiceGender gender;
  final bool firebreathEnabled;
  final PrayerModeType mode;
  final ValueChanged<PrayerModeType> onModeChanged;
  final ValueChanged<bool> onMusicChanged;
  final ValueChanged<bool> onVoiceChanged;
  final ValueChanged<_VoiceGender> onGenderChanged;
  final ValueChanged<bool> onFirebreathEnableChanged;
  final ValueChanged<double> onBreathsChanged;
  final ValueChanged<double> onHoldChanged;
  final ValueChanged<double> onPrayChanged;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final _Phase phase;
  final bool running;
  final bool firebreathActive;
  final Duration
  nextFirebreath; // remaining either active time or countdown time
  final VoidCallback onSaveSettings;
  final bool settingsDirty;

  const _ExpandableControlsPanel({
    required this.isExpanded,
    required this.expandCtrl,
    required this.breathsPerSet,
    required this.holdSeconds,
    required this.praySeconds,
    required this.musicOn,
    required this.voiceOn,
    required this.gender,
    required this.firebreathEnabled,
    required this.mode,
    required this.onModeChanged,
    required this.onMusicChanged,
    required this.onVoiceChanged,
    required this.onGenderChanged,
    required this.onFirebreathEnableChanged,
    required this.onBreathsChanged,
    required this.onHoldChanged,
    required this.onPrayChanged,
    required this.onStart,
    required this.onPause,
    required this.phase,
    required this.running,
    required this.firebreathActive,
    required this.nextFirebreath,
    required this.onSaveSettings,
    required this.settingsDirty,
  });

  @override
  Widget build(BuildContext context) {
    final slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: expandCtrl, curve: Curves.easeInOut));

    return Positioned.fill(
      child: Stack(
        children: [
          // Dismissal layer (tap outside to close)
          if (isExpanded)
            GestureDetector(
              onTap: () => expandCtrl.reverse(),
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),

          // The Controls Panel
          Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: slideAnimation,
              child: Container(
                // Max height 75% of screen
                height: MediaQuery.of(context).size.height * 0.75,
                decoration: BoxDecoration(
                  // Less transparent: 0.96
                  color: kRoyalBlue.withValues(alpha: 0.96),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  border: Border(
                    top: BorderSide(color: kRoyalBlue),
                    left: BorderSide(color: kRoyalBlue),
                    right: BorderSide(color: kRoyalBlue),
                  ),
                ),
                child: Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white30,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          12,
                          20,
                          MediaQuery.of(context).padding.bottom + 8,
                        ),
                        child: LayoutBuilder(
                          builder: (ctx, constraints) {
                            return SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Prayer Settings',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      TextButton.icon(
                                        // Allow saving while running now
                                        onPressed: settingsDirty
                                            ? onSaveSettings
                                            : null,
                                        icon: Icon(
                                          Icons.save_rounded,
                                          color: settingsDirty
                                              ? kPurple
                                              : Colors.white24,
                                          size: 18,
                                        ),
                                        label: Text(
                                          settingsDirty
                                              ? 'Save for next time'
                                              : 'Saved',
                                          style: TextStyle(
                                            color: settingsDirty
                                                ? kPurple
                                                : Colors.white38,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // if (firebreathEnabled) ...[
                                  //   _FirebreathBanner(active: firebreathActive, remaining: nextFirebreath),
                                  //   const SizedBox(height: 18),
                                  // ],

                                  // Mode Selector
                                  _ModeSelector(
                                    selectedMode: mode,
                                    onModeChanged: onModeChanged,
                                    enabled: !running,
                                  ),
                                  const SizedBox(height: 24),

                                  // Audio & Firebreath toggles
                                  _AudioSettingsInline(
                                    musicOn: musicOn,
                                    voiceOn: voiceOn,
                                    firebreathEnabled: firebreathEnabled,
                                    gender: gender,
                                    onMusicChanged: onMusicChanged,
                                    onVoiceChanged: onVoiceChanged,
                                    onGenderChanged: onGenderChanged,
                                    onFirebreathChanged:
                                        onFirebreathEnableChanged,
                                  ),
                                  const SizedBox(height: 18),

                                  // Sliders now interactive during session; changes apply to upcoming phases.
                                  Opacity(
                                    opacity: running ? 0.95 : 1,
                                    child: Column(
                                      children: [
                                        _SliderRow(
                                          label: 'Breaths before Hold/Pray',
                                          value: breathsPerSet.toDouble(),
                                          min: 1,
                                          max: mode == PrayerModeType.fire
                                              ? 60.0
                                              : 10.0,
                                          divisions: mode == PrayerModeType.fire
                                              ? 59
                                              : 9,
                                          display: '${breathsPerSet}x',
                                          onChanged: onBreathsChanged,
                                        ),
                                        _SliderRow(
                                          label: 'Hold length',
                                          value: holdSeconds.toDouble(),
                                          min: 0,
                                          max: 20,
                                          divisions: 20,
                                          display: '${holdSeconds}s',
                                          onChanged: onHoldChanged,
                                        ),
                                        _SliderRow(
                                          label: 'Prayer length',
                                          value: praySeconds.toDouble(),
                                          min: 5,
                                          max: 120,
                                          divisions: 23,
                                          display: '${praySeconds}s',
                                          onChanged: onPrayChanged,
                                        ),
                                        if (running)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Text(
                                              'Changes take effect immediately for breaths count; timing changes affect next Hold/Pray.',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                color: Colors.white38,
                                                fontSize: 11,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),

                                  // Start/Stop controls (kept near bottom but scrollable now)
                                  if (!running)
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 6,
                                          top: 6,
                                        ),
                                        child: GestureDetector(
                                          onTap: onStart,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 28,
                                              vertical: 14,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                              gradient: const LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Color(0xFF6C2BD9),
                                                  Color(0xFF371866),
                                                ],
                                              ),
                                              border: Border.all(
                                                color: kPurple,
                                                width: 1.4,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: kPurple.withValues(
                                                    alpha: 0.45,
                                                  ),
                                                  blurRadius: 22,
                                                  spreadRadius: 1,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: const [
                                                Icon(
                                                  Icons.play_arrow_rounded,
                                                  color: Colors.black,
                                                  size: 24,
                                                ),
                                                SizedBox(width: 6),
                                                Text(
                                                  'Start Session',
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 0.6,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 6,
                                          top: 6,
                                        ),
                                        child: GestureDetector(
                                          onTap: onPause,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 26,
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(28),
                                              gradient: const LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Color(0x33FF3B3B),
                                                  Color(0x220F1520),
                                                ],
                                              ),
                                              border: Border.all(
                                                color: kRed.withValues(
                                                  alpha: 0.8,
                                                ),
                                                width: 1.2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: kRed.withValues(
                                                    alpha: 0.35,
                                                  ),
                                                  blurRadius: 18,
                                                  spreadRadius: 1,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: const [
                                                Icon(
                                                  Icons.stop_rounded,
                                                  color: Colors.white,
                                                  size: 22,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Stop Session',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                    letterSpacing: 0.5,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        top: 4,
                                        bottom: 4,
                                      ),
                                      child: Text(
                                        _getPhaseLabel(phase),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ), // Align
        ],
      ), // Stack
    ); // Positioned.fill
  }

  String _getPhaseLabel(_Phase phase) {
    switch (phase) {
      case _Phase.idle:
        return 'Ready';
      case _Phase.inhale:
        return 'Breathe In';
      case _Phase.exhale:
        return 'Breathe Out';
      case _Phase.hold:
        return 'Hold (Sacred)';
      case _Phase.pray:
        return 'Pray (Sacred)';
    }
  }
}

class _ModeSelector extends StatelessWidget {
  final PrayerModeType selectedMode;
  final ValueChanged<PrayerModeType> onModeChanged;
  final bool enabled;

  const _ModeSelector({
    required this.selectedMode,
    required this.onModeChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Mode',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF0F1520),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                _buildModeItem(PrayerModeType.regular, 'Regular'),
                Container(width: 1, color: Colors.white10, height: 30),
                _buildModeItem(PrayerModeType.fire, 'Fire'),
                Container(width: 1, color: Colors.white10, height: 30),
                _buildModeItem(PrayerModeType.golden, 'Golden'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeItem(PrayerModeType mode, String label) {
    final bool isSelected = selectedMode == mode;
    Color activeColor;
    Color activeGlow;

    switch (mode) {
      case PrayerModeType.regular:
        // Use Cyan for better contrast against Royal Blue background
        activeColor = Colors.cyanAccent;
        activeGlow = Colors.cyanAccent.withValues(alpha: 0.4);
        break;
      case PrayerModeType.fire:
        activeColor = const Color(0xFFFF5722); // Orange/Fire
        activeGlow = const Color(0xFFFF5722).withValues(alpha: 0.4);
        break;
      case PrayerModeType.golden:
        activeColor = kGold;
        activeGlow = kGold.withValues(alpha: 0.4);
        break;
    }

    return Expanded(
      child: GestureDetector(
        onTap: enabled ? () => onModeChanged(mode) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: activeColor.withValues(alpha: 0.6))
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeGlow,
                      blurRadius: 8,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? activeColor : Colors.white38,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
