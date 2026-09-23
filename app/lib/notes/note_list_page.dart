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
      appBar: AppBar(
        title: Text(l10n.appTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(l10n.vaultSubtitle),
          ),
        ),
      ),
      body: notes.isEmpty
          ? const _EmptyNotes()
          : _NotesList(
              notes: notes,
              onEdit: onEdit,
              onDelete: onDelete,
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => onEdit(null),
        icon: const Icon(Icons.add),
        label: Text(l10n.newNote),
      ),
    );
  }
}

class _EmptyNotes extends StatelessWidget {
  const _EmptyNotes();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.enhanced_encryption_outlined, size: 56),
            const SizedBox(height: 20),
            Text(
              l10n.emptyNotesHeadline,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(l10n.emptyNotesBody),
          ],
        ),
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
