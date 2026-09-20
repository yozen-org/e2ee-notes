import 'package:flutter/material.dart';
import 'package:secure_keys/secure_keys.dart';

import 'app.dart';
import 'notes/notes_repository_factory/encrypted_notes_repository_factory.dart';
import 'vault/vault_opener/filesystem_vault_opener.dart';

void main() {
  runApp(
    App(
      notesRepositoryFactory: const EncryptedNotesRepositoryFactory(),
      vaultOpener: FilesystemVaultOpener(secureKey: PlatformSecureKey()),
    ),
  );
}
