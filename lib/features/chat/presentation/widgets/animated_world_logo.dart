import 'package:flutter/material.dart';

class AnimatedWorldLogo extends StatefulWidget {
  const AnimatedWorldLogo({super.key});

  @override
  State<AnimatedWorldLogo> createState() => _AnimatedWorldLogoState();
}

class _AnimatedWorldLogoState extends State<AnimatedWorldLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    // Preload the image and start animation once ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadImage();
    });
  }

  void _preloadImage() {
    final imageProvider = const AssetImage('assets/common/world.webp');
    final stream = imageProvider.resolve(ImageConfiguration.empty);

    stream.addListener(
      ImageStreamListener(
        (info, synchronousCall) {
          if (mounted) {
            setState(() => _isLoaded = true);
            _controller.forward();
          }
        },
        onError: (exception, stackTrace) {
          debugPrint('Error loading world image: $exception');
          // Show it anyway if error, to avoid stuck state
          if (mounted) {
            setState(() => _isLoaded = true);
            _controller.forward();
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return const SizedBox(width: 200, height: 200);
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Image.asset(
        'assets/common/world.webp',
        width: 200,
        height: 200,
        fit: BoxFit.contain,
        gaplessPlayback: true,
      ),
    );
  }
}
