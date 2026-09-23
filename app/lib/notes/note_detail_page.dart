import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'encrypted_notes_repository.dart';

class NoteDetailPage extends StatefulWidget {
  const NoteDetailPage({
    required this.repository,
    this.note,
    super.key,
  });

  final EncryptedNotesRepository repository;
  final NoteRecord? note;

  @override
  State<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends State<NoteDetailPage> {
  late final TextEditingController _titleController =
      TextEditingController(text: widget.note?.title ?? '');
  late final TextEditingController _bodyController =
      TextEditingController(text: widget.note?.body ?? '');
  bool _saving = false;

  bool get _isNew => widget.note == null;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.repository.save(
        noteId: widget.note?.id,
        title: _titleController.text,
        body: _bodyController.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.couldNotSaveNote('$error'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.newNote : l10n.editNote),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(l10n.encryptAndSave),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.noteTitleLabel),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _bodyController,
                expands: true,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(labelText: l10n.noteBodyLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
