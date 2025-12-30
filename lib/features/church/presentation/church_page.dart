import 'package:clientapp/core/theme/palette.dart';
import 'package:clientapp/features/church_admin/data/models/church_models.dart'
    as admin;
import 'package:clientapp/features/church/data/church_repository_user.dart';
import 'package:clientapp/core/services/global_radio_service.dart';
import 'package:clientapp/core/reward/church/church_reward_service.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:clientapp/shared/widgets/back_nav_button.dart';
import 'package:clientapp/shared/widgets/calm_background.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'dart:math' as math;
import 'package:clientapp/features/journal/presentation/widgets/journal_overlay_panel.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' show ImageFilter;
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:clientapp/shared/widgets/heaven_glow.dart';
import 'package:clientapp/shared/widgets/confetti_overlay.dart';

import 'package:clientapp/shared/widgets/royal_ring.dart';

class ChurchPage extends StatefulWidget {
  const ChurchPage({super.key});

  @override
  State<ChurchPage> createState() => _ChurchPageState();
}

class _ChurchPageState extends State<ChurchPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _player = AudioPlayer(); // For sermons/stories/sacraments only
  final _globalRadio = GlobalRadioService.instance; // For radio
  int _tabIndex = 0; // 0: Sermons, 1: Stories, 2: Sacraments
  bool _showJournal = false; // overlay toggle
  bool _showIntro = true; // initial intro overlay
  Timer? _introTimer;
  bool _bgPlayEnabled = true; // background playback always enabled
  bool _pausedForBackground = false; // track if we paused due to background
  bool _radioLoading = false; // radio loading state
  bool _radioTurningOff = false; // radio turning off animation state
  final GlobalKey _radioLogoKey = GlobalKey(); // key for radio logo animation
  final GlobalKey _appBarRadioKey = GlobalKey(); // key for appbar radio button
  final GlobalKey<ConfettiOverlayState> _confettiKey =
      GlobalKey<ConfettiOverlayState>();

  StreamSubscription? _rewardSubscription;

  // Firestore data
  final _repo = ChurchUserRepository();
  final Map<admin.ChurchSection, List<admin.ChurchMainItem>> _mains = {
    admin.ChurchSection.sermons: const [],
    admin.ChurchSection.stories: const [],
    admin.ChurchSection.sacraments: const [],
  };
  final Map<String, List<admin.ChurchSubItem>> _subsByMain = {};
  final Map<String, bool> _subsLoading = {}; // track per-main sub loading state
  bool _loading = false;
  String? _error;

  // Selection and playback state
  int _selectedMain = 0;
  admin.ChurchMainItem? _playingMain;
  admin.ChurchSubItem? _playingSub;
  String? _currentKey; // current audio url
  String? _nowTitle; // bottom bar title
  bool _isPlaying = false;
  double _speed = 1.0; // playback speed
  String? _loadingKey; // which audio url is currently loading
  final ScrollController _subScroll = ScrollController();
  bool _mainsNetworkLoading =
      false; // gate sublists until mains network fetch completes
  bool _tabSwitching = false; // smooth tab transition state
  int _previousTabIndex = 0; // cache previous tab for smooth transition

  // Accent color varies by tab so each background feels distinct
  Color get _accent {
    switch (_currentSection) {
      case admin.ChurchSection.sermons:
        return kPurple; // Sermons: Purple
      case admin.ChurchSection.stories:
        return kRed; // Stories: Red
      case admin.ChurchSection.sacraments:
        return kGold; // Sacraments: Gold
    }
  }

  admin.ChurchSection get _currentSection {
    switch (_tabIndex) {
      case 0:
        return admin.ChurchSection.sermons;
      case 1:
        return admin.ChurchSection.stories;
      case 2:
      default:
        return admin.ChurchSection.sacraments;
    }
  }

  Future<void> _loadMains(
    admin.ChurchSection section, {
    bool force = false,
  }) async {
    // Use in-memory cache if available
    final cached = _mains[section] ?? const <admin.ChurchMainItem>[];
    if (cached.isNotEmpty && !force) {
      // Show cached immediately, refresh silently in background
      setState(() => _error = null);
      // background refresh
      () async {
        try {
          if (mounted) setState(() => _mainsNetworkLoading = true);
          final list = await _repo.listMain(section);
          if (!mounted) return;
          setState(() {
            _mains[section] = list;
            if (list.isNotEmpty) {
              _selectedMain = _selectedMain.clamp(0, list.length - 1);
            }
          });
          // Persist cache
          await _saveMainsCache(section, list);
          for (final m in list) {
            final url = m.thumbnailUrl;
            if (url != null) {
              // ignore: unawaited_futures
              CachedNetworkImageProvider(
                url,
              ).resolve(const ImageConfiguration());
            }
          }
          final selected = list.isNotEmpty ? list[_selectedMain] : null;
          if (selected != null) {
            await _ensureSubsLoaded(section, selected);
          }
        } catch (_) {
        } finally {
          if (mounted) setState(() => _mainsNetworkLoading = false);
        }
      }();
      return;
    }

    // Try disk cache if memory is empty or force refresh requested
    final disk = await _readMainsCache(section);
    if (disk.isNotEmpty && !force) {
      if (mounted) {
        setState(() {
          _mains[section] = disk;
          if (disk.isNotEmpty) {
            _selectedMain = _selectedMain.clamp(0, disk.length - 1);
          }
        });
      }
      for (final m in disk) {
        final url = m.thumbnailUrl;
        if (url != null) {
          // ignore: unawaited_futures
          CachedNetworkImageProvider(url).resolve(const ImageConfiguration());
        }
      }
      // continue with silent network refresh
      () async {
        try {
          if (mounted) setState(() => _mainsNetworkLoading = true);
          final list = await _repo.listMain(section);
          if (!mounted) return;
          setState(() => _mains[section] = list);
          await _saveMainsCache(section, list);
          final selected = list.isNotEmpty ? list[_selectedMain] : null;
          if (selected != null) {
            await _ensureSubsLoaded(section, selected);
          }
        } catch (_) {
        } finally {
          if (mounted) setState(() => _mainsNetworkLoading = false);
        }
      }();
      return;
    }

    setState(() {
      _loading = true;
      _mainsNetworkLoading = true;
      _error = null;
    });
    try {
      final list = await _repo.listMain(section);
      if (!mounted) return;
      setState(() {
        _mains[section] = list;
        if (list.isNotEmpty) {
          _selectedMain = _selectedMain.clamp(0, list.length - 1);
        }
      });
      await _saveMainsCache(section, list);
      for (final m in list) {
        final url = m.thumbnailUrl;
        if (url != null) {
          // ignore: unawaited_futures
          CachedNetworkImageProvider(url).resolve(const ImageConfiguration());
        }
      }
      final selected = list.isNotEmpty ? list[_selectedMain] : null;
      if (selected != null) {
        await _ensureSubsLoaded(section, selected);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load items');
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
          _mainsNetworkLoading = false;
        });
    }
  }

  String _sectionCacheKey(admin.ChurchSection s) =>
      'church_mains_cache_${s.name}';

  Future<void> _saveMainsCache(
    admin.ChurchSection section,
    List<admin.ChurchMainItem> list,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = list
          .map(
            (m) => {
              'id': m.id,
              'title': m.title,
              'thumbnailUrl': m.thumbnailUrl,
              'audioUrl': m.audioUrl,
              'description': m.description,
            },
          )
          .toList();
      await prefs.setString(_sectionCacheKey(section), jsonEncode(data));
    } catch (_) {}
  }

  Future<List<admin.ChurchMainItem>> _readMainsCache(
    admin.ChurchSection section,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sectionCacheKey(section));
      if (raw == null || raw.isEmpty) return const [];
      final List list = jsonDecode(raw) as List;
      return list
          .map((e) => e as Map<String, dynamic>)
          .map(
            (m) => admin.ChurchMainItem(
              id: m['id'] as String,
              title: (m['title'] ?? '') as String,
              thumbnailUrl: m['thumbnailUrl'] as String?,
              audioUrl: m['audioUrl'] as String?,
              description: m['description'] as String?,
              createdAt: DateTime.fromMillisecondsSinceEpoch(0),
              updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _ensureSubsLoaded(
    admin.ChurchSection section,
    admin.ChurchMainItem main,
  ) async {
    if (main.audioUrl != null) return; // no sub list for direct audio
    final already = _subsByMain[main.id];
    if (already != null && already.isNotEmpty) return;
    if (_subsLoading[main.id] == true) return;
    setState(() => _subsLoading[main.id] = true);
    try {
      final subs = await _repo.listSub(section, main.id);
      if (!mounted) return;
      setState(() {
        _subsByMain[main.id] = subs;
        _subsLoading[main.id] = false;
      });
      // Prefetch sub thumbnails
      for (final s in subs) {
        final url = s.thumbnailUrl;
        if (url != null) {
          // ignore: unawaited_futures
          CachedNetworkImageProvider(url).resolve(const ImageConfiguration());
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _subsLoading[main.id] = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Listen to local player for sermons/stories/sacraments
    _player.playingStream.listen((p) {
      if (mounted) {
        setState(() {
          _isPlaying = p;
        });
      }
      // Track reward for Church Audio (Sermons, Stories, Sacraments)
      if (p) {
        ChurchRewardService.instance.startTrackingAudio();
      } else {
        ChurchRewardService.instance.stopTrackingAudio();
      }
    });
    _player.processingStateStream.listen((st) {
      if ((st == ProcessingState.ready || st == ProcessingState.completed) &&
          _loadingKey != null) {
        if (mounted) setState(() => _loadingKey = null);
      }
    });
    _player.speedStream.listen((s) {
      if (mounted) setState(() => _speed = s);
    });

    // Listen to global radio service
    _globalRadio.addListener(_onRadioStateChanged);

    // If radio is already playing when we enter, update the UI
    if (_globalRadio.isRadioPlaying) {
      _nowTitle = _globalRadio.getCurrentTitle();
      _isPlaying = true;
      ChurchRewardService.instance.startTrackingMusic();
    }

    // Listen for Church Rewards (Audio/Radio)
    _rewardSubscription = ChurchRewardService.instance.onRewardEarned.listen((
      _,
    ) {
      if (mounted) {
        debugPrint(' ChurchReward Earned! Triggering Electric overlay.');
        RoyalRing.show(
          context,
          glowColor: Colors.cyanAccent,
          size: 80,
          behavior: RoyalRingBehavior.electric,
        );
      }
    });

    _restoreBgPref();
    _loadMains(_currentSection);

    _introTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showIntro = false);
    });
  }

  Future<void> _restoreBgPref() async {
    // Background play is always enabled, no need to restore preference
    setState(() => _bgPlayEnabled = true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!_bgPlayEnabled) {
      if (state == AppLifecycleState.paused && _player.playing) {
        _pausedForBackground = true;
        _player.pause();
      } else if (state == AppLifecycleState.resumed && _pausedForBackground) {
        _pausedForBackground = false;
        _player.play();
      }
    }
  }

  void _onRadioStateChanged() {
    if (mounted) {
      setState(() {
        // Update UI when radio state changes
        if (_globalRadio.isRadioPlaying) {
          _nowTitle = _globalRadio.getCurrentTitle();
          _isPlaying = true;
          ChurchRewardService.instance.startTrackingMusic();
          // Close tuning dialog when radio starts playing
          if (_radioLoading) {
            _radioLoading = false;
            Navigator.of(context, rootNavigator: true).pop();
            // Trigger confetti celebration when radio starts!
            print(
              '🎊 Church Radio: Radio started playing! Triggering confetti!',
            );
            _confettiKey.currentState?.celebrate();
          }
        } else {
          // Radio stopped
          ChurchRewardService.instance.stopTrackingMusic();
          if (_nowTitle != null && _currentKey == null) {
            _nowTitle = null;
            _isPlaying = false;
          }
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _introTimer?.cancel();
    _subScroll.dispose();
    _globalRadio.removeListener(_onRadioStateChanged);
    _rewardSubscription?.cancel();
    // Don't dispose global radio - it persists across the app
    // Only dispose local player for sermons/stories
    _player.dispose();
    ChurchRewardService.instance.stopTrackingAudio();
    super.dispose();
  }
  // _ensureSubsLoaded replaces the old _loadSubs

  Future<void> _toggleForUrl(String url, String title) async {
    // Check if radio is on - prevent audio playback
    if (_globalRadio.isRadioPlaying) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please turn off the radio first to play this audio',
              style: GoogleFonts.lora(fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    _nowTitle = title;
    if (_currentKey == url) {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
    } else {
      if (mounted) setState(() => _loadingKey = url);
      try {
        final file = await DefaultCacheManager().getSingleFile(url);
        final audioSource = AudioSource.uri(
          Uri.file(file.path),
          tag: MediaItem(id: url, album: "Church", title: title),
        );
        await _player.setAudioSource(audioSource);
        _currentKey = url;
        await _player.play();
      } catch (_) {
        final audioSource = AudioSource.uri(
          Uri.parse(url),
          tag: MediaItem(id: url, album: "Church", title: title),
        );
        await _player.setAudioSource(audioSource);
        _currentKey = url;
        await _player.play();
      } finally {
        if (mounted) setState(() => _loadingKey = null);
      }
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Use previous tab's data during transition for smooth experience
    final displaySection = _tabSwitching
        ? (_previousTabIndex == 0
              ? admin.ChurchSection.sermons
              : _previousTabIndex == 1
              ? admin.ChurchSection.stories
              : admin.ChurchSection.sacraments)
        : _currentSection;

    final mains = _mains[displaySection] ?? const <admin.ChurchMainItem>[];
    final selected = mains.isNotEmpty
        ? mains[_selectedMain.clamp(0, mains.length - 1)]
        : null;
    return ConfettiOverlay(
      key: _confettiKey,
      child: Scaffold(
        backgroundColor: kDeepBlack,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: SizedBox(
            height: 28,
            child: Image.asset(
              'assets/church/appbarlogo.png',
              fit: BoxFit.contain,
            ),
          ),
          leading: const Padding(
            padding: EdgeInsets.only(left: 6),
            child: BackNavButton(),
          ),
          actions: [
            IconButton(
              key: _appBarRadioKey,
              icon: Opacity(
                opacity: _globalRadio.isRadioPlaying ? 0.5 : 1.0,
                child: Image.asset(
                  'assets/church/radio/church_radio_btn.png',
                  width: 32,
                  height: 32,
                ),
              ),
              tooltip: _globalRadio.isRadioPlaying
                  ? 'Radio already playing (use floating button)'
                  : 'Church Radio',
              onPressed: _globalRadio.isRadioPlaying
                  ? null
                  : () => _showRadioDialog(),
            ),
          ],
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          switchInCurve: Curves.easeInOutCubic,
          switchOutCurve: Curves.easeInOutCubic,
          child: CalmBackground(
            key: ValueKey('bg_$_tabIndex'),
            accent: _accent,
            child: Stack(
              children: [
                // Top title + main layout
                Column(
                  children: [
                    _tabHeader(),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 720;
                          return Stack(
                            children: [
                              // Main content
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0.02, 0),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Row(
                                  key: ValueKey('tab_$_tabIndex'),
                                  children: [
                                    SizedBox(
                                      width: isWide ? 320 : 200,
                                      child: Column(
                                        children: [
                                          if (_loading)
                                            Expanded(
                                              child: ListView.builder(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 10,
                                                    ),
                                                itemCount: 6,
                                                itemBuilder: (_, __) =>
                                                    _mainSkeletonTile(),
                                              ),
                                            )
                                          else if (_error != null)
                                            Expanded(
                                              child: Center(
                                                child: Text(
                                                  _error!,
                                                  style: TextStyle(
                                                    color: Colors.redAccent,
                                                  ),
                                                ),
                                              ),
                                            )
                                          else
                                            Expanded(child: _mainList(mains)),
                                          const SizedBox(height: 8),
                                          _journalButton(),
                                          const SizedBox(height: 8),
                                        ],
                                      ),
                                    ),
                                    Expanded(child: _rightPanel(selected)),
                                  ],
                                ),
                              ),
                              // Elegant overlay during tab switch
                              if (_tabSwitching)
                                Positioned.fill(
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 200),
                                    opacity: _tabSwitching ? 1.0 : 0.0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            _accent.withValues(alpha: 0.08),
                                            Colors.black.withValues(
                                              alpha: 0.25,
                                            ),
                                            _accent.withValues(alpha: 0.08),
                                          ],
                                        ),
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              width: 80,
                                              child: Image.asset(
                                                'assets/church/logo.png',
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            SizedBox(
                                              width: 120,
                                              height: 3,
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                                child: LinearProgressIndicator(
                                                  color: _accent,
                                                  backgroundColor: _accent
                                                      .withValues(alpha: 0.2),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
                if (_showIntro)
                  Positioned.fill(
                    child: Container(
                      color: kDeepBlack.withValues(alpha: 0.6),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 140,
                              child: Image.asset(
                                'assets/church/logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: 180,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: const LinearProgressIndicator(
                                  minHeight: 5,
                                  color: kGold,
                                  backgroundColor: Colors.white24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_showJournal)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.85 > 420
                            ? 420
                            : MediaQuery.of(context).size.width * 0.85,
                        height: double.infinity,
                        child: JournalOverlayPanel(
                          onClose: () => setState(() => _showJournal = false),
                          prefsKey: 'church_journal',
                          title: 'Church Notes',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _bottomArea(_accent),
      ),
    );
  }

  // Header showing the current tab title at the top of the screen
  Widget _tabHeader() {
    final title = _tabIndex == 0
        ? 'Sermons'
        : _tabIndex == 1
        ? 'Stories'
        : 'Sacraments';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(-0.1, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              title,
              key: ValueKey('title_$title'),
              style: GoogleFonts.lora(
                color: _accent,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 1,
            width: 56,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }

  void _showRadioDialog() {
    showDialog(
      context: context,
      barrierDismissible: !_radioLoading,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: kDeepBlack,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: kGold.withValues(alpha: 0.3)),
          ),
          title: Center(
            child: SizedBox(
              height: 100,
              child: Image.asset(
                'assets/church/radio/church_radio_logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_radioLoading) ...[
                // Loading animation
                Column(
                  children: [
                    SizedBox(
                      width: 200,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: const LinearProgressIndicator(
                          minHeight: 6,
                          color: kGold,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tuning...',
                      style: GoogleFonts.lora(
                        color: kGold,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Text(
                //   'Listen to Church Radio.',
                //   style: TextStyle(color: Colors.white70, fontSize: 14),
                //   textAlign: TextAlign.center,
                // ),
                // const SizedBox(height: 20),
                if (_globalRadio.isRadioPlaying)
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _globalRadio.stopRadio();
                      if (mounted) {
                        setState(() {
                          _nowTitle = null;
                          _isPlaying = false;
                        });
                      }
                      Navigator.of(ctx).pop();
                    },
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Radio'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: () async {
                      // Stop any currently playing audio before starting radio
                      if (_currentKey != null) {
                        await _player.stop();
                        if (mounted) {
                          setState(() {
                            _currentKey = null;
                            _nowTitle = null;
                            _playingMain = null;
                            _playingSub = null;
                            _isPlaying = false;
                          });
                        }
                      }

                      setDialogState(() => _radioLoading = true);
                      setState(() => _radioLoading = true);

                      try {
                        await _globalRadio.startRadio();
                        // Dialog will auto-close when audio starts playing
                        // Confetti will trigger in radio state listener
                      } catch (e) {
                        setDialogState(() => _radioLoading = false);
                        setState(() => _radioLoading = false);
                        Navigator.of(ctx).pop();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to start radio: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Radio'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGold,
                      foregroundColor: kDeepBlack,
                    ),
                  ),
              ],
            ],
          ),
          actions: _radioLoading
              ? []
              : [
                  TextButton(
                    child: const Text('Close', style: TextStyle(color: kGold)),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
        ),
      ),
    );
  }

  Widget _bottomArea(Color accent) {
    final player = _playerBar();
    // Don't apply an outer SafeArea bottom padding here so the navbar color
    // can extend to the very bottom of the screen. The inner navbar has its
    // own SafeArea to handle insets.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [if (player != null) player, _chatStyleBottomNav()],
    );
  }

  // Chat-style bottom nav to match main screen bottom navbar
  Widget _chatStyleBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        border: Border(
          top: BorderSide(color: _accent.withValues(alpha: 0.18), width: 1),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64, // a bit taller to give bottom space
          child: Stack(
            children: [
              // Lift icons up so they can visually come out above the top edge
              Transform.translate(
                offset: const Offset(0, -6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _chatNavItem(
                      index: 0,
                      imagePath: 'assets/church/buttons/sermons.png',
                      label: 'Sermons',
                      color: _accent,
                    ),
                    _chatNavItem(
                      index: 1,
                      imagePath: 'assets/church/buttons/stories.png',
                      label: 'Stories',
                      color: _accent,
                    ),
                    _chatNavItem(
                      index: 2,
                      imagePath: 'assets/church/buttons/sacraments.png',
                      label: 'Sacraments',
                      color: _accent,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chatNavItem({
    required int index,
    required String imagePath,
    required String label,
    required Color color,
  }) {
    final bool isSelected = _tabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () async {
          if (_tabIndex == index || _tabSwitching) return; // prevent double tap

          HapticFeedback.selectionClick();
          setState(() {
            _previousTabIndex = _tabIndex; // cache current tab
            _tabSwitching = true;
            _tabIndex = index;
            _selectedMain = 0;
          });

          // Load new tab data
          await _loadMains(_currentSection, force: true);

          // Small delay to show the loaded content before removing overlay
          await Future.delayed(const Duration(milliseconds: 150));

          if (mounted) {
            setState(() => _tabSwitching = false);
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.35 : 1,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: HeavenGlow(
                color: color,
                isSelected: isSelected,
                child: Image.asset(
                  imagePath,
                  height: 50,
                  width: 50,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 3,
              width: 18,
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.8)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Keep labels hidden to match main navbar style; uncomment if needed
            // if (!isSelected)
            //   Text(label,
            //       style: TextStyle(
            //         fontSize: 11,
            //         color: isSelected ? color : Colors.white70,
            //         fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            //       )),
          ],
        ),
      ),
    );
  }

  Widget _journalButton() {
    final Color accent = _accent;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _showJournal ? accent.withValues(alpha: 0.6) : Colors.white12,
        ),
        boxShadow: [
          if (_showJournal)
            BoxShadow(
              color: accent.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _showJournal = !_showJournal),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.menu_book_outlined, color: kGold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _showJournal ? 'Church Notes' : 'Church Notes',
                  style: GoogleFonts.lora(
                    fontSize: 12,
                    color: kGold,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                _showJournal ? Icons.chevron_left : Icons.chevron_right,
                color: kGold,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mainList(List<admin.ChurchMainItem> items) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accent.withValues(alpha: 0.14)),
      ),
      child: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(
          color: Colors.white12,
          indent: 16,
          endIndent: 16,
          height: 1,
        ),
        itemBuilder: (context, i) => _audioTile(items[i], i),
      ),
    );
  }

  // Skeleton placeholder for main list tiles while loading
  Widget _mainSkeletonTile() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _imageSkeleton(),
            Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.black.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: Container(
                  height: 14,
                  width: 160,
                  decoration: BoxDecoration(
                    color: Colors.white10.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _subSkeletonTile() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: Colors.white12, width: 1.0),
        color: Colors.black.withValues(alpha: 0.1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white10.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 12,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white10.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 10,
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.white10.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rightPanel(admin.ChurchMainItem? audio) {
    return Container(
      margin: const EdgeInsets.only(right: 12, top: 12, bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accent.withValues(alpha: 0.14)),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) {
          final slide = Tween<Offset>(
            begin: const Offset(0.02, 0),
            end: Offset.zero,
          ).animate(anim);
          return FadeTransition(
            opacity: anim,
            child: SlideTransition(position: slide, child: child),
          );
        },
        child: (_loading || _mainsNetworkLoading || audio == null)
            ? const SizedBox.shrink()
            : Column(
                key: ValueKey('panel_${audio.id}'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 5),
                    child: Text(
                      audio.title,
                      style: GoogleFonts.lora(
                        fontSize: 14,
                        color: kGold,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  // Row(
                  //   children: [
                  //     _squareThumb(audio.thumbnailUrl),
                  //     const SizedBox(width: 12),
                  //     Expanded(
                  //       child: Column(
                  //         crossAxisAlignment: CrossAxisAlignment.start,
                  //         children: [
                  //           Text(
                  //             audio.title,
                  //             style: GoogleFonts.lora(
                  //               fontSize: 11,
                  //               color: kGold,
                  //               fontWeight: FontWeight.w700,
                  //             ),
                  //             maxLines: 2,
                  //             overflow: TextOverflow.ellipsis,
                  //           ),
                  //           const SizedBox(height: 2),
                  //           if (audio.description != null &&
                  //               audio.description!.trim().isNotEmpty)
                  //             Text(
                  //               audio.description!,
                  //               style: const TextStyle(
                  //                 color: Colors.white70,
                  //                 fontSize: 9,
                  //                 height: 1.2,
                  //               ),
                  //               maxLines: 2,
                  //               overflow: TextOverflow.ellipsis,
                  //             ),
                  //         ],
                  //       ),
                  //     ),
                  //     if (audio.description != null &&
                  //         audio.description!.trim().isNotEmpty)
                  //       IconButton(
                  //         icon: const Icon(
                  //           Icons.info_outline,
                  //           color: kGold,
                  //           size: 22,
                  //         ),
                  //         tooltip: 'Info',
                  //         onPressed: () =>
                  //             _showInfo(context, audio.title, audio.description!),
                  //       ),
                  //     if (audio.audioUrl != null)
                  //       _playBtn(
                  //         url: audio.audioUrl!,
                  //         title: audio.title,
                  //         color: _accent,
                  //         size: 26,
                  //       ),
                  //   ],
                  // ),
                  // const SizedBox(height: 10),
                  if (audio.audioUrl == null)
                    Expanded(
                      child: Builder(
                        builder: (_) {
                          final loading = _subsLoading[audio.id] == true;
                          final items =
                              _subsByMain[audio.id] ??
                              const <admin.ChurchSubItem>[];
                          if (loading && items.isEmpty) {
                            // Sublist skeletons during load
                            return ListView.builder(
                              controller: _subScroll,
                              itemCount: 5,
                              itemBuilder: (_, __) => _subSkeletonTile(),
                            );
                          }
                          if (items.isEmpty) {
                            return const Center(
                              child: Text(
                                'No items yet',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }
                          return ListView.builder(
                            key: ValueKey('list_${audio.id}'),
                            controller: _subScroll,
                            itemCount: items.length,
                            itemBuilder: (_, i) {
                              final delay = 18 * i;
                              return TweenAnimationBuilder<double>(
                                tween: Tween(begin: 8, end: 0),
                                duration: Duration(milliseconds: 160 + delay),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, child) =>
                                    Transform.translate(
                                      offset: Offset(0, value),
                                      child: Opacity(
                                        opacity: (1 - (value / 8)).clamp(
                                          0.0,
                                          1.0,
                                        ),
                                        child: child,
                                      ),
                                    ),
                                child: _subRow(audio, items[i]),
                              );
                            },
                          );
                        },
                      ),
                    )
                  else
                    const Expanded(
                      child: Center(
                        child: Text(
                          'No sub items',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _audioTile(admin.ChurchMainItem audio, int index) {
    final Color accent = _accent;
    final bool selected = index == _selectedMain;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? accent.withValues(alpha: 0.35) : Colors.white12,
        ),
        boxShadow: [
          if (selected)
            BoxShadow(
              color: accent.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              HapticFeedback.selectionClick();
              setState(() => _selectedMain = index);
              if (audio.audioUrl == null) {
                await _ensureSubsLoaded(_currentSection, audio);
                // Smooth scroll sublist to top to signal context change
                if (_subScroll.hasClients) {
                  // Delay to allow list to rebuild
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _subScroll.animateTo(
                      0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                    );
                  });
                }
              } else {
                _playingMain = audio;
                _playingSub = null;
                await _toggleForUrl(audio.audioUrl!, audio.title);
              }
            },
            child: SizedBox(
              height: 120,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background image
                  if (audio.thumbnailUrl != null)
                    CachedNetworkImage(
                      imageUrl: audio.thumbnailUrl!,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 200),
                      placeholder: (_, __) => _imageSkeleton(),
                      errorWidget: (_, __, ___) => _imageFallbackIcon(),
                    )
                  else
                    _imageFallback(),
                  // Subtle selected overlay
                  if (selected)
                    Container(color: accent.withValues(alpha: 0.06)),
                  // Top-right info button (if description available)
                  if (audio.description != null &&
                      audio.description!.trim().isNotEmpty)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        tooltip: 'Info',
                        icon: const Icon(
                          Icons.info_outline,
                          color: kGold,
                          size: 20,
                        ),
                        onPressed: () =>
                            _showInfo(context, audio.title, audio.description!),
                      ),
                    ),
                  // Bottom gradient + title
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.75),
                            Colors.black.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                      child: Text(
                        audio.title,
                        style: GoogleFonts.lora(
                          color: kGold,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  // Bottom-right play/pause button (if playable)
                  if (audio.audioUrl != null)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: IconButton(
                        icon: Icon(
                          _currentKey == audio.audioUrl && _isPlaying
                              ? Icons.pause_circle
                              : Icons.play_circle,
                          color: accent,
                          size: 28,
                        ),
                        onPressed: () async {
                          if (_loadingKey == audio.audioUrl)
                            return; // prevent double taps
                          _playingMain = audio;
                          _playingSub = null;
                          await _toggleForUrl(audio.audioUrl!, audio.title);
                        },
                      ),
                    ),
                  // Loading overlay when starting playback
                  if (_loadingKey != null && _loadingKey == audio.audioUrl)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.45),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 60,
                                child: Image.asset(
                                  'assets/church/logo.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const CircularProgressIndicator(color: kGold),
                              const SizedBox(height: 8),
                              Text(
                                'Loading audio...',
                                style: GoogleFonts.lora(
                                  color: kGold,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _subRow(admin.ChurchMainItem parent, admin.ChurchSubItem s) {
    // Elegant list-style row with minimal padding
    final isPlaying = _currentKey == s.audioUrl && _isPlaying;
    final isLoading = _loadingKey == s.audioUrl;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: isPlaying
              ? _accent.withValues(alpha: 0.4)
              : _accent.withValues(alpha: 0.12),
          width: 1.0,
        ),
        color: isPlaying ? _accent.withValues(alpha: 0.04) : Colors.transparent,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10.0),
          onTap: () async {
            if (isLoading) return;
            HapticFeedback.selectionClick();
            _playingMain = parent;
            _playingSub = s;
            await _toggleForUrl(s.audioUrl, s.title);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 10.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                // Play/pause button with loading indicator
                SizedBox(
                  width: 36,
                  height: 36,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (!isLoading)
                        Icon(
                          isPlaying
                              ? Icons.pause_circle
                              : Icons.play_circle_outline,
                          color: _accent,
                          size: 32,
                        ),
                      if (isLoading)
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: _accent,
                            strokeWidth: 2.5,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        s.title,
                        style: GoogleFonts.lora(
                          color: isPlaying ? _accent : kGold,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isLoading)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                            'Loading audio...',
                            style: TextStyle(
                              color: _accent.withValues(alpha: 0.7),
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Info button if description available
                if (s.description != null && s.description!.trim().isNotEmpty)
                  IconButton(
                    tooltip: 'Info',
                    icon: Icon(
                      Icons.info_outline,
                      color: kGold.withValues(alpha: 0.6),
                      size: 18,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onPressed: () =>
                        _showInfo(context, s.title, s.description!),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showInfo(BuildContext context, String title, String description) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kDeepBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _accent.withValues(alpha: 0.22)),
        ),
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: kGold),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.lora(
                  color: kGold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            description,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Close', style: TextStyle(color: kGold)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  // Lightweight shimmer-like skeleton for image placeholders
  Widget _imageSkeleton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white10.withOpacity(0.06),
            Colors.white10.withOpacity(0.12),
          ],
        ),
      ),
    );
  }

  // Fallback gradient tile with icon when image fails or missing
  Widget _imageFallback({bool isSub = false}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withValues(alpha: isSub ? 0.35 : 0.4),
            Colors.black.withValues(alpha: isSub ? 0.15 : 0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          isSub ? Icons.audiotrack : Icons.local_fire_department_rounded,
          color: kGold,
          size: isSub ? 22 : 28,
        ),
      ),
    );
  }

  Widget _imageFallbackIcon() =>
      const Icon(Icons.image_not_supported_outlined, color: Colors.white30);

  // Removed legacy helpers (_playBtn, _squareThumb, _showInfo) as the new UI
  // uses full-bleed image cards with only a bottom title overlay.

  Widget? _playerBar() {
    final a = _nowTitle ?? _playingSub?.title ?? _playingMain?.title;
    if (a == null) return null;
    final Color accent = _accent;
    final thumb = _playingSub?.thumbnailUrl ?? _playingMain?.thumbnailUrl;

    // Radio mode has different UI
    if (_globalRadio.isRadioPlaying || _radioTurningOff) {
      return ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.52),
              border: Border(
                top: BorderSide(
                  color: kGold.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // Radio logo with animation key
                    ClipRRect(
                      key: _radioLogoKey,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 50,
                        height: 50,
                        color: Colors.black.withValues(alpha: 0.3),
                        child: Image.asset(
                          'assets/church/radio/church_radio_logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Title section
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _radioTurningOff
                                ? 'Radio is off. Wait...'
                                : 'You are listening to Jesus New Radio',
                            style: GoogleFonts.lora(
                              color: _radioTurningOff
                                  ? Colors.white54
                                  : Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!_radioTurningOff) ...[
                            const SizedBox(height: 4),
                            Text(
                              _globalRadio.getCurrentTitle(),
                              style: GoogleFonts.lora(
                                color: kGold,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // On/Off button
                    if (!_radioTurningOff)
                      StreamBuilder<ProcessingState>(
                        stream: _player.processingStateStream,
                        builder: (context, snap) {
                          final st = snap.data;
                          final isLoading =
                              st == ProcessingState.loading ||
                              st == ProcessingState.buffering;
                          return SizedBox(
                            width: 50,
                            height: 50,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    _isPlaying
                                        ? Icons.power_settings_new
                                        : Icons.power_settings_new_outlined,
                                    color: _isPlaying ? kGold : Colors.white54,
                                    size: 32,
                                  ),
                                  onPressed: () async {
                                    if (_isPlaying) {
                                      await _turnOffRadioWithAnimation();
                                    } else {
                                      await _player.play();
                                    }
                                  },
                                ),
                                if (isLoading)
                                  const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: kGold,
                                      strokeWidth: 2,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Normal audio mode
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.52),
            border: Border(
              top: BorderSide(
                color: _accent.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Buffered bar + slider
                  StreamBuilder<Duration?>(
                    stream: _player.durationStream,
                    builder: (context, durSnap) {
                      final total = durSnap.data ?? Duration.zero;
                      return StreamBuilder<Duration>(
                        stream: _player.positionStream,
                        builder: (context, posSnap) {
                          final pos = posSnap.data ?? Duration.zero;
                          return StreamBuilder<Duration>(
                            stream: _player.bufferedPositionStream,
                            builder: (context, bufSnap) {
                              final buffered = bufSnap.data ?? Duration.zero;
                              final totalMs = total.inMilliseconds.clamp(
                                0,
                                1 << 31,
                              );
                              final posMs = math.min(
                                pos.inMilliseconds,
                                total.inMilliseconds,
                              );
                              final bufMs = math.min(
                                buffered.inMilliseconds,
                                total.inMilliseconds,
                              );
                              return Column(
                                children: [
                                  SizedBox(
                                    height: 26,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // buffered track behind slider
                                        Positioned.fill(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8.0,
                                            ),
                                            child: LayoutBuilder(
                                              builder: (context, c) {
                                                final w = c.maxWidth;
                                                final bufW = totalMs == 0
                                                    ? 0.0
                                                    : (w * (bufMs / totalMs));
                                                return Stack(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  children: [
                                                    Container(
                                                      height: 2,
                                                      color: Colors.white24,
                                                    ),
                                                    Container(
                                                      height: 2,
                                                      width: bufW,
                                                      color: accent.withValues(
                                                        alpha: 0.35,
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                        // foreground slider
                                        SliderTheme(
                                          data: SliderTheme.of(context).copyWith(
                                            trackHeight: 2.5,
                                            thumbShape:
                                                const RoundSliderThumbShape(
                                                  enabledThumbRadius: 6,
                                                ),
                                            overlayShape:
                                                const RoundSliderOverlayShape(
                                                  overlayRadius: 12,
                                                ),
                                            activeTrackColor: accent,
                                            thumbColor: accent,
                                            inactiveTrackColor:
                                                Colors.transparent,
                                          ),
                                          child: Slider(
                                            value: totalMs == 0
                                                ? 0
                                                : posMs.toDouble(),
                                            min: 0,
                                            max: math.max(
                                              totalMs.toDouble(),
                                              1,
                                            ),
                                            onChanged: (v) => _player.seek(
                                              Duration(milliseconds: v.round()),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6.0,
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          _fmt(pos),
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          _fmt(total),
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 44,
                          height: 44,
                          color: Colors.black.withValues(alpha: 0.2),
                          child: thumb != null
                              ? CachedNetworkImage(
                                  imageUrl: thumb,
                                  fit: BoxFit.cover,
                                  fadeInDuration: const Duration(
                                    milliseconds: 200,
                                  ),
                                  placeholder: (_, __) => _imageSkeleton(),
                                  errorWidget: (_, __, ___) =>
                                      _imageFallbackIcon(),
                                )
                              : Icon(
                                  _globalRadio.isRadioPlaying
                                      ? Icons.radio
                                      : Icons.local_fire_department_rounded,
                                  color: kGold,
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // title
                      Expanded(
                        child: Text(
                          _globalRadio.isRadioPlaying
                              ? _globalRadio.getCurrentTitle()
                              : a,
                          style: GoogleFonts.lora(
                            color: kGold,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // controls
                      if (!_globalRadio.isRadioPlaying)
                        IconButton(
                          tooltip: 'Rewind 10s',
                          icon: const Icon(
                            Icons.replay_10,
                            color: Colors.white70,
                          ),
                          onPressed: () async {
                            final pos = _player.position;
                            final newPos = pos - const Duration(seconds: 10);
                            await _player.seek(
                              newPos < Duration.zero ? Duration.zero : newPos,
                            );
                          },
                        ),
                      // play/pause with loading indicator
                      StreamBuilder<ProcessingState>(
                        stream: _player.processingStateStream,
                        builder: (context, snap) {
                          final st = snap.data;
                          final isLoading =
                              st == ProcessingState.loading ||
                              st == ProcessingState.buffering;
                          return SizedBox(
                            width: 44,
                            height: 44,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    _isPlaying
                                        ? Icons.pause_circle
                                        : Icons.play_circle,
                                    color: accent,
                                    size: 28,
                                  ),
                                  onPressed: () async {
                                    if (_currentKey == null &&
                                        !_globalRadio.isRadioPlaying)
                                      return;
                                    if (_isPlaying) {
                                      await _player.pause();
                                    } else {
                                      await _player.play();
                                    }
                                    if (mounted) setState(() {});
                                  },
                                ),
                                if (isLoading)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: kGold,
                                      strokeWidth: 2,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                      if (!_globalRadio.isRadioPlaying)
                        IconButton(
                          tooltip: 'Forward 10s',
                          icon: const Icon(
                            Icons.forward_10,
                            color: Colors.white70,
                          ),
                          onPressed: () async {
                            final pos = _player.position;
                            final dur = _player.duration ?? Duration.zero;
                            final newPos = pos + const Duration(seconds: 10);
                            await _player.seek(newPos > dur ? dur : newPos);
                            setState(() {});
                          },
                        )
                      else
                        IconButton(
                          tooltip: 'Forward 10s',
                          icon: const Icon(
                            Icons.forward_10,
                            color: Colors.white70,
                          ),
                          onPressed: () async {
                            final pos = _player.position;
                            final total = _player.duration ?? Duration.zero;
                            final newPos = pos + const Duration(seconds: 10);
                            await _player.seek(newPos > total ? total : newPos);
                          },
                        ),
                      // speed (only for non-radio)
                      if (!_globalRadio.isRadioPlaying)
                        TextButton(
                          onPressed: () async {
                            final speeds = <double>[0.75, 1.0, 1.25, 1.5, 2.0];
                            final i = speeds.indexWhere(
                              (v) => (v - _speed).abs() < 0.01,
                            );
                            final next = speeds[(i + 1) % speeds.length];
                            await _player.setSpeed(next);
                            if (mounted) setState(() => _speed = next);
                          },
                          child: Text(
                            '${_speed.toStringAsFixed(2)}x',
                            style: const TextStyle(
                              color: kGold,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _turnOffRadioWithAnimation() async {
    // Show "Radio is off. Wait..." message
    setState(() => _radioTurningOff = true);

    // Wait a moment
    await Future.delayed(const Duration(milliseconds: 800));

    // Get positions for animation
    final RenderBox? logoBox =
        _radioLogoKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? appBarBox =
        _appBarRadioKey.currentContext?.findRenderObject() as RenderBox?;

    if (logoBox != null && appBarBox != null && mounted) {
      final logoPosition = logoBox.localToGlobal(Offset.zero);
      final appBarPosition = appBarBox.localToGlobal(Offset.zero);

      // Create overlay entry for flying animation
      final overlay = Overlay.of(context);
      late OverlayEntry overlayEntry;

      overlayEntry = OverlayEntry(
        builder: (context) => TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
          builder: (context, value, child) {
            final currentX =
                logoPosition.dx + (appBarPosition.dx - logoPosition.dx) * value;
            final currentY =
                logoPosition.dy + (appBarPosition.dy - logoPosition.dy) * value;
            final currentSize =
                50.0 * (1.0 - value * 0.4); // Shrink to 60% size

            return Positioned(
              left: currentX,
              top: currentY,
              child: Opacity(
                opacity: 1.0 - (value * 0.3), // Fade slightly
                child: Container(
                  width: currentSize,
                  height: currentSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
                  child: Image.asset(
                    'assets/church/radio/church_radio_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            );
          },
          onEnd: () {
            overlayEntry.remove();
          },
        ),
      );

      overlay.insert(overlayEntry);
    }

    // Stop radio
    await _globalRadio.stopRadio();

    if (mounted) {
      setState(() {
        _nowTitle = null;
        _radioTurningOff = false;
      });
    }
  }
}
