import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

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
  final random = Random.secure();
  final bytes = Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256)),
  );
  await file.writeAsBytes(bytes, flush: true);
  return bytes;
}
