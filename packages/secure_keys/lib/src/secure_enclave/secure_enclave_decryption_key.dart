import 'dart:convert';
import 'dart:typed_data';

import '../decryption_key.dart';
import 'secure_enclave_keys.dart';

final class SecureEnclaveDecryptionKey implements DecryptionKey {
  SecureEnclaveDecryptionKey(this._keys, Uint8List handle)
    : _handle = Uint8List.fromList(handle);

  final SecureEnclaveKeys _keys;
  final Uint8List _handle;

  @override
  Future<Uint8List> decrypt(Uint8List ciphertext) => _keys.unwrapVaultKey(
    keyHandle: _handle,
    envelope: VaultKeyEnvelope.fromMap(
      jsonDecode(utf8.decode(ciphertext)) as Map<String, dynamic>,
    ),
  );
}
