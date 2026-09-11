import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

final class RecipientKeyHandleFile {
  RecipientKeyHandleFile(Directory root)
    : _file = File(p.join(root.path, 'recipient-key.handle'));

  final File _file;

  Future<bool> exists() => _file.exists();

  Future<Uint8List> read() => _file.readAsBytes();

  Future<void> write(Uint8List handle) async {
    await _file.writeAsBytes(handle, flush: true);
  }
}
