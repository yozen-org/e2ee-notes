import 'dart:typed_data';

abstract interface class SigningKey {
  Future<Uint8List> sign(Uint8List message);
}
