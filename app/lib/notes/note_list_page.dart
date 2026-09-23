import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'encrypted_notes_repository.dart';

class NoteListPage extends StatelessWidget {
  const NoteListPage({
    required this.notes,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final List<NoteRecord> notes;
  final void Function(NoteRecord? note) onEdit;
  final void Function(NoteRecord note) onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: _NotesList(
          notes: notes,
          onEdit: onEdit,
          onDelete: onDelete,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => onEdit(null),
        icon: const Icon(Icons.add),
        label: Text(l10n.newNote),
      ),
    );
  }
}

class _NotesList extends StatelessWidget {
  const _NotesList({
    required this.notes,
    required this.onEdit,
    required this.onDelete,
  });

  final List<NoteRecord> notes;
  final void Function(NoteRecord) onEdit;
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
          onTap: () => onEdit(note),
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
