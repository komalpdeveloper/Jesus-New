import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/notes_service.dart';
import '../../../core/theme/palette.dart';

class NoteEditorScreen extends StatefulWidget {
  final NoteType noteType;
  final Note? existingNote;
  final String? initialReference;

  const NoteEditorScreen({
    super.key,
    required this.noteType,
    this.existingNote,
    this.initialReference,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _notesService = NotesService();
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingNote != null) {
      _titleController.text = widget.existingNote!.title;
      _contentController.text = widget.existingNote!.content;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) return;

    final now = DateTime.now();
    final note = Note(
      id: widget.existingNote?.id ?? _notesService.generateId(),
      title: title,
      content: content,
      createdAt: widget.existingNote?.createdAt ?? now,
      updatedAt: now,
      type: widget.noteType,
      reference: widget.existingNote?.reference ?? widget.initialReference,
    );

    await _notesService.saveNote(note);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _deleteNote() async {
    if (widget.existingNote == null) return;

    final isMeditation = widget.noteType == NoteType.meditation;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isMeditation ? kRoyalBlue : const Color(0xFF16213E),
        title: const Text('Delete Note?', style: TextStyle(color: Colors.white)),
        content: const Text('This action cannot be undone.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _notesService.deleteNote(widget.existingNote!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMeditation = widget.noteType == NoteType.meditation;
    final accentColor = isMeditation ? kPurple : Colors.amber;
    final bgColor = isMeditation ? kDeepBlack : const Color(0xFF1A1A2E);
    final appBarColor = isMeditation ? Colors.transparent : const Color(0xFF16213E);
    final textColor = Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor.withOpacity(0.7)),
          onPressed: () {
            if (_isDirty) {
              // Could show confirmation dialog here
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          if (widget.existingNote != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _deleteNote,
            ),
          TextButton(
            onPressed: _saveNote,
            child: Text(
              'Save',
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            if (widget.initialReference != null || widget.existingNote?.reference != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  children: [
                    Icon(Icons.bookmark, color: accentColor, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      widget.existingNote?.reference ?? widget.initialReference!,
                      style: TextStyle(color: accentColor, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: _titleController,
              style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'Title',
                hintStyle: TextStyle(color: textColor.withOpacity(0.3)),
                border: InputBorder.none,
              ),
              onChanged: (_) => setState(() => _isDirty = true),
            ),
            Divider(color: textColor.withOpacity(0.1)),
            Expanded(
              child: TextField(
                controller: _contentController,
                style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 16, height: 1.5),
                decoration: InputDecoration(
                  hintText: 'Start writing...',
                  hintStyle: TextStyle(color: textColor.withOpacity(0.3)),
                  border: InputBorder.none,
                ),
                maxLines: null,
                expands: true,
                onChanged: (_) => setState(() => _isDirty = true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
