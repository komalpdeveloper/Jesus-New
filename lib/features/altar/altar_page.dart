import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:clientapp/shared/widgets/back_nav_button.dart';
import 'package:clientapp/features/inventory/services/dock_service.dart';
import 'package:clientapp/core/services/user_service.dart';
import 'package:clientapp/core/services/purchase_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui' as ui;

// Trail point data class
class TrailPoint {
  final Offset position;
  final DateTime timestamp;

  TrailPoint({required this.position, required this.timestamp});
}

// Custom painter for the light trail effect
class LightTrailPainter extends CustomPainter {
  final List<TrailPoint> trailPoints;
  final double fadeProgress;

  LightTrailPainter({required this.trailPoints, required this.fadeProgress});

  @override
  void paint(Canvas canvas, Size size) {
    if (trailPoints.isEmpty) return;

    final now = DateTime.now();
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw trail segments with gradient opacity
    for (int i = 0; i < trailPoints.length - 1; i++) {
      final point = trailPoints[i];
      final nextPoint = trailPoints[i + 1];

      // Calculate age-based opacity (newer = more opaque)
      final age = now.difference(point.timestamp).inMilliseconds;
      final ageOpacity = (1.0 - (age / 500.0)).clamp(0.0, 1.0);

      // Apply fade out animation
      final finalOpacity = ageOpacity * (1.0 - fadeProgress);

      // Draw multiple layers for glow effect
      // Outer glow (wider, more transparent)
      paint
        ..color = const Color(0xFFFFD700).withValues(alpha: finalOpacity * 0.3)
        ..strokeWidth = 20.0
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10);
      canvas.drawLine(point.position, nextPoint.position, paint);

      // Middle glow
      paint
        ..color = const Color(0xFFFFD700).withValues(alpha: finalOpacity * 0.6)
        ..strokeWidth = 12.0
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5);
      canvas.drawLine(point.position, nextPoint.position, paint);

      // Inner bright core
      paint
        ..color = const Color(0xFFFFFFFF).withValues(alpha: finalOpacity * 0.9)
        ..strokeWidth = 6.0
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2);
      canvas.drawLine(point.position, nextPoint.position, paint);
    }

    // Draw a bright point at the current position
    if (trailPoints.isNotEmpty) {
      final currentPoint = trailPoints.last;
      final glowPaint = Paint()
        ..style = PaintingStyle.fill
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 15);

      // Outer glow
      glowPaint.color = const Color(
        0xFFFFD700,
      ).withValues(alpha: (1.0 - fadeProgress) * 0.4);
      canvas.drawCircle(currentPoint.position, 25, glowPaint);

      // Middle glow
      glowPaint.color = const Color(
        0xFFFFD700,
      ).withValues(alpha: (1.0 - fadeProgress) * 0.7);
      canvas.drawCircle(currentPoint.position, 15, glowPaint);

      // Bright center
      glowPaint.color = const Color(
        0xFFFFFFFF,
      ).withValues(alpha: (1.0 - fadeProgress) * 0.9);
      canvas.drawCircle(currentPoint.position, 8, glowPaint);
    }
  }

  @override
  bool shouldRepaint(LightTrailPainter oldDelegate) {
    return trailPoints != oldDelegate.trailPoints ||
        fadeProgress != oldDelegate.fadeProgress;
  }
}

class AltarPage extends StatefulWidget {
  const AltarPage({super.key});

  @override
  State<AltarPage> createState() => _AltarPageState();
}

class _AltarPageState extends State<AltarPage> with TickerProviderStateMixin {
  bool _isLoading = true;
  int currentRings = 0; // Current rings progress towards next level
  int level = 0; // Current altar level
  static const int maxLevel = 300; // Maximum altar level
  static const int ringsPerLevel = 1000000; // 1 million rings to level up

  final GlobalKey _altarKey = GlobalKey();
  AnimationController? _disappearController;
  AnimationController? _transitionController;
  Offset? _dropPosition;
  double _itemScale = 1.0;
  double _itemOpacity = 1.0;
  String? _droppedItemImageUrl;

  // Light trail tracking
  final List<TrailPoint> _trailPoints = [];
  bool _isDragging = false;
  AnimationController? _trailFadeController;

  // Fire animation opacities
  double _normalFireOpacity = 1.0;
  double _mediumFireOpacity = 0.0;
  double _godFireOpacity = 0.0;
  double _normToMedOpacity = 0.0;
  double _medToGodOpacity = 0.0;
  double _normToGodOpacity = 0.0;

  bool _isTransitioning = false;

  // Sacrifice flame effect overlay (Special Normal Fire.webp)
  AnimationController? _sacrificeFlameController;
  double _sacrificeFlameOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeAltar();
  }

  Future<void> _initializeAltar() async {
    try {
      // Load user stats
      try {
        final user = await UserService.instance.getCurrentUser().timeout(
          const Duration(seconds: 10),
        );
        if (mounted && user != null) {
          setState(() {
            currentRings = user.altarRings;
            level = user.altarLevel;
          });
        }
      } catch (e) {
        debugPrint('Error loading user stats: $e');
      }

      // Preload transition assets
      try {
        await _preloadTransitionAssets();
      } catch (e) {
        debugPrint('Error preloading transition assets: $e');
      }

      // Preload dock items
      if (mounted) {
        try {
          final dockItems = DockService.instance.dockItems;
          final validItems = dockItems
              .where((i) => i != null && i.productPngUrl != null)
              .toList();

          await Future.wait(
            validItems.map((item) async {
              if (!mounted) return;
              try {
                await precacheImage(
                  NetworkImage(item!.productPngUrl!),
                  context,
                );
              } catch (e) {
                debugPrint(
                  'Failed to precache dock item ${item?.productPngUrl}: $e',
                );
              }
            }),
          );
        } catch (e) {
          debugPrint('Error preloading dock items: $e');
        }
      }
    } catch (e) {
      debugPrint('Critical error initializing altar: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _preloadTransitionAssets() async {
    if (!mounted) return;

    // Helper to safely precache an image
    Future<void> safePrecache(String assetPath) async {
      if (!mounted) return;
      try {
        await precacheImage(AssetImage(assetPath), context);
      } catch (e) {
        debugPrint('Failed to precache asset $assetPath: $e');
      }
    }

    // Preload all transition videos/images
    // We run them in parallel but handle errors individually so one failure doesn't stop others
    await Future.wait([
      safePrecache('assets/altar/animations/normtomed.webp'),
      safePrecache('assets/altar/animations/medtogod.webp'),
      safePrecache('assets/altar/animations/normtogod.webp'),
      safePrecache('assets/altar/animations/medium Fire.webp'),
      safePrecache('assets/altar/animations/GodFire.webp'),
      safePrecache('assets/altar/animations/Normal Fire.webp'),
      safePrecache('assets/altar/animations/Special Normal Fire.webp'),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Glowing text effect
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [
                    const Color(0xFFFFD700),
                    const Color(0xFFD4AF37),
                    const Color(0xFFFFD700),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ).createShader(bounds),
                child: Text(
                  'Altar being ready...',
                  style: GoogleFonts.cinzel(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Custom loading indicator
              SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  children: [
                    const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFD4AF37),
                        strokeWidth: 2,
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFFFD700,
                              ).withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
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

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.8,
            colors: [
              Color(0xFF4A007D), // Deep purple center
              Color(0xFF2B0057), // Darker purple
              Color(0xFF000000), // Pure black edges
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  // Progress Bar at the top
                  _buildProgressBar(),

                  // Spacer to push altar to center
                  const Spacer(),

                  // Altar in the center
                  _buildAltar(),

                  // Spacer to push item dock to bottom
                  const Spacer(),

                  // Item Dock at the bottom
                  _buildItemDock(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            // Light trail overlay
            if (_isDragging && _trailPoints.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: LightTrailPainter(
                      trailPoints: _trailPoints,
                      fadeProgress: _trailFadeController?.value ?? 0.0,
                    ),
                  ),
                ),
              ),
            // Disappearing item animation overlay (Center on drop position)
            if (_dropPosition != null && _droppedItemImageUrl != null)
              Positioned(
                left: _dropPosition!.dx - 40, // Center the 80x80 image
                top: _dropPosition!.dy - 40,
                child: Transform.scale(
                  scale: _itemScale,
                  child: Opacity(
                    opacity: _itemOpacity,
                    child: Image.network(
                      _droppedItemImageUrl!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox(),
                    ),
                  ),
                ),
              ),
            // Back button overlay
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 6, top: 8),
                child: BackNavButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = (currentRings / ringsPerLevel).clamp(0.0, 1.0);
    final progressPercent = (progress * 100).toInt();

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 50, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Level Indicator
          Padding(
            padding: const EdgeInsets.only(left: 52, bottom: 8),
            child: Text(
              'LEVEL $level',
              style: GoogleFonts.cinzel(
                color: const Color(0xFFFFD700),
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                shadows: [
                  Shadow(color: Colors.orange.withOpacity(0.5), blurRadius: 10),
                ],
              ),
            ),
          ),
          Row(
            children: [
              // Heart icon
              Image.asset(
                'assets/altar/heart/heart.gif',
                width: 40,
                height: 40,
              ),
              const SizedBox(width: 12),

              // Progress bar
              Expanded(
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF4A007D),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        // Progress fill with glow effect
                        FractionallySizedBox(
                          widthFactor: progress,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4A007D), Color(0xFF7B2CBF)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF7B2CBF,
                                  ).withValues(alpha: 0.6),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                                BoxShadow(
                                  color: const Color(
                                    0xFFFFD700,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Progress text
                        Center(
                          child: Text(
                            '$progressPercent%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAltar() {
    return DragTarget<int>(
      key: _altarKey,
      onWillAcceptWithDetails: (details) {
        final data = details.data;
        return data >= 0 &&
            data < 3 &&
            DockService.instance.dockItems[data] != null;
      },
      onAcceptWithDetails: (details) {
        // Check if the drop position is within the fire area
        if (_isDropInFireArea(details.offset)) {
          _sacrificeItem(details.data, details.offset);
        } else {
          // Item was dropped outside fire - just clear the trail
          debugPrint('❌ Item dropped outside fire area - returning to box');
          HapticFeedback.lightImpact();
        }
      },
      builder: (context, candidateData, rejectedData) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Normal Fire (< 500 rings)
            if (_normalFireOpacity > 0)
              Center(
                child: Opacity(
                  opacity: _normalFireOpacity,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 1.5,
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: Image.asset(
                      'assets/altar/animations/Normal Fire.webp',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

            // Medium Fire (>= 500 rings)
            if (_mediumFireOpacity > 0)
              Center(
                child: Opacity(
                  opacity: _mediumFireOpacity,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 1.5,
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: Image.asset(
                      'assets/altar/animations/medium Fire.webp',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

            // God Fire (>= 10000 rings)
            if (_godFireOpacity > 0)
              Center(
                child: Opacity(
                  opacity: _godFireOpacity,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 1.5,
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: Image.asset(
                      'assets/altar/animations/GodFire.webp',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

            // Transition: Normal to Medium
            if (_normToMedOpacity > 0)
              Center(
                child: Opacity(
                  opacity: _normToMedOpacity,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 1.5,
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: Image.asset(
                      'assets/altar/animations/normtomed.webp',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

            // Transition: Medium to God
            if (_medToGodOpacity > 0)
              Center(
                child: Opacity(
                  opacity: _medToGodOpacity,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 1.5,
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: Image.asset(
                      'assets/altar/animations/medtogod.webp',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

            // Transition: Normal to God (direct jump)
            if (_normToGodOpacity > 0)
              Center(
                child: Opacity(
                  opacity: _normToGodOpacity,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 1.5,
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: Image.asset(
                      'assets/altar/animations/normtogod.webp',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

            // Sacrifice flame overlay (Special Normal Fire) - shows temporarily on sacrifice
            if (_sacrificeFlameOpacity > 0)
              Center(
                child: Opacity(
                  opacity: _sacrificeFlameOpacity,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 1.5,
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: Image.asset(
                      'assets/altar/animations/Special Normal Fire.webp',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _sacrificeItem(int slotIndex, Offset dropPosition) {
    // Haptic feedback on successful sacrifice - IMMEDIATELY
    HapticFeedback.mediumImpact();
    debugPrint('🎯 HAPTIC: Successful sacrifice - mediumImpact');

    final item = DockService.instance.dockItems[slotIndex];
    if (item == null) return;

    final rings = item.value * item.quantity;
    final int previousLifetimeRings = level * ringsPerLevel + currentRings;

    // Calculate new level/progress IMMEDIATELY for instant UI update
    int newProgress = currentRings + rings;
    int newLevel = level;
    bool leveledUp = false;

    if (newProgress >= ringsPerLevel && level < maxLevel) {
      final levelsGained = newProgress ~/ ringsPerLevel;
      newLevel = (level + levelsGained).clamp(0, maxLevel);

      // If we hit max level, set progress to 0 and don't carry over excess
      if (newLevel >= maxLevel) {
        newLevel = maxLevel;
        newProgress = 0;
      } else {
        newProgress = newProgress % ringsPerLevel;
      }
      leveledUp = true;
    } else if (level >= maxLevel) {
      // Already at max level, don't add progress
      newProgress = 0;
    }

    // Clear the item slot immediately
    DockService.instance.removeItem(slotIndex);

    // Persist changes (Remove item from inventory)
    PurchaseService.instance.sacrificeItem(item.id, item.quantity);

    // Set up the visual state IMMEDIATELY (synchronously) - includes level/progress
    setState(() {
      _dropPosition = dropPosition;
      _itemScale = 1.0;
      _itemOpacity = 1.0;
      _droppedItemImageUrl = item.productPngUrl;

      // Update level/progress instantly
      currentRings = newProgress;
      level = newLevel;
    });

    final int newLifetimeRings = level * ringsPerLevel + currentRings;

    debugPrint(
      'Sacrificed item worth $rings rings. Level: $level, Progress: $currentRings / $ringsPerLevel',
    );

    // Fire Logic (instant)
    _handleFireTransition(previousLifetimeRings, newLifetimeRings);

    // Trigger flare effect (instant)
    _triggerFlareEffect();

    // Celebration if Leveled Up (instant)
    if (leveledUp) {
      _showLevelUpCelebration();
    }

    // Start item disappear animation immediately (fast)
    _disappearController?.dispose();
    _disappearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300), // Faster animation
    );

    _disappearController!.addListener(() {
      if (mounted) {
        setState(() {
          _itemScale = 1.0 - _disappearController!.value;
          _itemOpacity = 1.0 - _disappearController!.value;
        });
      }
    });

    _disappearController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _dropPosition = null;
          });
        }
      }
    });

    _disappearController!.forward(from: 0.0);

    // Call service to update Altar Stats in Firestore (async, fire-and-forget)
    UserService.instance.processSacrifice(rings);
  }

  void _showLevelUpCelebration() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Level Up',
      barrierColor: Colors.black.withOpacity(0.8),
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Glowing Level Up Text
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          Color(0xFFFFD700),
                          Colors.white,
                          Color(0xFFFFD700),
                        ],
                      ).createShader(bounds),
                      child: Text(
                        'LEVEL UP!',
                        style: GoogleFonts.orbitron(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              // Level Number
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: value,
                      child: Text(
                        'LEVEL $level',
                        style: GoogleFonts.cinzel(
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFD4AF37),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
              // Continue Button
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFFD4AF37),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(30),
                          color: Colors.black.withOpacity(0.5),
                        ),
                        child: Text(
                          'YHWH',
                          style: GoogleFonts.cinzel(
                            color: Colors.white,
                            fontSize: 18,
                            letterSpacing: 2,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleFireTransition(int previousTotal, int newTotal) {
    if (_isTransitioning) return;

    // Scenario 1: Normal to Medium (crossing 500 threshold)
    if (previousTotal < 500 && newTotal >= 500 && newTotal < 10000) {
      _transitionToMediumFire();
    }
    // Scenario 2: Medium to God (crossing 10000 threshold)
    else if (previousTotal >= 500 &&
        previousTotal < 10000 &&
        newTotal >= 10000) {
      _transitionToGodFire();
    }
    // Scenario 3: Normal to God (direct jump from < 500 to >= 10000)
    else if (previousTotal < 500 && newTotal >= 10000) {
      _transitionNormalToGod();
    }
  }

  void _triggerFlareEffect() {
    _sacrificeFlameController?.dispose();
    _sacrificeFlameController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 2800,
      ), // Extended to show full animation
    );

    _sacrificeFlameController!.addListener(() {
      setState(() {
        final value = _sacrificeFlameController!.value;
        if (value < 0.1) {
          // Ultra-smooth fade in (0.0 - 0.1 = 280ms) using cubic ease-out
          final progress = value / 0.1;
          // Cubic ease-out for ultra-smooth appearance
          final eased =
              1.0 - (1.0 - progress) * (1.0 - progress) * (1.0 - progress);
          _sacrificeFlameOpacity = eased;
        } else if (value < 0.7) {
          // Hold at full opacity to let the animation play naturally (0.1 - 0.7 = 1680ms)
          _sacrificeFlameOpacity = 1.0;
        } else {
          // Ultra-smooth fade out (0.7 - 1.0 = 840ms) using cubic ease-in
          final progress = (value - 0.7) / 0.3;
          // Cubic ease-in for ultra-smooth disappearance
          final eased = 1.0 - (progress * progress * progress);
          _sacrificeFlameOpacity = eased;
        }
      });
    });

    _sacrificeFlameController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _sacrificeFlameOpacity = 0.0;
        });
      }
    });

    _sacrificeFlameController!.forward();
  }

  void _transitionToMediumFire() {
    _isTransitioning = true;

    _transitionController?.dispose();
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5700), // One circle animation
    );

    _transitionController!.addListener(() {
      setState(() {
        final value = _transitionController!.value.clamp(0.0, 1.0);

        if (value < 0.1) {
          // Phase 1: Smooth crossfade from normal fire to transition (0.0 - 0.1 = 300ms)
          final fadeProgress = (value / 0.1).clamp(0.0, 1.0);
          _normalFireOpacity = (1.0 - fadeProgress).clamp(0.0, 1.0);
          _normToMedOpacity = fadeProgress.clamp(0.0, 1.0);
          _mediumFireOpacity = 0.0;
        } else if (value < 0.8) {
          // Phase 2: Show transition animation at 100% opacity (0.1 - 0.8 = 2100ms)
          _normalFireOpacity = 0.0;
          _normToMedOpacity = 1.0;
          _mediumFireOpacity = 0.0;
        } else {
          // Phase 3: Smooth crossfade to medium fire (0.8 - 1.0 = 600ms)
          final fadeProgress = ((value - 0.8) / 0.2).clamp(0.0, 1.0);
          // Use cubic easeInOut for ultra-smooth transition
          final easedProgress = fadeProgress < 0.5
              ? 4 * fadeProgress * fadeProgress * fadeProgress
              : 1 -
                    4 *
                        (1 - fadeProgress) *
                        (1 - fadeProgress) *
                        (1 - fadeProgress);
          _normalFireOpacity = 0.0;
          _normToMedOpacity = (1.0 - easedProgress).clamp(0.0, 1.0);
          _mediumFireOpacity = easedProgress.clamp(0.0, 1.0);
        }
      });
    });

    _transitionController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _normalFireOpacity = 0.0;
          _normToMedOpacity = 0.0;
          _mediumFireOpacity = 1.0;
          _isTransitioning = false;
        });
      }
    });

    _transitionController!.forward();
  }

  void _transitionToGodFire() {
    _isTransitioning = true;

    _transitionController?.dispose();
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7500), // Single animation cycle
    );

    _transitionController!.addListener(() {
      setState(() {
        final value = _transitionController!.value.clamp(0.0, 1.0);

        if (value < 0.05) {
          // Phase 1: Smooth crossfade from medium fire to transition (0.0 - 0.05 = 675ms)
          final fadeProgress = (value / 0.05).clamp(0.0, 1.0);
          _mediumFireOpacity = (1.0 - fadeProgress).clamp(0.0, 1.0);
          _medToGodOpacity = fadeProgress.clamp(0.0, 1.0);
          _godFireOpacity = 0.0;
        } else if (value < 0.87) {
          // Phase 2: Show FULL transition video at 100% opacity (0.05 - 0.87 = 11070ms)
          _mediumFireOpacity = 0.0;
          _medToGodOpacity = 1.0;
          _godFireOpacity = 0.0;
        } else {
          // Phase 3: Ultra smooth long crossfade to god fire (0.87 - 1.0 = 1755ms)
          final fadeProgress = ((value - 0.87) / 0.13).clamp(0.0, 1.0);
          // Use cubic easeInOut for ultra-smooth transition
          final easedProgress = fadeProgress < 0.5
              ? 4 * fadeProgress * fadeProgress * fadeProgress
              : 1 -
                    4 *
                        (1 - fadeProgress) *
                        (1 - fadeProgress) *
                        (1 - fadeProgress);
          _mediumFireOpacity = 0.0;
          _medToGodOpacity = (1.0 - easedProgress).clamp(0.0, 1.0);
          _godFireOpacity = easedProgress.clamp(0.0, 1.0);
        }
      });
    });

    _transitionController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _mediumFireOpacity = 0.0;
          _medToGodOpacity = 0.0;
          _godFireOpacity = 1.0;
          _isTransitioning = false;
        });
      }
    });

    _transitionController!.forward();
  }

  void _transitionNormalToGod() {
    _isTransitioning = true;

    _transitionController?.dispose();
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 11500,
      ), // Extended by 4.5 seconds total
    );

    _transitionController!.addListener(() {
      setState(() {
        final value = _transitionController!.value.clamp(0.0, 1.0);

        if (value < 0.05) {
          // Phase 1: Smooth crossfade from normal fire to transition (0.0 - 0.05 = 575ms)
          final fadeProgress = (value / 0.05).clamp(0.0, 1.0);
          _normalFireOpacity = (1.0 - fadeProgress).clamp(0.0, 1.0);
          _normToGodOpacity = fadeProgress.clamp(0.0, 1.0);
          _godFireOpacity = 0.0;
        } else if (value < 0.87) {
          // Phase 2: Show FULL transition video at 100% opacity (0.05 - 0.87 = 9430ms)
          _normalFireOpacity = 0.0;
          _normToGodOpacity = 1.0;
          _godFireOpacity = 0.0;
        } else {
          // Phase 3: Ultra smooth long crossfade to god fire (0.87 - 1.0 = 1495ms)
          final fadeProgress = ((value - 0.87) / 0.13).clamp(0.0, 1.0);
          // Use cubic easeInOut for ultra-smooth transition
          final easedProgress = fadeProgress < 0.5
              ? 4 * fadeProgress * fadeProgress * fadeProgress
              : 1 -
                    4 *
                        (1 - fadeProgress) *
                        (1 - fadeProgress) *
                        (1 - fadeProgress);
          _normalFireOpacity = 0.0;
          _normToGodOpacity = (1.0 - easedProgress).clamp(0.0, 1.0);
          _godFireOpacity = easedProgress.clamp(0.0, 1.0);
        }
      });
    });

    _transitionController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _normalFireOpacity = 0.0;
          _normToGodOpacity = 0.0;
          _godFireOpacity = 1.0;
          _isTransitioning = false;
        });
      }
    });

    _transitionController!.forward();
  }

  @override
  void dispose() {
    _disappearController?.dispose();
    _transitionController?.dispose();
    _trailFadeController?.dispose();
    _sacrificeFlameController?.dispose();
    super.dispose();
  }

  void _addTrailPoint(Offset position) {
    setState(() {
      _trailPoints.add(
        TrailPoint(position: position, timestamp: DateTime.now()),
      );

      // Keep only recent points (last 500ms)
      final now = DateTime.now();
      _trailPoints.removeWhere(
        (point) => now.difference(point.timestamp).inMilliseconds > 500,
      );
    });
  }

  void _clearTrail() {
    // Fade out the trail smoothly
    _trailFadeController?.dispose();
    _trailFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _trailFadeController!.addListener(() {
      setState(() {
        // Trigger rebuild during fade animation
      });
    });

    _trailFadeController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _trailPoints.clear();
          _isDragging = false;
        });
      }
    });

    _trailFadeController!.forward();
  }

  bool _isDropInFireArea(Offset dropPosition) {
    // Get the altar's render box to determine fire bounds
    final RenderBox? altarBox =
        _altarKey.currentContext?.findRenderObject() as RenderBox?;
    if (altarBox == null) return false;

    // Get the altar's position and size
    final altarPosition = altarBox.localToGlobal(Offset.zero);
    final altarSize = altarBox.size;

    // Define the fire area as a circular region in the center of the altar
    // The fire is roughly 60% of the altar width
    final fireRadius = altarSize.width * 0.3;
    final fireCenter = Offset(
      altarPosition.dx + altarSize.width / 2,
      altarPosition.dy + altarSize.height / 2,
    );

    // Calculate distance from drop position to fire center
    final distance = (dropPosition - fireCenter).distance;

    // Return true if drop is within fire radius
    return distance <= fireRadius;
  }

  Widget _buildItemDock() {
    final screenWidth = MediaQuery.of(context).size.width;
    final dockSize =
        screenWidth * 0.25; // Each dock frame is 25% of screen width

    return ListenableBuilder(
      listenable: DockService.instance,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            height: dockSize * 1.2,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Left dock (high position)
                Positioned(
                  left: 0,
                  bottom: dockSize * 0.15,
                  child: _buildItemSlot(0, dockSize),
                ),
                // Middle dock (low position - directly below altar)
                Positioned(
                  left: screenWidth * 0.5 - dockSize * 0.5 - 20,
                  bottom: 0,
                  child: _buildItemSlot(1, dockSize),
                ),
                // Right dock (high position)
                Positioned(
                  right: 0,
                  bottom: dockSize * 0.15,
                  child: _buildItemSlot(2, dockSize),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemSlot(int index, double size) {
    final item = DockService.instance.dockItems[index];
    final hasItem = item != null;
    final itemImageUrl = item?.productPngUrl;
    final quantity = item?.quantity ?? 0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Layer 1: Base dock frame (500x500)
          SvgPicture.asset(
            'assets/altar/dock/dockframe.svg',
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),

          // Layer 2: DRAGGABLE dockitem in the middle
          if (hasItem && itemImageUrl != null)
            Draggable<int>(
              data: index,
              onDragStarted: () {
                // Haptic feedback on item pick-up
                HapticFeedback.lightImpact();
                debugPrint('👆 HAPTIC: Item picked up - lightImpact');

                // Cancel any ongoing fade animation
                _trailFadeController?.stop();
                _trailFadeController?.dispose();
                _trailFadeController = null;

                setState(() {
                  _isDragging = true;
                  _trailPoints.clear();
                });
              },
              onDragUpdate: (details) {
                _addTrailPoint(details.globalPosition);
              },
              onDragEnd: (details) {
                _clearTrail();
              },
              onDraggableCanceled: (velocity, offset) {
                // Haptic feedback on canceled sacrifice
                HapticFeedback.lightImpact();
                debugPrint('❌ HAPTIC: Sacrifice canceled - lightImpact');
                _clearTrail();
              },
              feedback: Transform.translate(
                offset: const Offset(0, -20),
                child: Opacity(
                  opacity: 0.8,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.network(
                        itemImageUrl,
                        width: size * 0.5,
                        height: size * 0.5,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox(),
                      ),
                      if (quantity > 1)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFD4AF37),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'x$quantity',
                              style: GoogleFonts.cinzel(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              childWhenDragging: Container(),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.translate(
                    offset: const Offset(0, -20),
                    child: Image.network(
                      itemImageUrl,
                      width: size * 0.8,
                      height: size * 0.8,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox(),
                    ),
                  ),
                ],
              ),
            ),

          // Layer 3: Dock frame overlap (500x500)
          IgnorePointer(
            child: SvgPicture.asset(
              'assets/altar/dock/dockframeoverlap.svg',
              width: size,
              height: size,
              fit: BoxFit.contain,
            ),
          ),

          // Layer 4: Quantity Badge (TOP LAYER - overlapping box edge, bottom-right)
          if (hasItem && quantity > 1)
            Positioned(
              bottom: size * 0.05, // Slightly inside
              right: size * 0.05, // Slightly inside
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFD4AF37),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Text(
                  '×$quantity',
                  style: GoogleFonts.cinzel(
                    color: const Color(0xFFD4AF37),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
