import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note.dart';

class NotebookService {
  static const String _passcodeKey = 'notebook_passcode';
  static const String _notesKey = 'notebook_notes';

  // Passcode management
  Future<bool> hasPasscode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_passcodeKey);
  }

  Future<void> setPasscode(String passcode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_passcodeKey, passcode);
  }

  Future<bool> verifyPasscode(String passcode) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_passcodeKey);
    return stored == passcode;
  }

  Future<void> changePasscode(String oldPasscode, String newPasscode) async {
    final isValid = await verifyPasscode(oldPasscode);
    if (isValid) {
      await setPasscode(newPasscode);
    } else {
      throw Exception('Invalid old passcode');
    }
  }

  // Notes management
  Future<List<Note>> getNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = prefs.getString(_notesKey);
    if (notesJson == null) return [];

    final List<dynamic> decoded = json.decode(notesJson);
    return decoded.map((json) => Note.fromJson(json)).toList();
  }

  Future<void> saveNotes(List<Note> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(notes.map((note) => note.toJson()).toList());
    await prefs.setString(_notesKey, encoded);
  }

  Future<void> addNote(Note note) async {
    final notes = await getNotes();
    notes.insert(0, note);
    await saveNotes(notes);
  }

  Future<void> updateNote(Note note) async {
    final notes = await getNotes();
    final index = notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      notes[index] = note;
      await saveNotes(notes);
    }
  }

  Future<void> deleteNote(String noteId) async {
    final notes = await getNotes();
    notes.removeWhere((n) => n.id == noteId);
    await saveNotes(notes);
  }
}
