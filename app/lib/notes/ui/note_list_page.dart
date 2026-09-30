import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../logic/note_record.dart';

class NoteListPage extends StatelessWidget {
  const NoteListPage({
    required this.notes,
    required this.onOpen,
    required this.onCreate,
    required this.onDelete,
    required this.onPair,
    super.key,
  });

  final List<NoteRecord> notes;
  final void Function(NoteRecord note) onOpen;
  final void Function() onCreate;
  final void Function(NoteRecord note) onDelete;
  final void Function() onPair;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.pairingTitle,
            icon: const Icon(Icons.devices),
            onPressed: onPair,
          ),
        ],
      ),
      body: SafeArea(
        child: _NotesList(
          notes: notes,
          onOpen: onOpen,
          onDelete: onDelete,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onCreate,
        icon: const Icon(Icons.add),
        label: Text(l10n.newNote),
      ),
    );
  }
}

class _NotesList extends StatelessWidget {
  const _NotesList({
    required this.notes,
    required this.onOpen,
    required this.onDelete,
  });

  final List<NoteRecord> notes;
  final void Function(NoteRecord) onOpen;
  final void Function(NoteRecord) onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: notes.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, index) {
        final note = notes[index];
        return ListTile(
          title: Text(note.title.isEmpty ? l10n.untitled : note.title),
          subtitle: Text(
            note.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => onOpen(note),
          trailing: IconButton(
            tooltip: l10n.deleteNote,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => onDelete(note),
          ),
        );
      },
    );
  }
}
