import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:clientapp/core/theme/palette.dart';
import 'package:clientapp/features/church_admin/data/models/church_models.dart';
import 'package:clientapp/features/church_admin/data/repositories/church_repository.dart';

class ChurchRadioSnippetsAdminPage extends StatefulWidget {
  const ChurchRadioSnippetsAdminPage({super.key});

  @override
  State<ChurchRadioSnippetsAdminPage> createState() =>
      _ChurchRadioSnippetsAdminPageState();
}

class _ChurchRadioSnippetsAdminPageState
    extends State<ChurchRadioSnippetsAdminPage> {
  final _repository = ChurchRepository();
  final _audioPlayer = AudioPlayer();
  List<ChurchRadioSnippet> _snippets = [];
  bool _loading = false;
  String? _error;
  String? _playingSnippetId;
  String? _loadingSnippetId;

  @override
  void initState() {
    super.initState();
    _loadSnippets();

    // Listen to player state changes
    _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;

      if (state.processingState == ProcessingState.completed) {
        setState(() {
          _playingSnippetId = null;
          _loadingSnippetId = null;
        });
      } else if (state.processingState == ProcessingState.ready) {
        // Audio is ready
        setState(() {
          _loadingSnippetId = null;
        });
      } else if (state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering) {
        // Keep loading state
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadSnippets() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final snippets = await _repository.listRadioSnippets();
      setState(() {
        _snippets = snippets;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _addSnippet() async {
    if (_loading) return;

    PlatformFile? file;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['mp3', 'm4a', 'aac'],
        withData: true,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      file = result.files.first;
      if (file.bytes == null) {
        _showError('Failed to read file');
        return;
      }
    } catch (e) {
      _showError('Failed to pick file: $e');
      return;
    }

    final selectedFile = file;

    final titleController = TextEditingController(
      text: selectedFile.name
          .replaceAll('.mp3', '')
          .replaceAll('.m4a', '')
          .replaceAll('.aac', ''),
    );

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Radio Snippet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Enter snippet title',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'File: ${selectedFile.name}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Upload'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;

    StateSetter? dialogSetState;
    double uploadProgress = 0.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: kDeepBlack,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: kGold.withValues(alpha: 0.3)),
          ),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              dialogSetState = setDialogState;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(color: kGold),
                  const SizedBox(height: 24),
                  Text(
                    'Uploading Snippet...',
                    style: GoogleFonts.lora(
                      color: kGold,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please wait, this may take a moment',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: uploadProgress,
                      minHeight: 8,
                      backgroundColor: Colors.white24,
                      color: kGold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(uploadProgress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    setState(() {
      _loading = true;
    });

    try {
      await _repository.createRadioSnippet(
        title: titleController.text.trim(),
        audioBytes: selectedFile.bytes!,
        onProgress: (progress) {
          uploadProgress = progress;
          dialogSetState?.call(() {});
        },
      );

      await _loadSnippets();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Snippet uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      _showError('Failed to upload: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _deleteSnippet(ChurchRadioSnippet snippet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Snippet'),
        content: Text('Are you sure you want to delete "${snippet.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);

    try {
      await _repository.deleteRadioSnippet(snippet.id);
      await _loadSnippets();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Snippet deleted')));
      }
    } catch (e) {
      _showError('Failed to delete: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Church Radio Snippets',
          style: GoogleFonts.lora(color: kGold, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: kGold),
            onPressed: _loadSnippets,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _addSnippet,
        backgroundColor: kGold,
        icon: const Icon(Icons.add, color: kDeepBlack),
        label: Text(
          'Add Snippet',
          style: TextStyle(color: kDeepBlack, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kPurple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kPurple.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: kPurple, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Radio Snippets',
                      style: GoogleFonts.lora(
                        color: kPurple,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'These snippets play initially and after every 3 tracks. One random snippet is selected each time.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildContent() {
    if (_loading && _snippets.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: kGold));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'Error: $_error',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSnippets,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_snippets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic, color: kGold, size: 64),
            const SizedBox(height: 16),
            Text(
              'No radio snippets yet',
              style: GoogleFonts.lora(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add audio snippets to play between tracks',
              style: TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _snippets.length,
      itemBuilder: (context, index) {
        final snippet = _snippets[index];
        return Card(
          color: Colors.black.withValues(alpha: 0.3),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: kPurple.withValues(alpha: 0.2),
              child: Icon(Icons.mic, color: kPurple),
            ),
            title: Text(
              snippet.title,
              style: GoogleFonts.lora(
                color: kGold,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Added: ${_formatDate(snippet.createdAt)}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _loadingSnippetId == snippet.id
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: kGold,
                          ),
                        ),
                      )
                    : IconButton(
                        icon: Icon(
                          _playingSnippetId == snippet.id
                              ? Icons.stop_circle
                              : Icons.play_circle_outline,
                          color: _playingSnippetId == snippet.id
                              ? Colors.green
                              : kGold,
                        ),
                        onPressed: () => _playSnippet(snippet),
                        tooltip: _playingSnippetId == snippet.id
                            ? 'Stop'
                            : 'Play',
                      ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteSnippet(snippet),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _playSnippet(ChurchRadioSnippet snippet) async {
    try {
      if (_playingSnippetId == snippet.id) {
        // Stop if already playing
        await _audioPlayer.stop();
        setState(() {
          _playingSnippetId = null;
          _loadingSnippetId = null;
        });
      } else {
        // Stop any currently playing
        if (_playingSnippetId != null) {
          await _audioPlayer.stop();
        }

        // Show loading
        setState(() {
          _loadingSnippetId = snippet.id;
          _playingSnippetId = null;
        });

        final audioSource = AudioSource.uri(
          Uri.parse(snippet.audioUrl),
          tag: MediaItem(
            id: snippet.id,
            album: "Church Radio Snippets",
            title: snippet.title,
            artist: "Church Radio",
          ),
        );

        await _audioPlayer.setAudioSource(audioSource);

        // Set playing immediately after source is set
        setState(() {
          _playingSnippetId = snippet.id;
          _loadingSnippetId = null;
        });

        await _audioPlayer.play();
      }
    } catch (e) {
      setState(() {
        _playingSnippetId = null;
        _loadingSnippetId = null;
      });
      _showError('Failed to play audio: $e');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
