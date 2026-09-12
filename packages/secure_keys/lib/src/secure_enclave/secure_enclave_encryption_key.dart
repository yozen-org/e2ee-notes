import 'dart:convert';
import 'dart:typed_data';

import '../encryption_key.dart';
import 'secure_enclave_keys.dart';

final class SecureEnclaveEncryptionKey implements EncryptionKey {
  const SecureEnclaveEncryptionKey(this._keys, this._recipient);

  final SecureEnclaveKeys _keys;
  final RecipientPublicKey _recipient;

  @override
  Future<Uint8List> encrypt(Uint8List plaintext) async {
    final envelope = await _keys.wrapVaultKey(
      vaultKey: plaintext,
      recipient: _recipient,
    );
    return Uint8List.fromList(utf8.encode(jsonEncode(envelope.toMap())));
  }
}
