import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:clientapp/core/theme/palette.dart';
import 'package:clientapp/shared/widgets/cosmic_background.dart';
import 'package:clientapp/shared/widgets/back_nav_button.dart';

class PasscodeLock extends StatefulWidget {
  final Widget child;
  
  const PasscodeLock({required this.child, super.key});

  @override
  State<PasscodeLock> createState() => _PasscodeLockState();
}

class _PasscodeLockState extends State<PasscodeLock> {
  static const String _passcodeKey = 'journal_passcode';
  static const String _passcodePromptShownKey = 'journal_passcode_prompt_shown';
  bool _isUnlocked = false;
  bool _isLoading = true;
  bool _hasPasscode = false;
  bool _showFirstTimeSetup = false;

  @override
  void initState() {
    super.initState();
    _checkPasscode();
  }

  Future<void> _checkPasscode() async {
    final prefs = await SharedPreferences.getInstance();
    final passcode = prefs.getString(_passcodeKey);
    final promptShown = prefs.getBool(_passcodePromptShownKey) ?? false;
    
    setState(() {
      _hasPasscode = passcode != null && passcode.isNotEmpty;
      _showFirstTimeSetup = !_hasPasscode && !promptShown;
      _isLoading = false;
      _isUnlocked = !_hasPasscode; // Auto-unlock if no passcode set
    });
  }

  Future<void> _onPasscodeSet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_passcodePromptShownKey, true);
    await _checkPasscode();
  }

  Future<void> _onSkip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_passcodePromptShownKey, true);
    setState(() {
      _isUnlocked = true;
      _showFirstTimeSetup = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: kDeepBlack,
        body: Center(child: CircularProgressIndicator(color: kGold)),
      );
    }

    if (_showFirstTimeSetup) {
      return FirstTimePasscodeSetup(
        onPasscodeSet: _onPasscodeSet,
        onSkip: _onSkip,
      );
    }

    if (_isUnlocked) {
      return widget.child;
    }

    return PasscodeScreen(
      onUnlock: () => setState(() => _isUnlocked = true),
    );
  }
}

class PasscodeScreen extends StatefulWidget {
  final VoidCallback onUnlock;
  
  const PasscodeScreen({required this.onUnlock, super.key});

  @override
  State<PasscodeScreen> createState() => _PasscodeScreenState();
}

class _PasscodeScreenState extends State<PasscodeScreen> {
  static const String _passcodeKey = 'journal_passcode';
  final List<String> _enteredDigits = [];
  bool _isError = false;

  Future<void> _onDigitPressed(String digit) async {
    if (_enteredDigits.length >= 4) return;

    setState(() {
      _enteredDigits.add(digit);
      _isError = false;
    });

    if (_enteredDigits.length == 4) {
      await _verifyPasscode();
    }
  }

  Future<void> _verifyPasscode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPasscode = prefs.getString(_passcodeKey);
    final enteredPasscode = _enteredDigits.join();

    if (enteredPasscode == savedPasscode) {
      widget.onUnlock();
    } else {
      setState(() {
        _isError = true;
        _enteredDigits.clear();
      });
      
      HapticFeedback.vibrate();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incorrect passcode'),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _onBackspace() {
    if (_enteredDigits.isEmpty) return;
    setState(() {
      _enteredDigits.removeLast();
      _isError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepBlack,
      body: CosmicBackground(
        accent: kGold,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  const Icon(Icons.lock_outline, color: kGold, size: 64),
                  const SizedBox(height: 24),
                  const Text(
                    'Enter Passcode',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 48),
                  _buildPasscodeIndicator(),
                  const SizedBox(height: 48),
                  _buildNumpad(),
                  const Spacer(),
                ],
              ),
              Positioned(
                top: 16,
                left: 8,
                child: BackNavButton(
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasscodeIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isFilled = index < _enteredDigits.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled 
              ? (_isError ? Colors.redAccent : kGold)
              : Colors.transparent,
            border: Border.all(
              color: _isError ? Colors.redAccent : kGold,
              width: 2,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildNumpad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          _buildNumpadRow(['1', '2', '3']),
          const SizedBox(height: 16),
          _buildNumpadRow(['4', '5', '6']),
          const SizedBox(height: 16),
          _buildNumpadRow(['7', '8', '9']),
          const SizedBox(height: 16),
          _buildNumpadRow(['', '0', 'back']),
        ],
      ),
    );
  }

  Widget _buildNumpadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((digit) {
        if (digit.isEmpty) {
          return const SizedBox(width: 70, height: 70);
        }
        
        if (digit == 'back') {
          return _buildNumpadButton(
            onTap: _onBackspace,
            child: const Icon(Icons.backspace_outlined, color: kGold, size: 28),
          );
        }
        
        return _buildNumpadButton(
          onTap: () => _onDigitPressed(digit),
          child: Text(
            digit,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNumpadButton({
    required VoidCallback onTap,
    required Widget child,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(35),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: kRoyalBlue.withValues(alpha: 0.5),
          border: Border.all(color: kRoyalBlue),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

class FirstTimePasscodeSetup extends StatefulWidget {
  final VoidCallback onPasscodeSet;
  final VoidCallback onSkip;
  
  const FirstTimePasscodeSetup({
    required this.onPasscodeSet,
    required this.onSkip,
    super.key,
  });

  @override
  State<FirstTimePasscodeSetup> createState() => _FirstTimePasscodeSetupState();
}

class _FirstTimePasscodeSetupState extends State<FirstTimePasscodeSetup> {
  static const String _passcodeKey = 'journal_passcode';
  final List<String> _enteredDigits = [];
  final List<String> _confirmDigits = [];
  bool _isConfirming = false;
  bool _isError = false;

  Future<void> _onDigitPressed(String digit) async {
    if (_isConfirming) {
      if (_confirmDigits.length >= 4) return;
      
      setState(() {
        _confirmDigits.add(digit);
        _isError = false;
      });

      if (_confirmDigits.length == 4) {
        await _verifyAndSave();
      }
    } else {
      if (_enteredDigits.length >= 4) return;
      
      setState(() {
        _enteredDigits.add(digit);
        _isError = false;
      });

      if (_enteredDigits.length == 4) {
        setState(() => _isConfirming = true);
      }
    }
  }

  Future<void> _verifyAndSave() async {
    final passcode = _enteredDigits.join();
    final confirm = _confirmDigits.join();

    if (passcode == confirm) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_passcodeKey, passcode);
      
      if (mounted) {
        widget.onPasscodeSet();
      }
    } else {
      setState(() {
        _isError = true;
        _enteredDigits.clear();
        _confirmDigits.clear();
        _isConfirming = false;
      });
      
      HapticFeedback.vibrate();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passcodes do not match. Try again.'),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _onBackspace() {
    if (_isConfirming) {
      if (_confirmDigits.isEmpty) {
        setState(() {
          _isConfirming = false;
          _enteredDigits.removeLast();
        });
      } else {
        setState(() {
          _confirmDigits.removeLast();
          _isError = false;
        });
      }
    } else {
      if (_enteredDigits.isEmpty) return;
      setState(() {
        _enteredDigits.removeLast();
        _isError = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepBlack,
      appBar: AppBar(
        title: const Text('Protect Your Journal'),
        backgroundColor: kRoyalBlue.withValues(alpha: 0.67),
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: widget.onSkip,
            child: const Text(
              'Skip',
              style: TextStyle(
                color: kGold,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: CosmicBackground(
        accent: kGold,
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Icon(
                _isConfirming ? Icons.check_circle_outline : Icons.lock_outline,
                color: kGold,
                size: 64,
              ),
              const SizedBox(height: 24),
              Text(
                _isConfirming ? 'Confirm Passcode' : 'Set a 4-Digit Passcode',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Keep your journal entries private and secure',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF8B8B92),
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              _buildPasscodeIndicator(),
              const SizedBox(height: 48),
              _buildNumpad(),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasscodeIndicator() {
    final currentDigits = _isConfirming ? _confirmDigits : _enteredDigits;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isFilled = index < currentDigits.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled 
              ? (_isError ? Colors.redAccent : kGold)
              : Colors.transparent,
            border: Border.all(
              color: _isError ? Colors.redAccent : kGold,
              width: 2,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildNumpad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          _buildNumpadRow(['1', '2', '3']),
          const SizedBox(height: 16),
          _buildNumpadRow(['4', '5', '6']),
          const SizedBox(height: 16),
          _buildNumpadRow(['7', '8', '9']),
          const SizedBox(height: 16),
          _buildNumpadRow(['', '0', 'back']),
        ],
      ),
    );
  }

  Widget _buildNumpadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((digit) {
        if (digit.isEmpty) {
          return const SizedBox(width: 70, height: 70);
        }
        
        if (digit == 'back') {
          return _buildNumpadButton(
            onTap: _onBackspace,
            child: const Icon(Icons.backspace_outlined, color: kGold, size: 28),
          );
        }
        
        return _buildNumpadButton(
          onTap: () => _onDigitPressed(digit),
          child: Text(
            digit,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNumpadButton({
    required VoidCallback onTap,
    required Widget child,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(35),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: kRoyalBlue.withValues(alpha: 0.5),
          border: Border.all(color: kRoyalBlue),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

class PasscodeSetup extends StatefulWidget {
  final String? currentPasscode;
  
  const PasscodeSetup({this.currentPasscode, super.key});

  @override
  State<PasscodeSetup> createState() => _PasscodeSetupState();
}

class _PasscodeSetupState extends State<PasscodeSetup> {
  static const String _passcodeKey = 'journal_passcode';
  final List<String> _enteredDigits = [];
  final List<String> _confirmDigits = [];
  bool _isConfirming = false;
  bool _isError = false;

  Future<void> _onDigitPressed(String digit) async {
    if (_isConfirming) {
      if (_confirmDigits.length >= 4) return;
      
      setState(() {
        _confirmDigits.add(digit);
        _isError = false;
      });

      if (_confirmDigits.length == 4) {
        await _verifyAndSave();
      }
    } else {
      if (_enteredDigits.length >= 4) return;
      
      setState(() {
        _enteredDigits.add(digit);
        _isError = false;
      });

      if (_enteredDigits.length == 4) {
        setState(() => _isConfirming = true);
      }
    }
  }

  Future<void> _verifyAndSave() async {
    final passcode = _enteredDigits.join();
    final confirm = _confirmDigits.join();

    if (passcode == confirm) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_passcodeKey, passcode);
      
      if (mounted) {
        Navigator.pop(context, true);
      }
    } else {
      setState(() {
        _isError = true;
        _enteredDigits.clear();
        _confirmDigits.clear();
        _isConfirming = false;
      });
      
      HapticFeedback.vibrate();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passcodes do not match. Try again.'),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _onBackspace() {
    if (_isConfirming) {
      if (_confirmDigits.isEmpty) {
        setState(() {
          _isConfirming = false;
          _enteredDigits.removeLast();
        });
      } else {
        setState(() {
          _confirmDigits.removeLast();
          _isError = false;
        });
      }
    } else {
      if (_enteredDigits.isEmpty) return;
      setState(() {
        _enteredDigits.removeLast();
        _isError = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepBlack,
      appBar: AppBar(
        title: Text(widget.currentPasscode != null ? 'Change Passcode' : 'Set Passcode'),
        backgroundColor: kRoyalBlue.withValues(alpha: 0.67),
        elevation: 0,
      ),
      body: CosmicBackground(
        accent: kGold,
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Icon(
                _isConfirming ? Icons.check_circle_outline : Icons.lock_outline,
                color: kGold,
                size: 64,
              ),
              const SizedBox(height: 24),
              Text(
                _isConfirming ? 'Confirm Passcode' : 'Enter New Passcode',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 48),
              _buildPasscodeIndicator(),
              const SizedBox(height: 48),
              _buildNumpad(),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasscodeIndicator() {
    final currentDigits = _isConfirming ? _confirmDigits : _enteredDigits;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isFilled = index < currentDigits.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled 
              ? (_isError ? Colors.redAccent : kGold)
              : Colors.transparent,
            border: Border.all(
              color: _isError ? Colors.redAccent : kGold,
              width: 2,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildNumpad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          _buildNumpadRow(['1', '2', '3']),
          const SizedBox(height: 16),
          _buildNumpadRow(['4', '5', '6']),
          const SizedBox(height: 16),
          _buildNumpadRow(['7', '8', '9']),
          const SizedBox(height: 16),
          _buildNumpadRow(['', '0', 'back']),
        ],
      ),
    );
  }

  Widget _buildNumpadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((digit) {
        if (digit.isEmpty) {
          return const SizedBox(width: 70, height: 70);
        }
        
        if (digit == 'back') {
          return _buildNumpadButton(
            onTap: _onBackspace,
            child: const Icon(Icons.backspace_outlined, color: kGold, size: 28),
          );
        }
        
        return _buildNumpadButton(
          onTap: () => _onDigitPressed(digit),
          child: Text(
            digit,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNumpadButton({
    required VoidCallback onTap,
    required Widget child,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(35),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: kRoyalBlue.withValues(alpha: 0.5),
          border: Border.all(color: kRoyalBlue),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}
