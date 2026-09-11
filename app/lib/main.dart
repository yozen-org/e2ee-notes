import 'package:e2ee_notes/src/vault_bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:notes_repository/notes_repository.dart';

void main() => runApp(E2eeNotesApp(repository: openLocalVault()));

class E2eeNotesApp extends StatelessWidget {
  const E2eeNotesApp({required this.repository, super.key});

  final Future<EncryptedNotesRepository> repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E2EE Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff395b64)),
        useMaterial3: true,
      ),
      home: NotesHomePage(repository: repository),
    );
  }
}

class NotesHomePage extends StatefulWidget {
  const NotesHomePage({required this.repository, super.key});

  final Future<EncryptedNotesRepository> repository;

  @override
  State<NotesHomePage> createState() => _NotesHomePageState();
}

class _NotesHomePageState extends State<NotesHomePage> {
  late Future<List<NoteRecord>> _notes = _load();

  Future<List<NoteRecord>> _load() async =>
      (await widget.repository).loadNotes();

  void _reload() {
    setState(() {
      _notes = _load();
    });
  }

  Future<void> _edit([NoteRecord? note]) async {
    var title = note?.title ?? '';
    var body = note?.body ?? '';
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(note == null ? 'New encrypted note' : 'Edit note'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: title,
                onChanged: (value) => title = value,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: body,
                onChanged: (value) => body = value,
                minLines: 5,
                maxLines: 12,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Encrypt & save'),
          ),
        ],
      ),
    );
    if (shouldSave != true || !mounted) return;
    await (await widget.repository).save(
      noteId: note?.id,
      title: title,
      body: body,
    );
    if (mounted) _reload();
  }

  Future<void> _delete(NoteRecord note) async {
    await (await widget.repository).delete(note.id);
    if (mounted) _reload();
  }

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

      body: FutureBuilder<List<NoteRecord>>(
        future: _notes,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Could not open vault: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final notes = snapshot.data!;
          if (notes.isEmpty) {
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
                    Text(
                      'Create a note. Only its encrypted operation is stored.',
                    ),
                  ],
                ),
              ),
            );
          }
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
                onTap: () => _edit(note),
                trailing: IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(note),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _edit,
        icon: const Icon(Icons.add),
        label: const Text('New note'),
      ),
    );
  }
}
