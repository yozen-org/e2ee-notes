import 'dart:async';
import 'dart:typed_data';

import 'package:e2ee_notes/vault/opened_vault.dart';
import 'package:e2ee_notes/vault/vault_controller/vault_controller.dart';
import 'package:e2ee_notes/vault/vault_controller/vault_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_keys/secure_keys.dart';

import '../support/callback_vault_opener.dart';
import '../widget_test.dart' show MemoryStore;

void main() {
  test('transitions from not opened to opening and opened', () async {
    final vault = OpenedVault(
      store: MemoryStore(),
      vaultKey: Uint8List(32),
      deviceId: 'a' * 64,
    );
    final opening = Completer<OpenedVault>();
    final controller = VaultController(
      vaultOpener: CallbackVaultOpener((_) => opening.future),
    );

    expect(controller.state, isA<VaultNotOpened>());

    final result = controller.open(
      requestKeyPolicy: (_) async => const KeyPolicy(allowSoftware: true),
    );
    expect(controller.state, isA<VaultOpening>());

    opening.complete(vault);
    await result;
    expect(controller.state, isA<VaultOpened>());
    expect((controller.state as VaultOpened).vault, same(vault));

    controller.dispose();
  });

  test('captures an opening failure and allows retrying', () async {
    var attempts = 0;
    final vault = OpenedVault(
      store: MemoryStore(),
      vaultKey: Uint8List(32),
      deviceId: 'a' * 64,
    );
    final controller = VaultController(
      vaultOpener: CallbackVaultOpener((_) async {
        attempts++;
        if (attempts == 1) throw StateError('failed');
        return vault;
      }),
    );
    Future<KeyPolicy> requestPolicy(KeyCapabilities _) async =>
        const KeyPolicy(allowSoftware: true);

    await controller.open(requestKeyPolicy: requestPolicy);
    expect(controller.state, isA<VaultOpenFailed>());

    await controller.open(requestKeyPolicy: requestPolicy);
    expect(controller.state, isA<VaultOpened>());
    expect(attempts, 2);

    controller.dispose();
  });
}
