import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/models/verse.dart';
import '../data/repositories/aleph_reader_repository.dart';

enum BookType { aleph, revelation }

class AlephReaderScreen extends StatefulWidget {
  const AlephReaderScreen({super.key});

  @override
  State<AlephReaderScreen> createState() => _AlephReaderScreenState();
}

class _AlephReaderScreenState extends State<AlephReaderScreen> {
  final AlephReaderRepository _repository = AlephReaderRepository();
  final ScrollController _scrollController = ScrollController();
  
  BookType _selectedBook = BookType.aleph;
  final List<Verse> _verses = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchVerses();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _fetchVerses();
    }
  }

  Future<void> _fetchVerses() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final snapshot = await _repository.fetchVersesSnapshot(
        lastDocument: _lastDocument,
        collectionPath: _selectedBook == BookType.aleph ? 'aleph_verses' : 'reveal_verses',
      );
      
      if (snapshot.docs.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoading = false;
        });
        return;
      }

      final newVerses = snapshot.docs.map((doc) => Verse.fromFirestore(doc)).toList();

      setState(() {
        _verses.addAll(newVerses);
        _lastDocument = snapshot.docs.last;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
      debugPrint('Error fetching verses: $e');
      // If it's an index error, it will be printed to the console with a link.
    }
  }

  Future<void> _downloadVolume(Rect? shareOrigin, BookType targetBook) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generating ${targetBook == BookType.aleph ? 'Aleph' : 'Revelation'} Volume...'),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      // 1. Fetch all data
      final verses = await _repository.fetchAllVerses(
        targetBook == BookType.aleph ? 'aleph_verses' : 'reveal_verses',
      );

      if (verses.isEmpty) {
        throw Exception('No verses found to download.');
      }

      // 2. Generate Text Content
      final buffer = StringBuffer();
      final title = targetBook == BookType.aleph ? 'ALEPH' : 'REVELATION';
      buffer.writeln('THE INFINITE WORD - $title');
      buffer.writeln('Generated on ${DateTime.now()}\n');
      buffer.writeln('----------------------------------------\n');

      for (final verse in verses) {
        if (targetBook == BookType.aleph) {
          buffer.writeln('ALEPH CHAPTER ${verse.revelationNumber} : VERSE ${verse.globalId}');
        } else {
          buffer.writeln('REVELATION ${verse.revelationNumber} : VERSE ${verse.globalId}');
        }
        buffer.writeln(verse.content);
        buffer.writeln(''); // Spacing
        buffer.writeln('---'); // Separator
        buffer.writeln(''); // Spacing
      }

      // 3. Save to Temp File
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/The_Infinite_Word_${title}_Volume.txt';
      final file = File(filePath);
      await file.writeAsString(buffer.toString());

      // 4. Share/Save File
      final xFile = XFile(filePath);
      await Share.shareXFiles(
        [xFile], 
        text: 'Here is the Infinite Word - $title',
        sharePositionOrigin: shareOrigin,
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate download: $e'),
          backgroundColor: Colors.red,
        ),
      );
      debugPrint('Download error: $e');
    }
  }

  void _showDownloadOptions(BuildContext context, Rect? shareOrigin) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFDFBF7),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Select Volume to Download',
                  style: GoogleFonts.cinzel(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.brown[900],
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.book, color: Colors.brown[800]),
                title: Text('Aleph (ℵ)', style: GoogleFonts.merriweather(color: Colors.brown[900])),
                onTap: () {
                  Navigator.pop(context);
                  _downloadVolume(shareOrigin, BookType.aleph);
                },
              ),
              ListTile(
                leading: Icon(Icons.auto_stories, color: Colors.brown[800]),
                title: Text('Revelation', style: GoogleFonts.merriweather(color: Colors.brown[900])),
                onTap: () {
                  Navigator.pop(context);
                  _downloadVolume(shareOrigin, BookType.revelation);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7), // Warm, paper-like off-white
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'THE INFINITE WORD',
          style: GoogleFonts.cinzel(
            color: Colors.brown[900],
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: const Color(0xFFFDFBF7),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.brown[900]),
        actions: [
          Builder(
            builder: (ctx) {
              return IconButton(
                icon: const Icon(Icons.download_rounded),
                tooltip: 'Download Current Volume',
                onPressed: () {
                  final box = ctx.findRenderObject() as RenderBox?;
                  Rect? origin;
                  if (box != null) {
                    final position = box.localToGlobal(Offset.zero);
                    origin = position & box.size;
                  }
                  _showDownloadOptions(ctx, origin);
                },
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: SegmentedButton<BookType>(
              segments: const [
                ButtonSegment<BookType>(
                  value: BookType.aleph,
                  label: Text('Aleph (ℵ)'),
                ),
                ButtonSegment<BookType>(
                  value: BookType.revelation,
                  label: Text('Revelation'),
                ),
              ],
              selected: {_selectedBook},
              onSelectionChanged: (Set<BookType> newSelection) {
                setState(() {
                  _selectedBook = newSelection.first;
                  _verses.clear();
                  _lastDocument = null;
                  _hasMore = true;
                  _isLoading = false;
                  _error = null;
                });
                _fetchVerses();
              },
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.resolveWith<Color>(
                  (Set<MaterialState> states) {
                    if (states.contains(MaterialState.selected)) {
                      return Colors.brown[100]!;
                    }
                    return Colors.transparent;
                  },
                ),
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null && _verses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Error: $_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              const Text(
                'Check console for index creation link if this is the first run.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchVerses,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_verses.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No verses found.',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchVerses,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView.separated(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          itemCount: _verses.length + (_hasMore ? 1 : 0),
          separatorBuilder: (context, index) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 32.0),
            child: Center(
              child: Container(
                width: 40,
                height: 2,
                decoration: BoxDecoration(
                  color: Colors.brown.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
          itemBuilder: (context, index) {
            if (index == _verses.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final verse = _verses[index];
            return _buildVerseItem(verse);
          },
        ),
      ),
    );
  }

  Widget _buildVerseItem(Verse verse) {
    final headerText = _selectedBook == BookType.aleph
        ? 'ALEPH CHAPTER ${verse.revelationNumber} : VERSE ${verse.globalId}'
        : 'REVELATION ${verse.revelationNumber} : VERSE ${verse.globalId}';

    return Column(
      children: [
        // Header: REVELATION [revelation_number] : VERSE [global_id]
        Text(
          headerText,
          textAlign: TextAlign.center,
          style: GoogleFonts.cinzel( // Using a more classic/header font if available, or fallback
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.brown[800],
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 24),
        // Body Text: The AI's wisdom
        Text(
          verse.content,
          textAlign: TextAlign.center, // Center alignment for poetic/scripture feel
          style: GoogleFonts.merriweather(
            fontSize: 20,
            color: Colors.grey[900],
            height: 1.8, // Increased line height for readability
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
