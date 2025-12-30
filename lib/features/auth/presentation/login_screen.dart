import 'dart:io' show Platform;
import 'package:clientapp/core/auth/auth_service.dart';
import 'package:clientapp/core/theme/palette.dart';
import 'package:clientapp/features/auth/presentation/username_screen.dart';
import 'package:clientapp/shared/widgets/cosmic_background.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loadingApple = false;
  bool _appleAvailable = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      SignInWithApple.isAvailable().then((v) {
        if (mounted) setState(() => _appleAvailable = v);
      }).catchError((_) {
        if (mounted) setState(() => _appleAvailable = false);
      });
    }
  }

  Future<void> _handleApple() async {
    setState(() => _loadingApple = true);
    try {
      await AuthService.instance.signInWithApple();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const UsernameScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Unable to sign in with Apple. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loadingApple = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kDeepBlack,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign In Error', style: GoogleFonts.lora(color: Colors.white)),
        content: Text(message, style: GoogleFonts.lora(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: GoogleFonts.lora(color: kPurple)),
          ),
        ],
      ),
    );
  }

  Widget _buildAppleButton() {
    return AnimatedOpacity(
      opacity: _loadingApple ? 0.7 : 1,
      duration: const Duration(milliseconds: 200),
      child: InkWell(
        onTap: _loadingApple ? null : _handleApple,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_loadingApple)
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              else
                const Icon(Icons.apple, color: Colors.black, size: 24),
              const SizedBox(width: 12),
              Text(
                'Continue with Apple',
                style: GoogleFonts.lora(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showApple = (!kIsWeb) && (Platform.isIOS || Platform.isMacOS) && _appleAvailable;

    return Scaffold(
      backgroundColor: kDeepBlack,
      body: CosmicBackground(
        accent: kPurple,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      height: 120,
                      width: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'Welcome Back',
                    style: GoogleFonts.lora(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Continue your spiritual journey',
                    style: GoogleFonts.lora(
                      fontSize: 16,
                      color: Colors.white60,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 60),
                  if (showApple) _buildAppleButton(),
                  if (!showApple) ...[
                    Text(
                      'Apple Sign-In is not available on this device',
                      style: GoogleFonts.lora(color: Colors.white60, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
