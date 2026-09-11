import 'dart:io';

import 'package:notes_repository/notes_repository.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:storage_filesystem/storage_filesystem.dart';

import 'local_material.dart';
import 'vault_key_provider.dart';

// 端末内の保存先と鍵を用意し、暗号化メモのRepositoryを組み立てる。
final class LocalVault {
  const LocalVault({required this.keyProvider});

  final VaultKeyProvider keyProvider;

  Future<EncryptedNotesRepository> open() async {
    final support = await getApplicationSupportDirectory();
    return openAt(Directory(p.join(support.path, 'e2ee-notes')));
  }

  // 保存ルートを指定できるようにして、テストでは一時ディレクトリを使う。
  Future<EncryptedNotesRepository> openAt(Directory root) async {
    await root.create(recursive: true);
    final vaultKey = await keyProvider.openKey(root);
    // 操作の発生元を識別する端末IDを、起動をまたいで保持する。
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
