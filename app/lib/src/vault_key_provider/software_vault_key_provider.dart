import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../local_material.dart';
import 'vault_key_provider.dart';

final class SoftwareVaultKeyProvider implements VaultKeyProvider {
  const SoftwareVaultKeyProvider();

  @override
  Future<Uint8List> openKey(Directory root) =>
      readOrCreateLocalBytes(File(p.join(root.path, 'vault-key.bin')), 32);
}
