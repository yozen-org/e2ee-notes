import 'package:flutter/material.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('E2EE Notes'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(28),
          child: Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Local encrypted vault · hardware-backed when available',
            ),
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
        label: const Text('New note'),
      ),
    );
  }
}

class _EmptyNotes extends StatelessWidget {
  const _EmptyNotes();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.enhanced_encryption_outlined, size: 56),
            SizedBox(height: 20),
            Text(
              'Your notes, your keys, your storage.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12),
            Text('Create a note. Only its encrypted operation is stored.'),
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
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: notes.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, index) {
        final note = notes[index];
        return ListTile(
          title: Text(note.title.isEmpty ? 'Untitled' : note.title),
          subtitle: Text(
            note.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => onEdit(note),
          trailing: IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => onDelete(note),
          ),
        );
      },
    );
  }
}
