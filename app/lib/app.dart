import 'package:flutter/material.dart';

import 'notes/notes_home_page.dart';
import 'notes/notes_repository.dart';
import 'vault/vault_launcher.dart';

class E2eeNotesApp extends StatelessWidget {
  const E2eeNotesApp({this.repository, super.key});

  final Future<EncryptedNotesRepository>? repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E2EE Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff395b64)),
        useMaterial3: true,
      ),
      home: repository == null
          ? const VaultLauncher()
          : NotesHomePage(repository: repository!),
    );
  }
}
