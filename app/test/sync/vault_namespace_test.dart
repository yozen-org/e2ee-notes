import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:e2ee_notes/sync/vault_namespace.dart';

void main() {
  test('derives a stable 64-character namespace', () async {
    final vaultKey = Uint8List.fromList(List.generate(32, (i) => i));

    final first = await vaultNamespace(vaultKey);
    final second = await vaultNamespace(vaultKey);

    expect(first, second);
    expect(first, hasLength(64));
    expect(first, matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  test('different vault keys produce different namespaces', () async {
    final a = await vaultNamespace(Uint8List(32));
    final b = await vaultNamespace(Uint8List.fromList([1, ...List.filled(31, 0)]));

    expect(a, isNot(b));
  });
}
