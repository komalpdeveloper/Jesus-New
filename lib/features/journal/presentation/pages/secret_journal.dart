import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:clientapp/core/theme/palette.dart';
import 'package:clientapp/shared/widgets/cosmic_background.dart';
import 'package:clientapp/features/journal/presentation/pages/edit_journal_entry.dart';
import 'package:clientapp/features/journal/presentation/pages/journal_settings.dart';
import 'package:clientapp/features/journal/presentation/widgets/passcode_lock.dart';
import 'package:clientapp/core/reward/journal/journal_reward_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

class SecretJournal extends StatelessWidget {
  const SecretJournal({super.key});

  @override
  Widget build(BuildContext context) {
    return const PasscodeLock(
      child: _SecretJournalContent(),
    );
  }
}

class _SecretJournalContent extends StatefulWidget {
  const _SecretJournalContent();
  @override
  State<_SecretJournalContent> createState() => _SecretJournalState();
}

class _SecretJournalState extends State<_SecretJournalContent> with SingleTickerProviderStateMixin {
  List<String> entries = [];
  late final AnimationController _pulseCtl;

  @override
  void initState() {
    super.initState();
    _pulseCtl = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    // ignore: cascade_invocations
    _pulseCtl.repeat(reverse: true);
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => entries = prefs.getStringList('journal') ?? []);
  }

  Future<void> _addEntry(String entry) async {
    if (entry.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() => entries.add(entry.trim()));
    await prefs.setStringList('journal', entries);
    
    // Award rings for saving a journal entry
    await JournalRewardService.instance.rewardEntrySaved();
  }

  Future<void> _updateEntry(int index, String entry) async {
    if (entry.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() => entries[index] = entry.trim());
    await prefs.setStringList('journal', entries);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry updated')), 
      );
    }
  }

  Future<void> _deleteEntry(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final removed = entries.removeAt(index);
    setState(() {});
    await prefs.setStringList('journal', entries);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Entry deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              setState(() => entries.insert(index, removed));
              await prefs.setStringList('journal', entries);
            },
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pulseCtl.dispose();
    super.dispose();
  }

  void _showAddSheet() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Sheen(
        child: Container(
          decoration: BoxDecoration(
            color: kRoyalBlue.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            border: Border.all(color: kRoyalBlue),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 24, spreadRadius: 2, offset: Offset(0, -6)),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text("New Entry", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: kRoyalBlue,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kRoyalBlue),
                  ),
                  child: TextField(
                    controller: ctrl,
                    maxLines: 6,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Write your thoughts...",
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
                      backgroundColor: kPurple,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                      shadowColor: kPurple,
                    ),
                    onPressed: () { _addEntry(ctrl.text); Navigator.pop(context); },
                    child: const Text("Save", style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportJournal() async {
    if (entries.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No entries to export')),
        );
      }
      return;
    }

    try {
      final now = DateTime.now();
      final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final fileName = 'journal_export_$timestamp.txt';

      final buffer = StringBuffer();
      buffer.writeln('═══════════════════════════════════════');
      buffer.writeln('        SECRET JOURNAL EXPORT');
      buffer.writeln('═══════════════════════════════════════');
      buffer.writeln('Exported: ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}');
      buffer.writeln('Total Entries: ${entries.length}');
      buffer.writeln('═══════════════════════════════════════\n');

      for (int i = 0; i < entries.length; i++) {
        buffer.writeln('Entry ${i + 1}:');
        buffer.writeln('───────────────────────────────────────');
        buffer.writeln(entries[i]);
        buffer.writeln('\n═══════════════════════════════════════\n');
      }

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(buffer.toString());

      if (!mounted) return;

      // Get the screen size for share position origin (required on iPad)
      final box = context.findRenderObject() as RenderBox?;
      final sharePositionOrigin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null;

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Secret Journal Export',
        text: 'My journal entries exported as text file',
        sharePositionOrigin: sharePositionOrigin,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Journal exported successfully'),
            backgroundColor: kPurple,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importJournal() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.single.path!);
      final content = await file.readAsString();

      // Parse the imported content
      final importedEntries = <String>[];
      final lines = content.split('\n');
      final buffer = StringBuffer();
      bool inEntry = false;

      for (final line in lines) {
        if (line.startsWith('Entry ') && line.contains(':')) {
          if (buffer.isNotEmpty) {
            final entry = buffer.toString().trim();
            if (entry.isNotEmpty && !entry.startsWith('───')) {
              importedEntries.add(entry);
            }
            buffer.clear();
          }
          inEntry = true;
          continue;
        }

        if (line.startsWith('═══') || line.startsWith('───')) {
          continue;
        }

        if (line.contains('SECRET JOURNAL EXPORT') ||
            line.contains('Exported:') ||
            line.contains('Total Entries:')) {
          continue;
        }

        if (inEntry && line.trim().isNotEmpty) {
          buffer.writeln(line);
        }
      }

      // Add the last entry
      if (buffer.isNotEmpty) {
        final entry = buffer.toString().trim();
        if (entry.isNotEmpty) {
          importedEntries.add(entry);
        }
      }

      if (importedEntries.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No valid entries found in file'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Show confirmation dialog
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0F1520),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF162031)),
          ),
          title: const Row(
            children: [
              Icon(Icons.upload_file, color: kGold, size: 28),
              SizedBox(width: 12),
              Text('Import Journal', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Found ${importedEntries.length} entries to import.',
                style: const TextStyle(color: Color(0xFFB3C1D1), fontSize: 15),
              ),
              const SizedBox(height: 12),
              const Text(
                'These entries will be added to your existing journal.',
                style: TextStyle(color: Color(0xFF8B8B92), fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8B8B92))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Import', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Add imported entries
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        entries.addAll(importedEntries);
      });
      await prefs.setStringList('journal', entries);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported ${importedEntries.length} entries'),
            backgroundColor: kPurple,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImportExportMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Sheen(
        child: Container(
          decoration: BoxDecoration(
            color: kRoyalBlue.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            border: Border.all(color: kRoyalBlue),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 24, spreadRadius: 2, offset: Offset(0, -6)),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                const Text(
                  'Import / Export',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kPurple.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.download, color: kPurple),
                  ),
                  title: const Text(
                    'Import from File',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                  subtitle: const Text(
                    'Load entries from a .txt file',
                    style: TextStyle(color: Color(0xFF8B8B92), fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _importJournal();
                  },
                ),
                const Divider(color: Color(0xFF162031), height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kGold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.upload, color: kGold),
                  ),
                  title: const Text(
                    'Export to File',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                  subtitle: const Text(
                    'Save all entries as a .txt file',
                    style: TextStyle(color: Color(0xFF8B8B92), fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _exportJournal();
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepBlack,
      appBar: AppBar(
        title: const Text("Secret Journal"),
        backgroundColor: kRoyalBlue.withValues(alpha: 0.67),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.import_export),
            onPressed: _showImportExportMenu,
            tooltip: 'Import/Export',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const JournalSettings()),
            ),
            tooltip: 'Settings',
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 14, spreadRadius: 2, offset: Offset(0, 6))],
            border: Border(bottom: BorderSide(color: kRoyalBlue)),
          ),
        ),
      ),
      body: CosmicBackground(
        accent: kGold,
        child: entries.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.menu_book_outlined, color: kGold, size: 42),
                    SizedBox(height: 12),
                    Text("No entries yet.", style: TextStyle(color: Colors.white70, fontSize: 16)),
                  ],
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.0, // square tiles
                ),
                itemCount: entries.length,
                itemBuilder: (_, i) {
                  // Show newest first by reversing display order
                  final idx = entries.length - 1 - i;
                  return _JournalCard(
                    text: entries[idx],
                    onEdit: () => _openEditPage(idx, entries[idx]),
                    onDelete: () => _confirmDelete(idx),
                  );
                },
              ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _pulseCtl,
        builder: (_, child) {
          final t = Curves.easeInOut.transform(_pulseCtl.value);
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: kGold.withValues(alpha: 0.4 + 0.2 * t), blurRadius: 20 + 10 * t, spreadRadius: 1 + t),
              ],
            ),
            child: child,
          );
        },
        child: FloatingActionButton(
          backgroundColor: kGold,
          foregroundColor: Colors.black,
          onPressed: _showAddSheet,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _JournalCard extends StatelessWidget {
  final String text;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  const _JournalCard({required this.text, this.onEdit, this.onDelete});
  @override
  Widget build(BuildContext context) {
    return Sheen(
      child: Container(
        decoration: BoxDecoration(
          color: kRoyalBlue,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kRoyalBlue),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tiny accent dot
              Align(
                alignment: Alignment.topLeft,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: kPurple,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: kPurple.withValues(alpha: 0.6), blurRadius: 12, spreadRadius: 1),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Content snippet
              Expanded(
                child: Text(
                  text,
                  maxLines: 12,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, height: 1.3, fontSize: 14.5),
                ),
              ),
              const SizedBox(height: 8),
              // Actions
              if (onEdit != null || onDelete != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onEdit != null)
                      _IconButtonTiny(
                        icon: Icons.edit,
                        tooltip: 'Edit',
                        onTap: onEdit!,
                      ),
                    if (onDelete != null)
                      _IconButtonTiny(
                        icon: Icons.delete_outline,
                        tooltip: 'Delete',
                        onTap: onDelete!,
                        color: kGold,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconButtonTiny extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color? color;
  final VoidCallback onTap;
  const _IconButtonTiny({required this.icon, required this.tooltip, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
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
              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3))],
            ),
            child: Icon(icon, size: 16, color: color ?? const Color(0xFF8B8B92)),
          ),
        ),
      ),
    );
  }
}

extension on _SecretJournalState {
  Future<void> _openEditPage(int index, String current) async {
    final updated = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => JournalEditPage(initialText: current)),
    );
    if (updated != null && updated != current) {
      // Persist change and show feedback
      await _updateEntry(index, updated);
    }
  }

  void _confirmDelete(int index) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F1520),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFF162031))),
          title: const Text('Delete Entry', style: TextStyle(color: Colors.white)),
          content: const Text('Are you sure you want to delete this entry?', style: TextStyle(color: Color(0xFFB3C1D1))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8B8B92))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kGold, foregroundColor: Colors.black),
              onPressed: () { Navigator.pop(ctx); _deleteEntry(index); },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
