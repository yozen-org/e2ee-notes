import 'dart:typed_data';

import '../decryption_key.dart';
import 'tpm_keys.dart';

final class TpmDecryptionKey implements DecryptionKey {
  const TpmDecryptionKey(this._keys);

  final TpmKeys _keys;

  @override
  Future<Uint8List> decrypt(Uint8List ciphertext) =>
      _keys.unprotect(ciphertext);
}
