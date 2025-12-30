import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import 'package:clientapp/core/reward/journal/journal_reward_service.dart';

class NotesService {
  static const String _storageKey = 'user_notes';
  final Uuid _uuid = const Uuid();

  Future<List<Note>> getNotes(NoteType type) async {
    final prefs = await SharedPreferences.getInstance();
    final String? notesJson = prefs.getString(_storageKey);
    if (notesJson == null) return [];

    final List<dynamic> decoded = json.decode(notesJson);
    final List<Note> allNotes = decoded.map((e) => Note.fromMap(e)).toList();
    
    // Filter by type and sort by updated date descending
    final filtered = allNotes.where((n) => n.type == type).toList();
    filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return filtered;
  }

  Future<void> saveNote(Note note) async {
    final prefs = await SharedPreferences.getInstance();
    final String? notesJson = prefs.getString(_storageKey);
    List<Note> allNotes = [];
    
    if (notesJson != null) {
      final List<dynamic> decoded = json.decode(notesJson);
      allNotes = decoded.map((e) => Note.fromMap(e)).toList();
    }

    // Check if update or new
    final index = allNotes.indexWhere((n) => n.id == note.id);
    if (index >= 0) {
      allNotes[index] = note;
    } else {
      allNotes.add(note);
    }

    await prefs.setString(_storageKey, json.encode(allNotes.map((e) => e.toMap()).toList()));
    
    // Award rings for saving a note
    await JournalRewardService.instance.rewardEntrySaved();
  }

  Future<void> deleteNote(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final String? notesJson = prefs.getString(_storageKey);
    if (notesJson == null) return;

    final List<dynamic> decoded = json.decode(notesJson);
    List<Note> allNotes = decoded.map((e) => Note.fromMap(e)).toList();
    
    allNotes.removeWhere((n) => n.id == id);
    
    await prefs.setString(_storageKey, json.encode(allNotes.map((e) => e.toMap()).toList()));
  }

  String generateId() {
    return _uuid.v4();
  }
}
