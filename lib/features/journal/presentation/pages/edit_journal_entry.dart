import 'package:flutter/material.dart';
import 'package:clientapp/core/theme/palette.dart';

class JournalEditPage extends StatefulWidget {
  final String initialText;
  const JournalEditPage({super.key, required this.initialText});

  @override
  State<JournalEditPage> createState() => _JournalEditPageState();
}

class _JournalEditPageState extends State<JournalEditPage> {
  late final TextEditingController _ctrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry cannot be empty')),
      );
      return;
    }
    
    setState(() => _isSaving = true);
    
    // Small delay to show saving state
    await Future.delayed(const Duration(milliseconds: 200));
    
    if (mounted) {
      Navigator.of(context).pop<String>(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepBlack,
      appBar: AppBar(
        title: const Text('Edit Entry'),
        backgroundColor: kRoyalBlue.withValues(alpha: 0.67),
        elevation: 0,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: kGold,
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save', style: TextStyle(color: kGold, fontWeight: FontWeight.w700)),
            ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 14, spreadRadius: 2, offset: Offset(0, 6)),
            ],
            border: Border(bottom: BorderSide(color: kRoyalBlue)),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: kRoyalBlue,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kRoyalBlue),
          ),
          child: TextField(
            controller: _ctrl,
            maxLines: null,
            expands: true,
            style: const TextStyle(color: Colors.white, height: 1.35, fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'Edit your entry...',
              hintStyle: TextStyle(color: Color(0xFF8B8B92)),
              contentPadding: EdgeInsets.all(16),
              border: InputBorder.none,
            ),
          ),
        ),
      ),
    );
  }
}
