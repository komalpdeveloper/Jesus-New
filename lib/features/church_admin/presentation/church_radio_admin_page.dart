import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:clientapp/core/theme/palette.dart';
import 'package:clientapp/features/church_admin/data/models/church_models.dart';
import 'package:clientapp/features/church_admin/data/repositories/church_repository.dart';
import 'package:clientapp/features/church_admin/presentation/church_radio_snippets_admin_page.dart';

class ChurchRadioAdminPage extends StatefulWidget {
  const ChurchRadioAdminPage({super.key});

  @override
  State<ChurchRadioAdminPage> createState() => _ChurchRadioAdminPageState();
}

class _ChurchRadioAdminPageState extends State<ChurchRadioAdminPage> {
  final _repository = ChurchRepository();
  List<ChurchRadioTrack> _tracks = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final tracks = await _repository.listRadioTracks();
      setState(() {
        _tracks = tracks;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _addTrack() async {
    // Prevent multiple calls
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

    // file is guaranteed to be non-null here due to earlier checks
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
        title: const Text('Add Radio Track'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Enter track title',
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

    // Variable to hold dialog state setter
    StateSetter? dialogSetState;
    double uploadProgress = 0.0;

    // Show upload progress dialog
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
                    'Uploading Audio...',
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
      await _repository.createRadioTrack(
        title: titleController.text.trim(),
        audioBytes: selectedFile.bytes!,
        onProgress: (progress) {
          uploadProgress = progress;
          // Update dialog
          dialogSetState?.call(() {});
        },
      );

      await _loadTracks();

      if (mounted) {
        Navigator.of(context).pop(); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Track uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close progress dialog
      }
      _showError('Failed to upload: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _deleteTrack(ChurchRadioTrack track) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Track'),
        content: Text('Are you sure you want to delete "${track.title}"?'),
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
      await _repository.deleteRadioTrack(track.id);
      await _loadTracks();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Track deleted')));
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
          'Church Radio Tracks',
          style: GoogleFonts.lora(color: kGold, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: kGold),
            onPressed: _loadTracks,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _addTrack,
        backgroundColor: kGold,
        icon: const Icon(Icons.add, color: kDeepBlack),
        label: Text(
          'Add Track',
          style: TextStyle(color: kDeepBlack, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // Commercials button at the top
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChurchRadioSnippetsAdminPage(),
                ),
              );
            },
            icon: const Icon(Icons.mic, color: kDeepBlack),
            label: Text(
              'Add Commercials',
              style: GoogleFonts.lora(
                color: kDeepBlack,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPurple,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(double.infinity, 56),
            ),
          ),
        ),

        // Info message
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kGold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kGold.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: kGold, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Radio Track Order',
                      style: GoogleFonts.lora(
                        color: kGold,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This order is for admin convenience. When users play Church Radio, these audio tracks will play in random order.',
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

        // Main content
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildContent() {
    if (_loading && _tracks.isEmpty) {
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
              onPressed: _loadTracks,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.radio, color: kGold, size: 64),
            const SizedBox(height: 16),
            Text(
              'No radio tracks yet',
              style: GoogleFonts.lora(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add audio tracks to play in Church Radio',
              style: TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tracks.length,
      itemBuilder: (context, index) {
        final track = _tracks[index];
        return Card(
          color: Colors.black.withValues(alpha: 0.3),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: kGold.withValues(alpha: 0.2),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: kGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              track.title,
              style: GoogleFonts.lora(
                color: kGold,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Order: ${track.order}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteTrack(track),
            ),
          ),
        );
      },
    );
  }
}
