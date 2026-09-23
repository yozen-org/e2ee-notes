import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'encrypted_notes_repository.dart';
import 'note_detail_page.dart';
import 'note_list_page.dart';
import 'notes_state.dart';

class NotesHomePage extends StatefulWidget {
  const NotesHomePage({required this.repository, super.key});

  final EncryptedNotesRepository repository;

  @override
  State<NotesHomePage> createState() => _NotesHomePageState();
}

class _NotesHomePageState extends State<NotesHomePage> {
  NotesState _state = const NotesLoading();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final notes = await widget.repository.loadNotes();
      if (mounted) setState(() => _state = NotesReady(notes));
    } catch (error) {
      if (mounted) setState(() => _state = NotesFailed(error));
    }
  }

  Future<void> _reload() async {
    setState(() => _state = const NotesLoading());
    await _load();
  }

  Future<void> _openDetail(NoteRecord? note) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NoteDetailPage(
          repository: widget.repository,
          note: note,
        ),
      ),
    );
    if (saved == true && mounted) _reload();
  }

  Future<void> _delete(NoteRecord note) async {
    await widget.repository.delete(note.id);
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return switch (_state) {
      NotesLoading() => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      NotesFailed(:final error) => Scaffold(
        body: Center(child: Text(l10n.couldNotLoadNotes('$error'))),
      ),
      NotesReady(:final notes) => NoteListPage(
        notes: notes,
        onEdit: _openDetail,
        onDelete: _delete,
      ),
    };
  }
}
