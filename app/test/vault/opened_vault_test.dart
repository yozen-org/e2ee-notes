import 'dart:typed_data';

import 'package:e2ee_notes/vault/opened_vault.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget_test.dart' show MemoryStore;

void main() {
  test('vault key cannot be changed through shared byte lists', () {
    final source = Uint8List(32);
    final vault = OpenedVault(
      store: MemoryStore(),
      vaultKey: source,
      deviceId: 'a' * 64,
    );

    source[0] = 1;
    final exposed = vault.vaultKey..[0] = 2;

    expect(exposed[0], 2);
    expect(vault.vaultKey[0], 0);
  });
}
