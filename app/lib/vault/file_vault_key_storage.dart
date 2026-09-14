import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:secure_keys/secure_keys.dart';

import 'vault_key_storage.dart';

final class FileVaultKeyStorage implements VaultKeyStorage {
  FileVaultKeyStorage(Directory root)
    : _file = File(p.join(root.path, 'vault-key.json'));
  final File _file;

  @override
  Future<KeyRecord?> read() async {
    final type = await FileSystemEntity.type(_file.path);
    if (type == FileSystemEntityType.notFound) return null;
    return KeyRecord.decode(await _file.readAsBytes());
  }

  @override
  Future<void> save(KeyRecord record) async {
    final temporary = await _file.parent.createTemp('.vault-key-');
    try {
      final staged = File(p.join(temporary.path, 'record'));
      await staged.writeAsBytes(record.encode(), flush: true);
      await staged.rename(_file.path);
    } finally {
      await temporary.delete(recursive: true);
    }
  }
}
