import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

final class TpmProtectedKeyFile {
  TpmProtectedKeyFile(Directory root)
    : _file = File(p.join(root.path, 'vault-key.tpm'));

  final File _file;

  Future<bool> exists() => _file.exists();

  Future<Uint8List> read() async {
    if (await _file.length() > 8192) {
      throw const FormatException('TPM protected key is too large');
    }
    return _file.readAsBytes();
  }

  Future<void> write(Uint8List protectedKey) async {
    final temporary = await _file.parent.createTemp('.tpm-key-');
    try {
      final staged = File(p.join(temporary.path, 'vault-key.tpm'));
      await staged.writeAsBytes(protectedKey, flush: true);
      await staged.rename(_file.path);
    } finally {
      await temporary.delete(recursive: true);
    }
  }
}
