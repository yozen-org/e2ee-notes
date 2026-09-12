import 'dart:io';
import 'dart:typed_data';

import '../vault_key_files/tpm_protected_key_file.dart';
import 'vault_key_repository.dart';

final class TpmVaultKeyRepository implements VaultKeyRepository {
  TpmVaultKeyRepository(Directory root) : _file = TpmProtectedKeyFile(root);

  final TpmProtectedKeyFile _file;

  @override
  Future<bool> exists() => _file.exists();

  @override
  Future<Uint8List> read() => _file.read();

  @override
  Future<void> write(Uint8List bytes) => _file.write(bytes);
}
