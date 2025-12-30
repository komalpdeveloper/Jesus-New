import 'package:clientapp/shared/widgets/back_nav_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui';
import 'package:clientapp/features/altar/altar_page.dart';
import 'package:clientapp/features/mountain/presentation/mountain_page.dart';
import 'package:clientapp/features/inventory/presentation/inventory_screen.dart';
import 'package:clientapp/features/bible/presentation/book_list_screen.dart';
import 'package:gif_view/gif_view.dart';

import 'package:clientapp/services/subscription_manager.dart';
import 'package:clientapp/features/paywall/paywall_screen.dart';
import 'package:clientapp/features/temple-healer/cornelius_screen.dart';

class TempleWindowPage extends StatefulWidget {
  const TempleWindowPage({super.key});

  @override
  State<TempleWindowPage> createState() => _TempleWindowPageState();
}

class _TempleWindowPageState extends State<TempleWindowPage> {
  final bool _showLotties = true;
  bool _candleOn = true; // candle toggle state
  bool _isPremium = false; // Premium status

  @override
  void initState() {
    super.initState();
    _checkPremium();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheAssets();
  }

  void _precacheAssets() {
    // Preload heavy assets to ensure smooth fade-in
    precacheImage(const AssetImage('assets/temple/bg.jpg'), context);
    precacheImage(const AssetImage('assets/temple/jeues.gif'), context);
    precacheImage(const AssetImage('assets/temple/altar.gif'), context);
    precacheImage(const AssetImage('assets/temple/mountain.gif'), context);
    precacheImage(const AssetImage('assets/temple/treasure.gif'), context);
    precacheImage(const AssetImage('assets/temple/bible.png'), context);
    precacheImage(const AssetImage('assets/temple/candle_off.gif'), context);
    // Note: candle_on is loaded by GifView, but precaching might help disk read
    precacheImage(const AssetImage('assets/temple/candle_on.gif'), context);
    precacheImage(const AssetImage('assets/temple/candle_btn.png'), context);
    precacheImage(const AssetImage('assets/temple/temple-healer.png'), context);
    precacheImage(const AssetImage('assets/temple/lock.png'), context);
  }

  Future<void> _checkPremium() async {
    final status = await SubscriptionManager.isPremium();
    if (mounted) setState(() => _isPremium = status);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          // Static background image
          Image.asset('assets/temple/bg.jpg', fit: BoxFit.cover),

          // Ambient scrim: darker when candle is OFF, lighter when ON (affects background only)
          if (_showLotties)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeInOutCubic,
              opacity: _candleOn ? 0.0 : 0.55,
              child: IgnorePointer(child: Container(color: Colors.black)),
            ),

          // After video: three large archways and a glowing circle above
          if (_showLotties)
            _ArchwaysScene(candleOn: _candleOn, isPremium: _isPremium),

          // Top-left back button overlay
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: BackNavButton(),
              ),
            ),
          ),

          // Bottom Controls (Healer & Candle)
          if (_showLotties)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const CorneliusTempleHealerScreen(),
                            ),
                          );
                        },
                        child: Image.asset(
                          'assets/temple/temple-healer.png',
                          width: 65,
                          height: 65,
                          fit: BoxFit.contain,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _candleOn = !_candleOn),
                        child: Image.asset(
                          'assets/temple/candle_btn.png',
                          width: 80,
                          height: 80,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ArchwaysScene extends StatelessWidget {
  const _ArchwaysScene({required this.candleOn, required this.isPremium});

  final bool candleOn;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          // Make the three items larger and pack them tighter horizontally
          final sidePadding = width * 0.045; // 4.5% padding on each side
          final gap = width * 0.02; // slightly tighter
          final archWidth = ((width - (sidePadding * 2) - (gap * 2)) / 3).clamp(
            0.0,
            width,
          );

          return Stack(
            children: [
              // Glowing circle above (jeues.gif) - tap to open Church
              Align(
                alignment: const Alignment(0, -0.4195),
                child: SizedBox(
                  height: height * 0.18,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pushNamed('/church'),
                    child: Image.asset(
                      'assets/temple/jeues.gif',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              // ✨ FIXED PART ✨
              // The archways and Bible are now in a Column to ensure the Bible is tappable.
              Align(
                alignment: const Alignment(0, 0.289),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: sidePadding),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Row(
                            children: [
                              const SizedBox(width: 25.6),
                              SizedBox(
                                width: archWidth - 16,
                                child: GestureDetector(
                                  onTap: () {
                                    if (!isPremium) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const PaywallScreen(),
                                        ),
                                      );
                                      return;
                                    }
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const AltarPage(),
                                      ),
                                    );
                                  },
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      isPremium
                                          ? Image.asset(
                                              'assets/temple/altar.gif',
                                              fit: BoxFit.contain,
                                            )
                                          : ImageFiltered(
                                              imageFilter: ImageFilter.blur(
                                                sigmaX: 5.0,
                                                sigmaY: 5.0,
                                              ),
                                              child: ColorFiltered(
                                                colorFilter:
                                                    const ColorFilter.matrix(
                                                      <double>[
                                                        0.2126,
                                                        0.7152,
                                                        0.0722,
                                                        0,
                                                        0,
                                                        0.2126,
                                                        0.7152,
                                                        0.0722,
                                                        0,
                                                        0,
                                                        0.2126,
                                                        0.7152,
                                                        0.0722,
                                                        0,
                                                        0,
                                                        0,
                                                        0,
                                                        0,
                                                        1,
                                                        0,
                                                      ],
                                                    ),
                                                child: Image.asset(
                                                  'assets/temple/altar.gif',
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            ),
                                      if (!isPremium)
                                        Image.asset(
                                          'assets/temple/lock.png',
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.contain,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6.6),
                              Padding(
                                padding: const EdgeInsets.only(top: 4.2),
                                child: SizedBox(
                                  width: archWidth - 14,
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const MountainPage(),
                                        ),
                                      );
                                    },
                                    child: Image.asset(
                                      'assets/temple/mountain.gif',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 3.5),
                              SizedBox(
                                width: archWidth - 16,
                                child: GestureDetector(
                                  onTap: () {
                                    if (!isPremium) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const PaywallScreen(),
                                        ),
                                      );
                                      return;
                                    }
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const InventoryScreen(),
                                      ),
                                    );
                                  },
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      isPremium
                                          ? Image.asset(
                                              'assets/temple/treasure.gif',
                                              fit: BoxFit.contain,
                                            )
                                          : ImageFiltered(
                                              imageFilter: ImageFilter.blur(
                                                sigmaX: 5.0,
                                                sigmaY: 5.0,
                                              ),
                                              child: ColorFiltered(
                                                colorFilter:
                                                    const ColorFilter.matrix(
                                                      <double>[
                                                        0.2126,
                                                        0.7152,
                                                        0.0722,
                                                        0,
                                                        0,
                                                        0.2126,
                                                        0.7152,
                                                        0.0722,
                                                        0,
                                                        0,
                                                        0.2126,
                                                        0.7152,
                                                        0.0722,
                                                        0,
                                                        0,
                                                        0,
                                                        0,
                                                        0,
                                                        1,
                                                        0,
                                                      ],
                                                    ),
                                                child: Image.asset(
                                                  'assets/temple/treasure.gif',
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            ),
                                      if (!isPremium)
                                        Image.asset(
                                          'assets/temple/lock.png',
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.contain,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Candle positioned at bottom-left of the 3 items row
                          Positioned(
                            left: -sidePadding,
                            bottom: -54, // push further down below row
                            child: SizedBox(
                              height: archWidth * 0.5, // smaller candle
                              child: Stack(
                                children: [
                                  // Candle OFF - always rendered
                                  AnimatedOpacity(
                                    duration: const Duration(milliseconds: 400),
                                    opacity: candleOn ? 0.0 : 1.0,
                                    child: Image.asset(
                                      'assets/temple/candle_off.gif',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  // Candle ON - always rendered
                                  AnimatedOpacity(
                                    duration: const Duration(milliseconds: 400),
                                    opacity: candleOn ? 1.0 : 0.0,
                                    child: CandleGif(
                                      key: const ValueKey('left_candle_on'),
                                      asset: 'assets/temple/candle_on.gif',
                                      speed: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Candle positioned at bottom-right of the 3 items row
                          Positioned(
                            right: -sidePadding,
                            bottom: -54, // push further down below row
                            child: SizedBox(
                              height: archWidth * 0.5, // smaller candle
                              child: Stack(
                                children: [
                                  // Candle OFF - always rendered
                                  AnimatedOpacity(
                                    duration: const Duration(milliseconds: 400),
                                    opacity: candleOn ? 0.0 : 1.0,
                                    child: Image.asset(
                                      'assets/temple/candle_off.gif',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  // Candle ON - always rendered
                                  AnimatedOpacity(
                                    duration: const Duration(milliseconds: 400),
                                    opacity: candleOn ? 1.0 : 0.0,
                                    child: CandleGif(
                                      key: const ValueKey('right_candle_on'),
                                      asset: 'assets/temple/candle_on.gif',
                                      speed: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bible button is now here, below the Stack
                    Transform.translate(
                      // This transform recreates the original spacing
                      offset: Offset(0, archWidth * 0.1),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BookListScreen(),
                            ),
                          );
                        },
                        child: Image.asset(
                          'assets/temple/bible.png',
                          height: archWidth,
                          fit: BoxFit.contain,
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
  }
}

// Simple wrapper to play candle GIFs at a controllable speed (approximate 0.5x)
class CandleGif extends StatefulWidget {
  const CandleGif({
    super.key,
    required this.asset,
    this.speed = 1.0, // 1.0 normal, 0.5 half-speed
    this.fit = BoxFit.contain,
  });

  final String asset;
  final double speed;
  final BoxFit fit;

  @override
  State<CandleGif> createState() => _CandleGifState();
}

class _CandleGifState extends State<CandleGif> {
  late GifController _controller;

  int get _frameRate {
    // gif_view defaults to ~15 fps. Scale it by speed and clamp to a sensible range.
    final base = 15.0;
    final rate = (base * widget.speed).clamp(1.0, 60.0);
    return rate.round();
  }

  @override
  void initState() {
    super.initState();
    _controller = GifController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GifView.asset(
      widget.asset,
      controller: _controller,
      frameRate: _frameRate,
      fit: widget.fit,
    );
  }
}
