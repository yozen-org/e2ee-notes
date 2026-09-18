import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:e2ee_notes/storage/filesystem_blob_store.dart';

import 'read_or_create_random_bytes.dart';

import 'package:secure_keys/secure_keys.dart';

import 'file_vault_key_storage.dart';
import 'legacy_vault_key_migration.dart';
import 'opened_vault.dart';
import 'request_key_policy.dart';
import 'vault_key_service.dart';

final class FilesystemVaultOpener {
  const FilesystemVaultOpener({
    required this.secureKey,
    required this.requestPolicy,
  });

  final SecureKey secureKey;
  final RequestKeyPolicy requestPolicy;

  Future<OpenedVault> open() async {
    final support = await getApplicationSupportDirectory();
    return openAt(Directory(p.join(support.path, 'e2ee-notes')));
  }

  Future<OpenedVault> openAt(Directory root) async {
    await root.create(recursive: true);
    final storage = FileVaultKeyStorage(root);
    await LegacyVaultKeyMigration(root, secureKey).migrateTo(storage);
    final keyService = VaultKeyService(
      secureKey: secureKey,
      storage: storage,
      requestPolicy: requestPolicy,
    );
    final vaultKey = await keyService.loadOrCreateKey();
    await LegacyVaultKeyMigration(root, secureKey).migrateTo(storage);

    final deviceIdBytes = await readOrCreateRandomBytes(
      File(p.join(root.path, 'device-id.bin')),
      32,
    );
    final deviceId = deviceIdBytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return OpenedVault(
      store: FilesystemBlobStore(Directory(p.join(root.path, 'storage'))),
      vaultKey: vaultKey,
      deviceId: deviceId,
    );
  }
}
