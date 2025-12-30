import 'package:clientapp/shared/widgets/back_nav_button.dart';
import 'package:clientapp/features/auth/services/user_profile_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

class MountainPage extends StatefulWidget {
  const MountainPage({super.key});

  @override
  State<MountainPage> createState() => _MountainPageState();
}

class _MountainPageState extends State<MountainPage> {
  double _progress = 0.0; // 0.0 = bottom, 1.0 = top
  int _strides = 0;
  final int _totalStrides = 300;
  bool _isGlowing = false;

  late VideoPlayerController _videoController;
  String? _userGender;

  @override
  void initState() {
    super.initState();

    _videoController =
        VideoPlayerController.asset('assets/mountain/background.mp4')
          ..initialize().then((_) {
            if (mounted) {
              _videoController.setLooping(true);
              _videoController.play();
              setState(() {});
            }
          });

    _loadUserGender();
  }

  Future<void> _loadUserGender() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _userGender = 'male'; // Default to male if not logged in
      });
      return;
    }

    final profile = await UserProfileService.instance.getUserProfile(uid);
    if (mounted) {
      setState(() {
        _userGender = profile?.gender ?? 'male'; // Default to male if not set
      });
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  void _moveUp() {
    if (_strides >= _totalStrides) return;

    setState(() {
      _strides++;
      _progress = _strides / _totalStrides;
      _isGlowing = true;
    });

    // Reset glow after short delay
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _isGlowing = false;
        });
      }
    });

    if (_strides == _totalStrides) {
      _showFinishPopup();
    }
  }

  void _resetStrides() {
    setState(() {
      _strides = 0;
      _progress = 0.0;
    });
    Navigator.of(context).pop(); // Close the popup
  }

  void _showFinishPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD4AF37), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You have crossed over to calmness.',
                textAlign: TextAlign.center,
                style: GoogleFonts.cinzel(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _resetStrides,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  'Start Again',
                  style: GoogleFonts.cinzel(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInfoPopup() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip
              .none, // Allow close button to overflow if needed, or just be safe
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'The Bridge',
                    style: GoogleFonts.cinzel(
                      color: const Color(0xFFD4AF37),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Tap the arrow to take a Stride.\n\nBreathe with the rhythm.\n\nComplete 300 Strides in one session to cross over to calmness.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cinzel(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white10,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate person position and size
    // Progress 0.0 = bottom of screen, 1.0 = 60% up the screen
    final double personSize =
        250 - (_progress * 220); // 250px to 30px (very big start)
    final double maxHeight = screenHeight * 0.6; // Stop at 60% of screen height
    final double bottomPosition =
        _progress * maxHeight; // Start at 0 (bottom), end at 60% height
    final double horizontalPosition = screenWidth / 2 - personSize / 2;
    return Scaffold(
      body: Stack(
        children: [
          // Background video
          Positioned.fill(
            child: _videoController.value.isInitialized
                ? SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _videoController.value.size.width,
                        height: _videoController.value.size.height,
                        child: VideoPlayer(_videoController),
                      ),
                    ),
                  )
                : Image.asset(
                    'assets/mountain/background.png',
                    fit: BoxFit.cover,
                  ),
          ),

          // Person climbing
          if (_userGender != null)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              bottom: bottomPosition,
              left: horizontalPosition,
              width: personSize,
              height: personSize,
              child: Image.asset(
                _userGender == 'female'
                    ? 'assets/mountain/woman.png'
                    : 'assets/mountain/man.png',
                fit: BoxFit.contain,
              ),
            ),

          // Back button
          const Positioned(top: 50, left: 10, child: BackNavButton()),

          // Info Button
          Positioned(
            top: 50,
            left: 70, // Placed near Back Button
            child: GestureDetector(
              onTap: _showInfoPopup,
              child: Image.asset(
                'assets/mountain/infoIcon.png',
                width: 40,
                height: 40,
              ),
            ),
          ),

          // Strides Indicator
          Positioned(
            top: 50,
            right: 20,
            child: Text(
              'STRIDES: $_strides / $_totalStrides',
              style: GoogleFonts.cinzel(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  const Shadow(
                    blurRadius: 10.0,
                    color: Colors.black,
                    offset: Offset(2.0, 2.0),
                  ),
                ],
              ),
            ),
          ),

          // Peace Button (The Tapping Button)
          Positioned(
            bottom: 40,
            right: 30,
            child: GestureDetector(
              onTap: _strides < _totalStrides ? _moveUp : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16), // Rounded square
                  boxShadow: _isGlowing
                      ? [
                          BoxShadow(
                            color: const Color(0xFFD4AF37).withOpacity(0.8),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.6),
                            blurRadius: 15,
                            spreadRadius: 5,
                          ),
                        ]
                      : [],
                ),
                child: Image.asset(
                  'assets/mountain/peaceIcon.png',
                  width: 80, // Slightly larger for better tap target
                  height: 80,
                ),
              ),
            ),
          ),

          // Completion Indicator (Optional overlay if needed, but Popup handles it now)
          if (_strides >= _totalStrides)
            const SizedBox.shrink(), // We use the popup instead
        ],
      ),
    );
  }
}
