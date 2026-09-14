import 'package:secure_keys/secure_keys.dart';

abstract interface class VaultKeyStorage {
  Future<KeyRecord?> read();
  Future<void> save(KeyRecord record);
}
