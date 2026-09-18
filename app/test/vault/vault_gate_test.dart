import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_keys/secure_keys.dart';
import 'package:e2ee_notes/vault/vault_gate.dart';
import 'package:e2ee_notes/vault/opened_vault.dart';

import '../widget_test.dart' show MemoryStore;

void main() {
  testWidgets('forwards policy requester and retries opening failures', (
    tester,
  ) async {
    var attempts = 0;
    OpenedVault? openedVault;
    Future<KeyPolicy> requestPolicy(KeyCapabilities _) async =>
        const KeyPolicy(allowSoftware: true);

    await tester.pumpWidget(
      MaterialApp(
        home: VaultGate(
          requestPolicy: requestPolicy,
          builder: (context, vault) {
            openedVault = vault;
            return const Text('Vault ready');
          },
          vaultOpener: (actualRequestPolicy) async {
            attempts++;
            if (attempts == 1) throw StateError('failed');
            final policy = await actualRequestPolicy(
              const KeyCapabilities(
                hardwareBacked: false,
                sharing: false,
                userPresence: false,
              ),
            );
            expect(policy.allowSoftware, isTrue);
            return OpenedVault(
              store: MemoryStore(),
              vaultKey: Uint8List(32),
              deviceId: 'a' * 64,
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.textContaining('Could not open vault'), findsOneWidget);
    expect(attempts, 1);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(openedVault, isNotNull);
    expect(find.text('Vault ready'), findsOneWidget);
  });
}
