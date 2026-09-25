import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'note_detail_page.dart';
import 'note_list_page.dart';
import 'note_record.dart';
import 'notes_state.dart';
import 'notes_service.dart';

class NotesHomePage extends StatefulWidget {
  const NotesHomePage({required this.service, super.key});

  final NotesService service;

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
      final notes = await widget.service.loadNotes();
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
          service: widget.service,
          note: note,
        ),
      ),
    );
    if (saved == true && mounted) _reload();
  }

  Future<void> _delete(NoteRecord note) async {
    await widget.service.delete(note.id);
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) => switch (_state) {
        NotesLoading() => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        NotesFailed(:final error) => _NotesFailedView(error: error),
        NotesReady(:final notes) => NoteListPage(
          notes: notes,
          onOpen: _openDetail,
          onCreate: () => _openDetail(null),
          onDelete: _delete,
        ),
      };
}

class _NotesFailedView extends StatelessWidget {
  const _NotesFailedView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(child: Text(l10n.couldNotLoadNotes('$error'))),
    );
  }
}
