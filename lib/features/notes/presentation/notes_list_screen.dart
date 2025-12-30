import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';
import '../services/notes_service.dart';
import 'note_editor_screen.dart';
import '../../../core/theme/palette.dart'; // Assuming this exists based on PrayerMode code

class NotesListScreen extends StatefulWidget {
  final NoteType noteType;

  const NotesListScreen({super.key, required this.noteType});

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  final NotesService _notesService = NotesService();
  List<Note> _notes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    final notes = await _notesService.getNotes(widget.noteType);
    if (mounted) {
      setState(() {
        _notes = notes;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteNote(String id) async {
    await _notesService.deleteNote(id);
    _loadNotes();
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final isMeditation = widget.noteType == NoteType.meditation;
    return await showDialog<bool>(
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
    ) ?? false;
  }

  void _openEditor([Note? note]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          noteType: widget.noteType,
          existingNote: note,
        ),
      ),
    );
    _loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.noteType == NoteType.meditation ? 'Meditation Notes' : 'Bible Notes';
    
    // Theme colors based on feature
    final isMeditation = widget.noteType == NoteType.meditation;
    final bgColor = isMeditation ? kDeepBlack : const Color(0xFF1A1A2E);
    final appBarColor = isMeditation ? Colors.transparent : const Color(0xFF16213E);
    final cardColor = isMeditation ? kRoyalBlue.withOpacity(0.5) : const Color(0xFF0F3460);
    final accentColor = isMeditation ? kPurple : Colors.amber;
    final textColor = Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        title: Text(title, style: TextStyle(color: textColor)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor.withOpacity(0.7)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: accentColor,
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : _notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.note_alt_outlined, size: 64, color: textColor.withOpacity(0.2)),
                      const SizedBox(height: 16),
                      Text(
                        'No notes yet',
                        style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    return Dismissible(
                      key: Key(note.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red[900],
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        return await _confirmDelete(context);
                      },
                      onDismissed: (_) => _deleteNote(note.id),
                      child: Card(
                        color: cardColor,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: isMeditation ? BorderSide(color: kRoyalBlue, width: 1) : BorderSide.none,
                        ),
                        child: InkWell(
                          onTap: () => _openEditor(note),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        note.title.isNotEmpty ? note.title : 'Untitled',
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (note.reference != null)
                                          Container(
                                            margin: const EdgeInsets.only(right: 8),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: accentColor.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              note.reference!,
                                              style: TextStyle(
                                                color: accentColor,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        GestureDetector(
                                          onTap: () async {
                                            if (await _confirmDelete(context)) {
                                              _deleteNote(note.id);
                                            }
                                          },
                                          child: Icon(
                                            Icons.delete_outline,
                                            color: Colors.redAccent.withOpacity(0.7),
                                            size: 20,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  note.content,
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.7),
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  DateFormat.yMMMd().add_jm().format(note.updatedAt),
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.4),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
