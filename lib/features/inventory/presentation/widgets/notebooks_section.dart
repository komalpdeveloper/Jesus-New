import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/notebook_service.dart';
import '../../models/note.dart';
import 'passcode_dialog.dart';
import 'note_editor_dialog.dart';

class NotebooksSection extends StatefulWidget {
  const NotebooksSection({super.key});

  @override
  State<NotebooksSection> createState() => _NotebooksSectionState();
}

class _NotebooksSectionState extends State<NotebooksSection> {
  final NotebookService _service = NotebookService();
  bool _isUnlocked = false;
  bool _isLoading = true;
  List<Note> _notes = [];

  @override
  void initState() {
    super.initState();
    _checkPasscode();
  }

  Future<void> _checkPasscode() async {
    final hasPasscode = await _service.hasPasscode();
    if (!hasPasscode) {
      // First time - set up passcode
      if (mounted) {
        _showSetupPasscode();
      }
    } else {
      // Ask for passcode
      if (mounted) {
        _showEnterPasscode();
      }
    }
    setState(() => _isLoading = false);
  }

  void _showSetupPasscode() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PasscodeDialog(
        title: 'Set Up Passcode',
        subtitle: 'Create a 4-digit passcode to protect your notes',
        isSetup: true,
        onPasscodeEntered: (passcode) async {
          await _service.setPasscode(passcode);
          setState(() => _isUnlocked = true);
          await _loadNotes();
        },
      ),
    );
  }

  void _showEnterPasscode() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PasscodeDialog(
        title: 'Enter Passcode',
        subtitle: 'Enter your 4-digit passcode',
        isSetup: false,
        onPasscodeEntered: (passcode) async {
          final isValid = await _service.verifyPasscode(passcode);
          if (isValid) {
            setState(() => _isUnlocked = true);
            await _loadNotes();
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Incorrect passcode',
                    style: GoogleFonts.lato(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  backgroundColor: Colors.red.shade900,
                ),
              );
              _showEnterPasscode();
            }
          }
        },
      ),
    );
  }

  Future<void> _loadNotes() async {
    final notes = await _service.getNotes();
    setState(() => _notes = notes);
  }

  void _showChangePasscode() {
    showDialog(
      context: context,
      builder: (context) => PasscodeDialog(
        title: 'Change Passcode',
        subtitle: 'Enter your current passcode',
        isSetup: false,
        onPasscodeEntered: (oldPasscode) async {
          final isValid = await _service.verifyPasscode(oldPasscode);
          if (isValid) {
            if (mounted) {
              Navigator.pop(context);
              _showNewPasscode();
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Incorrect passcode',
                    style: GoogleFonts.lato(color: Colors.white),
                  ),
                  backgroundColor: Colors.red.shade900,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _showNewPasscode() {
    showDialog(
      context: context,
      builder: (context) => PasscodeDialog(
        title: 'New Passcode',
        subtitle: 'Enter your new 4-digit passcode',
        isSetup: true,
        onPasscodeEntered: (newPasscode) async {
          await _service.setPasscode(newPasscode);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Passcode changed successfully',
                  style: GoogleFonts.lato(color: const Color(0xFFD4AF37)),
                  textAlign: TextAlign.center,
                ),
                backgroundColor: const Color(0xFF2C2416),
              ),
            );
          }
        },
      ),
    );
  }

  void _addNote() {
    showDialog(
      context: context,
      builder: (context) => NoteEditorDialog(
        onSave: (title, content) async {
          final note = Note(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: title,
            content: content,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await _service.addNote(note);
          await _loadNotes();
        },
      ),
    );
  }

  void _editNote(Note note) {
    showDialog(
      context: context,
      builder: (context) => NoteEditorDialog(
        note: note,
        onSave: (title, content) async {
          final updated = note.copyWith(
            title: title,
            content: content,
            updatedAt: DateTime.now(),
          );
          await _service.updateNote(updated);
          await _loadNotes();
        },
      ),
    );
  }

  void _deleteNote(Note note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1410),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFD4AF37), width: 2),
        ),
        title: Text(
          'Delete Note',
          style: GoogleFonts.cinzel(
            color: const Color(0xFFD4AF37),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${note.title}"?',
          style: GoogleFonts.lato(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.9),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.lato(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.6),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await _service.deleteNote(note.id);
              await _loadNotes();
              if (mounted) Navigator.pop(context);
            },
            child: Text(
              'Delete',
              style: GoogleFonts.lato(
                color: Colors.red.shade400,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFD4AF37),
        ),
      );
    }

    if (!_isUnlocked) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock,
              size: 64,
              color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Notebooks Locked',
              style: GoogleFonts.cinzel(
                fontSize: 20,
                color: const Color(0xFFD4AF37).withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header with actions
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MY NOTES',
                style: GoogleFonts.cinzel(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFD4AF37),
                  letterSpacing: 2,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.lock_reset, color: Color(0xFFD4AF37)),
                    onPressed: _showChangePasscode,
                    tooltip: 'Change Passcode',
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Color(0xFFD4AF37)),
                    onPressed: _addNote,
                    tooltip: 'Add Note',
                  ),
                ],
              ),
            ],
          ),
        ),
        // Notes list
        Expanded(
          child: _notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.note_add,
                        size: 64,
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No notes yet',
                        style: GoogleFonts.cinzel(
                          fontSize: 18,
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to create your first note',
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    return _buildNoteCard(note);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildNoteCard(Note note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2416).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFD4AF37),
          width: 1.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          note.title,
          style: GoogleFonts.playfairDisplay(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFD4AF37),
            fontStyle: FontStyle.italic,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              note.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.lato(
                fontSize: 14,
                color: const Color(0xFFD4AF37).withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Updated: ${_formatDate(note.updatedAt)}',
              style: GoogleFonts.lato(
                fontSize: 12,
                color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Color(0xFFD4AF37), size: 20),
              onPressed: () => _editNote(note),
            ),
            IconButton(
              icon: Icon(
                Icons.delete,
                color: Colors.red.shade400,
                size: 20,
              ),
              onPressed: () => _deleteNote(note),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
