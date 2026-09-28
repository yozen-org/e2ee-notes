import 'dart:typed_data';

final class ProtectedVaultKey {
  const ProtectedVaultKey({
    required this.alias,
    required this.iv,
    required this.ciphertext,
  });

  final String alias;
  final Uint8List iv;
  final Uint8List ciphertext;
}

abstract interface class AndroidKeystoreKeys {
  Future<bool> isAvailable();
  Future<ProtectedVaultKey> protect(Uint8List vaultKey);
  Future<Uint8List> unprotect(ProtectedVaultKey protected);
}
