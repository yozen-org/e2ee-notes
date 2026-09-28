import 'dart:typed_data';

import 'package:secure_keys/android.dart';

final class FakeAndroidKeystoreKeys implements AndroidKeystoreKeys {
  bool available = true;
  int availabilityChecks = 0;
  final keys = <String, Uint8List>{};
  int _nextId = 1;
  Uint8List Function(Uint8List)? transformRestored;

  @override
  Future<bool> isAvailable() async {
    availabilityChecks++;
    return available;
  }

  @override
  Future<ProtectedVaultKey> protect(Uint8List vaultKey) async {
    final alias = 'key-${_nextId++}';
    keys[alias] = Uint8List.fromList(vaultKey);
    return ProtectedVaultKey(alias: alias, iv: Uint8List(12), ciphertext: Uint8List(1));
  }

  @override
  Future<Uint8List> unprotect(ProtectedVaultKey protected) async {
    if (!available) throw StateError('Android Keystore unavailable');
    final key = keys[protected.alias];
    if (key == null) throw const FormatException('invalid protected key');
    final restored = Uint8List.fromList(key);
    return transformRestored?.call(restored) ?? restored;
  }
}
