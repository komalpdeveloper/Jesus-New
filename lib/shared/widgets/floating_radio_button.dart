import 'package:flutter/material.dart';
import 'package:clientapp/core/services/global_radio_service.dart';
import 'package:clientapp/core/theme/palette.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:clientapp/main.dart';

/// Draggable floating radio button that appears when radio is playing
class FloatingRadioButton extends StatefulWidget {
  const FloatingRadioButton({super.key});

  @override
  State<FloatingRadioButton> createState() => _FloatingRadioButtonState();
}

class _FloatingRadioButtonState extends State<FloatingRadioButton>
    with SingleTickerProviderStateMixin {
  final _radioService = GlobalRadioService.instance;
  late AnimationController _pulseController;

  // Draggable position (default: center-right, calculated after first frame)
  Offset? _position;
  bool _isPositionLoaded = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Listen to radio state changes
    _radioService.addListener(_onRadioStateChanged);

    // Load saved position
    _loadPosition();
  }

  void _onRadioStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPosition() async {
    final prefs = await SharedPreferences.getInstance();

    final x = prefs.getDouble('radio_button_x');
    final y = prefs.getDouble('radio_button_y');

    if (mounted) {
      setState(() {
        if (x != null && y != null) {
          _position = Offset(x, y);
        }
        _isPositionLoaded = true;
      });
    }
  }

  Future<void> _savePosition() async {
    if (_position == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('radio_button_x', _position!.dx);
    await prefs.setDouble('radio_button_y', _position!.dy);
  }

  @override
  void dispose() {
    _radioService.removeListener(_onRadioStateChanged);
    _pulseController.dispose();
    super.dispose();
  }

  void _showRadioDialog() {
    final context = JesusNewApp.navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kDeepBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: kGold.withValues(alpha: 0.3)),
        ),
        title: Center(
          child: SizedBox(
            height: 80,
            child: Image.asset(
              'assets/church/radio/church_radio_logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _radioService.getCurrentTitle(),
              style: const TextStyle(
                color: kGold,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _radioService.isMuted ? 'Muted' : 'Playing',
              style: TextStyle(
                color: _radioService.isMuted ? Colors.orange : Colors.green,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // Mute/Unmute button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (_radioService.isMuted) {
                    await _radioService.unmute();
                  } else {
                    await _radioService.mute();
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                icon: Icon(
                  _radioService.isMuted ? Icons.volume_up : Icons.volume_off,
                ),
                label: Text(_radioService.isMuted ? 'Unmute' : 'Mute'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _radioService.isMuted
                      ? kGold
                      : Colors.orange,
                  foregroundColor: kDeepBlack,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Stop button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _radioService.stopRadio();
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                icon: const Icon(Icons.stop),
                label: const Text('Stop Radio'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
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

  @override
  Widget build(BuildContext context) {
    if (!_radioService.isRadioPlaying || !_isPositionLoaded) {
      return const SizedBox.shrink();
    }

    final screenSize = MediaQuery.of(context).size;
    final buttonSize = 60.0;

    // Calculate default position (center-right)
    final defaultPosition = Offset(
      screenSize.width - buttonSize - 16, // Right side with padding
      (screenSize.height - buttonSize) / 2, // Vertically centered
    );

    final currentPos = _position ?? defaultPosition;

    // Wrap in Stack to ensure Positioned works correctly
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: currentPos.dx,
          top: currentPos.dy,
          child: GestureDetector(
            onPanUpdate: (details) {
              final startPos = _position ?? defaultPosition;
              setState(() {
                // Update position as user drags
                _position = Offset(
                  (startPos.dx + details.delta.dx).clamp(
                    0,
                    screenSize.width - buttonSize,
                  ),
                  (startPos.dy + details.delta.dy).clamp(
                    0,
                    screenSize.height - buttonSize,
                  ),
                );
              });
            },
            onPanEnd: (_) {
              // Save position when drag ends
              _savePosition();
            },
            onTap: _showRadioDialog,
            child: _buildButton(),
          ),
        ),
      ],
    );
  }

  Widget _buildButton() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (_pulseController.value * 0.1);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: kDeepBlack,
              shape: BoxShape.circle,
              border: Border.all(
                color: _radioService.isMuted ? Colors.orange : kGold,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_radioService.isMuted ? Colors.orange : kGold)
                      .withValues(alpha: 0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              children: [
                Center(
                  child: Image.asset(
                    'assets/church/radio/church_radio_logo.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                ),
                if (_radioService.isMuted)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.volume_off,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
