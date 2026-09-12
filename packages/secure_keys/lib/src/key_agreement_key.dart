import 'dart:typed_data';

abstract interface class KeyAgreementKey {
  Future<Uint8List> deriveSharedSecret(Uint8List encodedPeerPublicKey);
}
