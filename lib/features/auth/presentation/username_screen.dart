import 'package:clientapp/core/theme/palette.dart';
import 'package:clientapp/features/auth/presentation/gender_screen.dart';
import 'package:clientapp/features/auth/services/user_profile_service.dart';
import 'package:clientapp/shared/widgets/cosmic_background.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class UsernameScreen extends StatefulWidget {
  const UsernameScreen({super.key});

  @override
  State<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<UsernameScreen> {
  final _controller = TextEditingController();
  final _displayNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _checking = false;
  bool _initializing = true;
  String? _availabilityMessage;

  @override
  void initState() {
    super.initState();
    _initializeSuggestedUsername();
  }

  Future<void> _initializeSuggestedUsername() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final profile = await UserProfileService.instance.getUserProfile(
          user.uid,
        );
        if (profile != null) {
          final suggested = UserProfileService.instance
              .generateSuggestedUsername(profile.displayName);
          _controller.text = suggested;
          // Check availability of suggested username
          _checkAvailability(suggested);
        }
      }
    } catch (e) {
      debugPrint('[UsernameScreen] Error initializing: $e');
    } finally {
      if (mounted) {
        setState(() => _initializing = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _checkAvailability(String username) async {
    if (username.length < 3) {
      setState(() => _availabilityMessage = null);
      return;
    }

    setState(() => _checking = true);
    final available = await UserProfileService.instance.isUsernameAvailable(
      username,
    );
    if (mounted) {
      setState(() {
        _checking = false;
        _availabilityMessage = available ? '✓ Available' : '✗ Username taken';
      });
    }
  }

  Future<void> _handleContinue() async {
    if (!_formKey.currentState!.validate()) return;

    final username = _controller.text.trim();
    setState(() => _loading = true);

    try {
      final displayName = _displayNameController.text.trim();
      await UserProfileService.instance.updateUsername(
        username,
        displayName: displayName,
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const GenderScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving username: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a username';
    }
    if (value.trim().length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (value.trim().length > 12) {
      return 'Username must be 12 characters or less';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value.trim())) {
      return 'Only letters, numbers, and underscores allowed';
    }
    if (_availabilityMessage?.contains('taken') ?? false) {
      return 'This username is already taken';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(
        backgroundColor: kDeepBlack,
        body: Center(child: CircularProgressIndicator(color: kPurple)),
      );
    }

    return Scaffold(
      backgroundColor: kDeepBlack,
      body: CosmicBackground(
        accent: kPurple,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                const SizedBox(height: 60),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Setup Profile',
                    style: GoogleFonts.lora(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tell us about yourself',
                    style: GoogleFonts.lora(
                      fontSize: 16,
                      color: Colors.white60,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.amber,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Username cannot be changed later',
                        style: GoogleFonts.lora(
                          fontSize: 13,
                          color: Colors.amber,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Display Name Input
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Display Name",
                          style: GoogleFonts.lora(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _displayNameController,
                        style: GoogleFonts.lora(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: 'e.g. John Doe',
                          hintStyle: GoogleFonts.lora(color: Colors.white30),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: kPurple,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? "Name required"
                            : null,
                      ),
                      const SizedBox(height: 20),

                      // Username Input
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Username",
                          style: GoogleFonts.lora(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _controller,
                        style: GoogleFonts.lora(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter username',
                          hintStyle: GoogleFonts.lora(color: Colors.white30),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: kPurple,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Colors.red,
                              width: 2,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Colors.red,
                              width: 2,
                            ),
                          ),
                          suffixIcon: _checking
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: kPurple,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        validator: _validateUsername,
                        onChanged: (value) {
                          _checkAvailability(value.trim());
                        },
                      ),
                    ],
                  ),
                ),
                if (_availabilityMessage != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _availabilityMessage!,
                      style: GoogleFonts.lora(
                        color: _availabilityMessage!.contains('✓')
                            ? Colors.green
                            : Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _handleContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPurple,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Continue',
                            style: GoogleFonts.lora(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
