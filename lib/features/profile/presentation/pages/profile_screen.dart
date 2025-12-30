import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:clientapp/core/theme/palette.dart';
import 'package:clientapp/core/models/app_user.dart';
import 'package:clientapp/core/services/user_service.dart';
import 'package:clientapp/shared/widgets/cosmic_background.dart';
import 'package:clientapp/features/journal/presentation/pages/secret_journal.dart';
import 'package:clientapp/features/user_chat/services/user_chat_service.dart';

import 'package:clientapp/services/subscription_manager.dart';
import 'package:clientapp/features/settings/presentation/pages/settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _displayNameController;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false; // Track changes
  bool _isPremium = false; // Track subscription status
  AppUser? _user;
  String? _username;
  File? _newProfileImage;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
    _loadData();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _user = await UserService.instance.getCurrentUser();
    if (_user != null) {
      _displayNameController.text = _user!.displayName ?? '';
      _username = await UserChatService().getUsername(_user!.id);

      // Check premium status
      _isPremium = await SubscriptionManager.isPremium();
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _onFieldChanged() {
    final newName = _displayNameController.text.trim();
    final originalName = _user?.displayName ?? '';
    final nameChanged = newName != originalName && newName.isNotEmpty;
    final imageChanged = _newProfileImage != null;

    setState(() {
      _hasChanges = nameChanged || imageChanged;
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _newProfileImage = File(picked.path);
        _hasChanges = true; // Mark as changed
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _user == null) return;

    // Check if uploading image
    if (_newProfileImage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uploading profile image... please wait'),
          duration: Duration(
            seconds: 2,
          ), // Short duration so it doesn't block "Success" later
          backgroundColor: kRoyalBlue,
        ),
      );
    }

    setState(() => _isSaving = true);

    try {
      String? newPhotoUrl;
      if (_newProfileImage != null) {
        newPhotoUrl = await UserService.instance.uploadProfileImage(
          _newProfileImage!,
        );
      }

      await UserService.instance.updateProfile(
        displayName: _displayNameController.text.trim(),
        photoUrl: newPhotoUrl,
      );

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _hasChanges = false; // Reset changes after save
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepBlack,
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.3),
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        title: Text(
          "My Profile",
          style: GoogleFonts.cinzel(color: kGold, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: kGold),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: (_hasChanges && !_isLoading)
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor: kGold.withOpacity(0.4),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          "SAVE CHANGES",
                          style: GoogleFonts.cinzel(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 1,
                          ),
                        ),
                ),
              ),
            )
          : null,
      body: Stack(
        children: [
          const Positioned.fill(child: CosmicBackground(accent: kRoyalBlue)),
          // Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: kGold))
          else
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 120, 24, 40),
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar Section
                    _buildAvatarSection(),
                    const SizedBox(height: 24),

                    // Display Name
                    _buildDisplayNameField(),
                    const SizedBox(height: 8),

                    // Username
                    Text(
                      _username != null ? "@$_username" : "...",
                      style: GoogleFonts.lora(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Subscription Badge
                    _buildSubscriptionBadge(),

                    const SizedBox(height: 32),

                    // Secret Journal Card (below user info)
                    _buildSecretJournalCard(),

                    const SizedBox(height: 32),

                    // Stats Cards Row (at bottom)
                    // Stats Cards Row (at bottom)
                    Row(
                      children: [
                        Expanded(child: _buildRingsCard()),
                        const SizedBox(width: 8),
                        Expanded(child: _buildAltarLevelCard()),
                      ],
                    ),

                    // Extra padding for FAB
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow effect
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: kGold.withValues(alpha: 0.3),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),
          // Avatar
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: kGold, width: 2),
            ),
            child: CircleAvatar(
              radius: 60,
              backgroundColor: kRoyalBlue,
              backgroundImage: _newProfileImage != null
                  ? FileImage(_newProfileImage!)
                  : (_user?.photoUrl != null
                            ? NetworkImage(_user!.photoUrl!)
                            : null)
                        as ImageProvider?,
              child: (_newProfileImage == null && _user?.photoUrl == null)
                  ? Text(
                      _user?.displayName?.isNotEmpty == true
                          ? _user!.displayName![0].toUpperCase()
                          : "U",
                      style: GoogleFonts.cinzel(
                        fontSize: 40,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
          // Edit Badge
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: kGold,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 18,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRingsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kGold.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            "assets/reward/images/ring_gold.webp",
            width: 40,
            height: 40,
          ),
          const SizedBox(height: 8),
          Text(
            "${_user?.ringCount ?? 0}",
            style: GoogleFonts.cinzel(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            "Rings Earned",
            style: GoogleFonts.lora(fontSize: 12, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: _isPremium
            ? kGold.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isPremium ? kGold : Colors.white24,
          width: 1,
        ),
        boxShadow: _isPremium
            ? [
                BoxShadow(
                  color: kGold.withValues(alpha: 0.2),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isPremium ? Icons.star_rounded : Icons.star_outline_rounded,
            color: _isPremium ? kGold : Colors.white54,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            _isPremium ? "PREMIUM MEMBER" : "FREE MEMBER",
            style: GoogleFonts.cinzel(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _isPremium ? kGold : Colors.white70,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAltarLevelCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kGold.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset("assets/altar/heart/heart.gif", width: 40, height: 40),
          const SizedBox(height: 8),
          Text(
            "${_user?.altarLevel ?? 0}",
            style: GoogleFonts.cinzel(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            "Altar Level",
            style: GoogleFonts.lora(fontSize: 12, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildDisplayNameField() {
    return SizedBox(
      width: 200, // Constrain width for a cleaner center look
      child: TextFormField(
        controller: _displayNameController,
        textAlign: TextAlign.center,
        style: GoogleFonts.cinzel(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          hintText: "Display Name",
          hintStyle: GoogleFonts.cinzel(color: Colors.white24),
          border: InputBorder.none, // Transparent look
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white24),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: kGold),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          isDense: true,
        ),
        maxLength: 12,
        buildCounter:
            (
              context, {
              required currentLength,
              required isFocused,
              maxLength,
            }) => null, // Hide counter
        onChanged: (_) => _onFieldChanged(),
        validator: (v) => v!.trim().isEmpty ? "Required" : null,
      ),
    );
  }

  Widget _buildSecretJournalCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SecretJournal()),
        );
      },
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [const Color(0xFF2C2C2C), const Color(0xFF1A1A1A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.white10),
        ),
        child: Stack(
          children: [
            // Background Pattern/Image placeholder
            Positioned(
              right: -20,
              top: -20,
              child: Opacity(
                opacity: 0.1,
                child: Icon(
                  Icons.menu_book_rounded,
                  size: 150,
                  color: Colors.white,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kGold.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: kGold.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.lock_rounded, color: kGold),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Secret Journal",
                        style: GoogleFonts.cinzel(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Your private reflections",
                        style: GoogleFonts.lora(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white24,
                    size: 16,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
