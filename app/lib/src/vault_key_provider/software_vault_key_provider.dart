import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../read_or_create_random_bytes.dart';
import 'vault_key_provider.dart';

final class SoftwareVaultKeyProvider implements VaultKeyProvider {
  const SoftwareVaultKeyProvider();

  @override
  Future<Uint8List> openKey(Directory root) =>
      readOrCreateRandomBytes(File(p.join(root.path, 'vault-key.bin')), 32);
}
