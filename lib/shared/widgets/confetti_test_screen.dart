import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'confetti_overlay.dart';

/// Test screen to verify confetti animation is working
class ConfettiTestScreen extends StatefulWidget {
  const ConfettiTestScreen({super.key});

  @override
  State<ConfettiTestScreen> createState() => _ConfettiTestScreenState();
}

class _ConfettiTestScreenState extends State<ConfettiTestScreen> {
  final GlobalKey<ConfettiOverlayState> _confettiKey = GlobalKey<ConfettiOverlayState>();

  @override
  Widget build(BuildContext context) {
    return ConfettiOverlay(
      key: _confettiKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text('Confetti Test', style: GoogleFonts.cinzel()),
          backgroundColor: Colors.purple,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Tap the button to test confetti!',
                style: GoogleFonts.lora(color: Colors.white, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () {
                  print('🎊 Test button pressed!');
                  _confettiKey.currentState?.celebrate();
                },
                icon: const Icon(Icons.celebration),
                label: Text('Celebrate!', style: GoogleFonts.cinzel(fontSize: 20)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Check console for debug messages',
                style: GoogleFonts.lora(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
