import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:notes_repository/notes_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:storage_filesystem/storage_filesystem.dart';

final class LocalVault {
  static Future<EncryptedNotesRepository> open() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory(
      '${support.path}${Platform.pathSeparator}e2ee-notes',
    );
    await root.create(recursive: true);
    final key = await _readOrCreateBytes(
      File('${root.path}${Platform.pathSeparator}vault-key.bin'),
      32,
    );
    final deviceIdBytes = await _readOrCreateBytes(
      File('${root.path}${Platform.pathSeparator}device-id.bin'),
      32,
    );
    final deviceId = deviceIdBytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return EncryptedNotesRepository(
      store: FilesystemBlobStore(
        Directory('${root.path}${Platform.pathSeparator}storage'),
      ),
      vaultKey: key,
      deviceId: deviceId,
    );
  }

  static Future<Uint8List> _readOrCreateBytes(File file, int length) async {
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      if (bytes.length != length) {
        throw const FormatException('invalid local vault material');
      }
      return bytes;
    }
    final random = Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
    await file.writeAsBytes(bytes, flush: true);
    return bytes;
  }
}
