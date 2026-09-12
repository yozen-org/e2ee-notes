import 'dart:typed_data';

abstract interface class VerificationKey {
  Future<bool> verify({
    required Uint8List message,
    required Uint8List signature,
  });
}
