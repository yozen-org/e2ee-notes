import 'dart:io';

import 'package:notes_repository/notes_repository.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:storage_filesystem/storage_filesystem.dart';

import 'local_material.dart';
import 'vault_key_provider/vault_key_provider.dart';

final class LocalVault {
  const LocalVault({required this.keyProvider});

  final VaultKeyProvider keyProvider;

  Future<EncryptedNotesRepository> open() async {
    final support = await getApplicationSupportDirectory();
    return openAt(Directory(p.join(support.path, 'e2ee-notes')));
  }

  Future<EncryptedNotesRepository> openAt(Directory root) async {
    await root.create(recursive: true);
    final vaultKey = await keyProvider.openKey(root);

    final deviceIdBytes = await readOrCreateLocalBytes(
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
