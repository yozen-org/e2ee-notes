import 'dart:io';
import 'dart:typed_data';

import 'generate_random_bytes.dart';

Future<Uint8List> readOrCreateRandomBytes(File file, int length) async {
  if (await file.exists()) {
    return _readBytesWithExpectedLength(file, length);
  }
  return _createRandomBytesFile(file, length);
}

Future<Uint8List> _readBytesWithExpectedLength(
  File file,
  int expectedLength,
) async {
  final bytes = await file.readAsBytes();
  if (bytes.length != expectedLength) {
    throw FormatException(
      'Expected $expectedLength bytes, found ${bytes.length}',
    );
  }
  return bytes;
}

Future<Uint8List> _createRandomBytesFile(File file, int length) async {
  final bytes = generateRandomBytes(length);
  await file.writeAsBytes(bytes, flush: true);
  return bytes;
}
