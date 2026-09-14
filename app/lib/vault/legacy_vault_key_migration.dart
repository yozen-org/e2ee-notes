import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:secure_keys/secure_keys.dart';

import 'vault_key_storage.dart';
import 'vault_key_validation.dart';

/// Compatibility only. New vaults use one opaque key record.
final class LegacyVaultKeyMigration {
  LegacyVaultKeyMigration(this.root, this.secureKey);
  final Directory root;
  final SecureKey secureKey;

  Future<void> migrateTo(VaultKeyStorage storage) async {
    final files = await _readFiles();
    final legacy = importLegacyKeyRecord(files);
    if (legacy == null) return;
    final existing = await storage.read();
    final key = await secureKey.open(existing ?? legacy);
    requireMatchingVaultKeys(key, await secureKey.open(legacy));
    final plain = files['vault-key.bin'];
    if (plain != null) requireMatchingVaultKeys(key, plain);
    if (existing == null) await storage.save(legacy);
    requireMatchingVaultKeys(
      key,
      await secureKey.open((await storage.read())!),
    );
    // Retain legacy protected artifacts for compatibility. Remove a plaintext
    // copy only after the new record is protected and verified. This is retry-safe.
    if (existing != null && !secureKey.isSoftware(existing) && plain != null) {
      await File(p.join(root.path, 'vault-key.bin')).delete();
    }
  }

  Future<Map<String, Uint8List>> _readFiles() async {
    final files = <String, Uint8List>{};
    for (final name in legacyKeyFiles) {
      final file = File(p.join(root.path, name));
      if (await FileSystemEntity.type(file.path) !=
          FileSystemEntityType.notFound) {
        files[name] = await file.readAsBytes();
      }
    }
    return files;
  }
}
