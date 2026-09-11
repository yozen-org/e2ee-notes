import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

Future<Uint8List> readOrCreateLocalBytes(File file, int length) async {
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
