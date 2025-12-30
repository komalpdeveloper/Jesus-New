import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:clientapp/core/theme/palette.dart';
import 'package:clientapp/shared/widgets/cosmic_background.dart';
import '../widgets/passcode_lock.dart';

class JournalSettings extends StatefulWidget {
  const JournalSettings({super.key});

  @override
  State<JournalSettings> createState() => _JournalSettingsState();
}

class _JournalSettingsState extends State<JournalSettings> {
  static const String _passcodeKey = 'journal_passcode';
  bool _isLoading = true;
  bool _hasPasscode = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final passcode = prefs.getString(_passcodeKey);
    
    setState(() {
      _hasPasscode = passcode != null && passcode.isNotEmpty;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepBlack,
      appBar: AppBar(
        title: const Text('Journal Settings'),
        backgroundColor: kRoyalBlue.withValues(alpha: 0.67),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 14,
                spreadRadius: 2,
                offset: Offset(0, 6),
              ),
            ],
            border: Border(bottom: BorderSide(color: kRoyalBlue)),
          ),
        ),
      ),
      body: CosmicBackground(
        accent: kGold,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: kGold))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSectionTitle('Security'),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    icon: _hasPasscode ? Icons.lock : Icons.lock_open,
                    title: _hasPasscode ? 'Change Passcode' : 'Set Passcode',
                    subtitle: _hasPasscode 
                      ? 'Update your 4-digit passcode'
                      : 'Protect your journal with a 4-digit code',
                    onTap: _setupPasscode,
                  ),
                  if (_hasPasscode) ...[
                    const SizedBox(height: 12),
                    _buildActionCard(
                      icon: Icons.lock_open_outlined,
                      title: 'Remove Passcode',
                      subtitle: 'Disable passcode protection',
                      onTap: _removePasscode,
                      isDestructive: true,
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    return Sheen(
      child: Container(
        decoration: BoxDecoration(
          color: isDestructive ? Colors.red.shade900.withValues(alpha: 0.2) : kRoyalBlue,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDestructive ? Colors.redAccent.withValues(alpha: 0.3) : kRoyalBlue,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDestructive 
                ? Colors.redAccent.withValues(alpha: 0.2)
                : kPurple.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon, 
              color: isDestructive ? Colors.redAccent : kGold, 
              size: 24,
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: isDestructive ? Colors.redAccent : Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF8B8B92), fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right, color: Color(0xFF8B8B92)),
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: kGold,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Future<void> _setupPasscode() async {
    final prefs = await SharedPreferences.getInstance();
    final currentPasscode = prefs.getString(_passcodeKey);
    
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PasscodeSetup(currentPasscode: currentPasscode),
      ),
    );

    if (result == true) {
      await _loadSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentPasscode != null 
                ? 'Passcode changed successfully'
                : 'Passcode set successfully',
            ),
            backgroundColor: kPurple,
          ),
        );
      }
    }
  }

  Future<void> _removePasscode() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1520),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF162031)),
        ),
        title: const Text('Remove Passcode?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Your journal will no longer be protected by a passcode. Anyone with access to your device can view your entries.',
          style: TextStyle(color: Color(0xFFB3C1D1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8B8B92))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_passcodeKey);
      await _loadSettings();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passcode removed'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
