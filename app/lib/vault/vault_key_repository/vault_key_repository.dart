import 'dart:typed_data';

abstract interface class VaultKeyRepository {
  Future<bool> exists();
  Future<Uint8List> read();
  Future<void> write(Uint8List bytes);
}
