import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../vault_key_validation.dart';
import 'vault_key_repository.dart';

final class PlaintextVaultKeyRepository implements VaultKeyRepository {
  PlaintextVaultKeyRepository(Directory root)
    : _file = File(p.join(root.path, 'vault-key.bin'));

  final File _file;

  @override
  Future<bool> exists() => _file.exists();

  @override
  Future<Uint8List> read() async {
    final key = await _file.readAsBytes();
    validateVaultKey(key);
    return key;
  }

  @override
  Future<void> write(Uint8List key) async {
    validateVaultKey(key);
    await _file.writeAsBytes(key, flush: true);
  }

  Future<void> delete() async => _file.delete();
}
