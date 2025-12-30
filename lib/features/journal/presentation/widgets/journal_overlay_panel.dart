// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:clientapp/core/theme/palette.dart';
import 'package:clientapp/shared/widgets/cosmic_background.dart';
import 'package:clientapp/features/journal/presentation/pages/edit_journal_entry.dart';

/// A side overlay panel for quick note-taking.
/// Uses SharedPreferences to persist entries.
/// By default, stores under key 'journal' (same as SecretJournal),
/// but can be overridden via [prefsKey] to maintain a separate journal
/// (e.g., a dedicated Church journal).
class JournalOverlayPanel extends StatefulWidget {
  final VoidCallback? onClose;
  final String prefsKey;
  final String title;
  const JournalOverlayPanel({
    super.key,
    this.onClose,
    this.prefsKey = 'journal',
    this.title = 'Journal',
  });

  @override
  State<JournalOverlayPanel> createState() => _JournalOverlayPanelState();
}

class _JournalOverlayPanelState extends State<JournalOverlayPanel> {
  List<String> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _entries = prefs.getStringList(widget.prefsKey) ?? []);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(widget.prefsKey, _entries);
  }

  Future<void> _addEntry(BuildContext context) async {
    final ctrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Sheen(
        child: SafeArea(
          top: false,
          child: AnimatedPadding(
            // Smoothly adjust for the on-screen keyboard so the editor stays visible
            padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: Container(
              decoration: BoxDecoration(
                color: kRoyalBlue.withValues(alpha: 0.92),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                border: Border.all(color: kRoyalBlue),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 24, spreadRadius: 2, offset: Offset(0, -6)),
                ],
              ),
              child: SingleChildScrollView(
                // Allow the content to move above the keyboard
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'New Note',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: kRoyalBlue,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kRoyalBlue),
                      ),
                      child: TextField(
                        controller: ctrl,
                        autofocus: true,
                        minLines: 5,
                        maxLines: null, // Let it expand/scroll as needed
                        keyboardType: TextInputType.multiline,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Write your thoughts... ',
                          hintStyle: TextStyle(color: Color(0xFF8B8B92)),
                          contentPadding: EdgeInsets.all(12),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kGold,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                          shadowColor: kGold,
                        ),
                        onPressed: () async {
                          final text = ctrl.text.trim();
                          if (text.isNotEmpty) {
                            setState(() => _entries.add(text));
                            await _persist();
                          }
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editEntry(int index) async {
    final current = _entries[index];
    final updated = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => JournalEditPage(initialText: current)),
    );
    if (!mounted) return;
    if (updated != null && updated.trim().isNotEmpty && updated.trim() != current) {
      setState(() => _entries[index] = updated.trim());
      await _persist();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entry updated')));
    }
  }

  Future<void> _deleteEntry(int index) async {
    final removed = _entries.removeAt(index);
    setState(() {});
    await _persist();
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Entry deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            setState(() => _entries.insert(index, removed));
            await prefs.setStringList('journal', _entries);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: kRoyalBlue.withValues(alpha: 0.85),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: kRoyalBlue),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(4, 0))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [kRoyalBlue, kRoyalBlue.withValues(alpha: 0.6)]),
                borderRadius: const BorderRadius.only(topRight: Radius.circular(16)),
                border: const Border(bottom: BorderSide(color: Colors.black, width: 0.5)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.menu_book_outlined, color: kGold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(widget.title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    tooltip: 'New note',
                    onPressed: () => _addEntry(context),
                    icon: const Icon(Icons.add, color: kGold),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: _entries.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.sticky_note_2_outlined, color: kGold),
                          SizedBox(height: 8),
                          Text('No notes yet', style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final idx = _entries.length - 1 - i; // show newest first
                        return _NoteTile(
                          text: _entries[idx],
                          onEdit: () => _editEntry(idx),
                          onDelete: () => _deleteEntry(idx),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  final String text;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _NoteTile({required this.text, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Sheen(
      child: Container(
        decoration: BoxDecoration(
          color: kRoyalBlue,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kRoyalBlue),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                text,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, height: 1.35),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _tinyIconButton(icon: Icons.edit, tooltip: 'Edit', onTap: onEdit),
                  const SizedBox(width: 6),
                  _tinyIconButton(icon: Icons.delete_outline, tooltip: 'Delete', onTap: onDelete, color: kGold),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _tinyIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFF0F1520),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF162031)),
          ),
          child: Icon(icon, size: 16, color: color ?? const Color(0xFF8B8B92)),
        ),
      ),
    );
  }
}
