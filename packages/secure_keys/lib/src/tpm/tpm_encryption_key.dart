import 'dart:typed_data';

import '../encryption_key.dart';
import 'tpm_keys.dart';

final class TpmEncryptionKey implements EncryptionKey {
  const TpmEncryptionKey(this._keys);

  final TpmKeys _keys;

  @override
  Future<Uint8List> encrypt(Uint8List plaintext) => _keys.protect(plaintext);
}
