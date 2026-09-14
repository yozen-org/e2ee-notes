import 'dart:io';

import 'package:e2ee_notes/notes/notes_repository.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:e2ee_notes/storage/storage_filesystem.dart';

import 'read_or_create_random_bytes.dart';
import 'vault_key_selection/vault_key_selector.dart';

final class LocalVault {
  const LocalVault({required this.keySelectorFactory});

  final VaultKeySelector Function(Directory root) keySelectorFactory;

  Future<EncryptedNotesRepository> open() async {
    final support = await getApplicationSupportDirectory();
    return openAt(Directory(p.join(support.path, 'e2ee-notes')));
  }

  Future<EncryptedNotesRepository> openAt(Directory root) async {
    await root.create(recursive: true);
    final keyService = await keySelectorFactory(root).select();
    final vaultKey = await keyService.openKey();

    final deviceIdBytes = await readOrCreateRandomBytes(
      File(p.join(root.path, 'device-id.bin')),
      32,
    );
    final deviceId = deviceIdBytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return EncryptedNotesRepository(
      store: FilesystemBlobStore(Directory(p.join(root.path, 'storage'))),
      vaultKey: vaultKey,
      deviceId: deviceId,
    );
  }
}
