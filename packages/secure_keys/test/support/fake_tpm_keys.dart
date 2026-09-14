import 'dart:typed_data';

import 'package:secure_keys/tpm.dart';

final class FakeTpmKeys implements TpmKeys {
  bool available = true;
  int availabilityChecks = 0;
  final keys = <int, Uint8List>{};
  Future<void> Function()? beforeProtect;
  Uint8List Function(Uint8List)? transformRestored;

  @override
  Future<bool> isAvailable() async {
    availabilityChecks++;
    return available;
  }

  @override
  Future<Uint8List> protect(Uint8List vaultKey) async {
    await beforeProtect?.call();
    final id = keys.length + 1;
    keys[id] = Uint8List.fromList(vaultKey);
    return Uint8List.fromList([id]);
  }

  @override
  Future<Uint8List> unprotect(Uint8List protectedKey) async {
    if (!available) throw StateError('TPM unavailable');
    final key = protectedKey.length == 1 ? keys[protectedKey.single] : null;
    if (key == null) throw const FormatException('invalid protected key');
    final restored = Uint8List.fromList(key);
    return transformRestored?.call(restored) ?? restored;
  }
}
