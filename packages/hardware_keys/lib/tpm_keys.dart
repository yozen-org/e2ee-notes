import 'dart:typed_data';

abstract interface class TpmKeys {
  Future<bool> isAvailable();
  Future<Uint8List> protect(Uint8List vaultKey);
  Future<Uint8List> unprotect(Uint8List protectedKey);
}
