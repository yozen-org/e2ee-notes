import 'dart:typed_data';

abstract interface class EncryptionKey {
  Future<Uint8List> encrypt(Uint8List plaintext);
}
