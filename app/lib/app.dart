import 'package:flutter/material.dart';

import 'notes/notes_home_page.dart';
import 'notes/notes_repository_factory/notes_repository_factory.dart';
import 'vault/vault_gate.dart';
import 'vault/vault_opener.dart';

class E2eeNotesApp extends StatelessWidget {
  const E2eeNotesApp({
    required this.vaultOpener,
    required this.notesRepositoryFactory,
    super.key,
  });

  final VaultOpener vaultOpener;
  final NotesRepositoryFactory notesRepositoryFactory;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E2EE Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff395b64)),
        useMaterial3: true,
      ),
      home: VaultGate(
        vaultOpener: vaultOpener,
        builder: (_, vault) =>
            NotesHomePage(repository: notesRepositoryFactory.create(vault)),
      ),
    );
  }
}
