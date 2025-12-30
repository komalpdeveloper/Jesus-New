import 'dart:convert';
import 'package:flutter/services.dart';

class BibleData {
  static Map<String, dynamic>? _bibleJson;

  static Future<void> loadBible() async {
    if (_bibleJson != null) return;
    final String jsonString = await rootBundle.loadString('assets/bible/bibledoc.json');
    _bibleJson = jsonDecode(jsonString);
  }

  static List<String> getBooks() {
    if (_bibleJson == null) return [];
    return _bibleJson!.keys.toList();
  }

  static List<int> getChapters(String book) {
    if (_bibleJson == null || !_bibleJson!.containsKey(book)) return [];
    final bookData = _bibleJson![book] as Map<String, dynamic>;
    return bookData.keys.map((k) => int.parse(k)).toList()..sort();
  }

  static List<int> getVerses(String book, int chapter) {
    if (_bibleJson == null || !_bibleJson!.containsKey(book)) return [];
    final bookData = _bibleJson![book] as Map<String, dynamic>;
    final chapterKey = chapter.toString();
    if (!bookData.containsKey(chapterKey)) return [];
    final chapterData = bookData[chapterKey] as Map<String, dynamic>;
    return chapterData.keys.map((k) => int.parse(k)).toList()..sort();
  }

  static String getVerseText(String book, int chapter, int verse) {
    if (_bibleJson == null || !_bibleJson!.containsKey(book)) return '';
    final bookData = _bibleJson![book] as Map<String, dynamic>;
    final chapterKey = chapter.toString();
    if (!bookData.containsKey(chapterKey)) return '';
    final chapterData = bookData[chapterKey] as Map<String, dynamic>;
    final verseKey = verse.toString();
    return chapterData[verseKey] ?? '';
  }

  static String getFullChapter(String book, int chapter) {
    final verses = getVerses(book, chapter);
    final buffer = StringBuffer();
    for (final verse in verses) {
      final text = getVerseText(book, chapter, verse);
      buffer.write('$verse. $text ');
    }
    return buffer.toString().trim();
  }
}
