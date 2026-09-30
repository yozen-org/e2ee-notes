import 'package:flutter/material.dart';
import 'package:secure_keys/secure_keys.dart';

import '../../l10n/app_localizations.dart';
import '../../sync/sync_vault.dart';
import '../../vault/opened_vault.dart';
import '../../vault/pairing/pairing_screen.dart';
import '../logic/note_record.dart';
import '../logic/notes_service.dart';
import 'note_detail_page.dart';
import 'note_list_page.dart';

sealed class _NotesState {
  const _NotesState();
}

final class _NotesLoading extends _NotesState {
  const _NotesLoading();
}

final class _NotesFailed extends _NotesState {
  const _NotesFailed(this.error);

  final Object error;
}

final class _NotesReady extends _NotesState {
  const _NotesReady(this.notes);

  final List<NoteRecord> notes;
}

class NotesScreen extends StatefulWidget {
  const NotesScreen({
    required this.service,
    required this.secureKey,
    required this.vault,
    super.key,
  });

  final NotesService service;
  final SecureKey secureKey;
  final OpenedVault vault;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  _NotesState _state = const _NotesLoading();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final notes = await widget.service.loadNotes();
      if (mounted) setState(() => _state = _NotesReady(notes));
    } catch (error) {
      if (mounted) setState(() => _state = _NotesFailed(error));
    }
  }

  Future<void> _reload() async {
    setState(() => _state = const _NotesLoading());
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
    if (saved == true && mounted) {
      _reload();
      syncVaultBestEffort(widget.vault);
    }
  }

  Future<void> _delete(NoteRecord note) async {
    await widget.service.delete(note.id);
    if (mounted) {
      _reload();
      syncVaultBestEffort(widget.vault);
    }
  }

  void _openPairing() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PairingScreen(
          secureKey: widget.secureKey,
          vault: widget.vault,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => switch (_state) {
        _NotesLoading() => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        _NotesFailed(:final error) => _NotesFailedView(error: error),
        _NotesReady(:final notes) => NoteListPage(
          notes: notes,
          onOpen: _openDetail,
          onCreate: () => _openDetail(null),
          onDelete: _delete,
          onPair: _openPairing,
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
