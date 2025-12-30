import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class PasscodeDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool isSetup;
  final Function(String) onPasscodeEntered;

  const PasscodeDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isSetup,
    required this.onPasscodeEntered,
  });

  @override
  State<PasscodeDialog> createState() => _PasscodeDialogState();
}

class _PasscodeDialogState extends State<PasscodeDialog> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  String? _firstPasscode;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onDigitEntered(int index, String value) {
    if (value.isNotEmpty) {
      if (index < 3) {
        _focusNodes[index + 1].requestFocus();
      } else {
        // All digits entered
        final passcode = _controllers.map((c) => c.text).join();
        if (widget.isSetup && _firstPasscode == null) {
          // First entry in setup
          _firstPasscode = passcode;
          _clearFields();
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Confirm your passcode',
                style: GoogleFonts.lato(color: const Color(0xFFD4AF37)),
                textAlign: TextAlign.center,
              ),
              backgroundColor: const Color(0xFF2C2416),
              duration: const Duration(seconds: 1),
            ),
          );
        } else if (widget.isSetup && _firstPasscode != null) {
          // Confirmation in setup
          if (passcode == _firstPasscode) {
            Navigator.pop(context);
            widget.onPasscodeEntered(passcode);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Passcodes do not match',
                  style: GoogleFonts.lato(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                backgroundColor: Colors.red.shade900,
                duration: const Duration(seconds: 2),
              ),
            );
            _firstPasscode = null;
            _clearFields();
            setState(() {});
          }
        } else {
          // Normal entry
          Navigator.pop(context);
          widget.onPasscodeEntered(passcode);
        }
      }
    }
  }

  void _clearFields() {
    for (var controller in _controllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1410),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFD4AF37),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock,
              size: 48,
              color: const Color(0xFFD4AF37),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: GoogleFonts.cinzel(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFD4AF37),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _firstPasscode != null ? 'Confirm your passcode' : widget.subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(
                fontSize: 14,
                color: const Color(0xFFD4AF37).withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _buildDigitField(index),
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),
            if (!widget.isSetup)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.lato(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.6),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDigitField(int index) {
    return Container(
      width: 48,
      height: 58,
      decoration: BoxDecoration(
        color: const Color(0xFF2C2416),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFD4AF37),
          width: 2,
        ),
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        obscureText: true,
        style: GoogleFonts.cinzel(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFD4AF37),
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        onChanged: (value) => _onDigitEntered(index, value),
        onTap: () {
          _controllers[index].selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controllers[index].text.length,
          );
        },
      ),
    );
  }
}
