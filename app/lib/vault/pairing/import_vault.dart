import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:secure_keys/secure_keys.dart';

import '../../storage/filesystem_blob_store.dart';
import '../file_vault_key_storage.dart';
import '../opened_vault.dart';
import '../read_or_create_random_bytes.dart';

/// Restores a vault from a pairing envelope: accepts the transferred vault key
/// and opens a fresh, empty vault. The operation log is pulled later by sync.
Future<OpenedVault> importVault(
  Directory root, {
  required SecureKey secureKey,
  required VaultKeyEnvelope envelope,
  required RecipientKey recipientKey,
  required KeyPolicy policy,
}) async {
  await root.create(recursive: true);
  final generated = await secureKey.accept(
    envelope,
    recipientKey,
    policy: policy,
  );
  await FileVaultKeyStorage(root).save(generated.record);

  final store = FilesystemBlobStore(Directory(p.join(root.path, 'storage')));
  final deviceIdBytes = await readOrCreateRandomBytes(
    File(p.join(root.path, 'device-id.bin')),
    32,
  );
  final deviceId = deviceIdBytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return OpenedVault(
    store: store,
    vaultKey: generated.vaultKey,
    deviceId: deviceId,
  );
}
