import 'dart:typed_data';

abstract interface class DecryptionKey {
  Future<Uint8List> decrypt(Uint8List ciphertext);
}
