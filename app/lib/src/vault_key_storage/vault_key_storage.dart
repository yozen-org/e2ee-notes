import 'dart:typed_data';

abstract interface class VaultKeyStorage {
  Future<bool> exists();
  Future<bool> isAvailable();
  Future<Uint8List> read();
  Future<void> write(Uint8List key);
}
