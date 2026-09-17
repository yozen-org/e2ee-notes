import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_keys/secure_keys.dart';
import 'package:e2ee_notes/vault/vault_gate.dart';
import 'package:e2ee_notes/notes/encrypted_notes_repository.dart';

import '../widget_test.dart' show MemoryStore;

void main() {
  for (final hardware in [false, true]) {
    testWidgets('consent gates key creation and retry works: $hardware', (
      tester,
    ) async {
      var created = 0;
      KeyPolicy? policy;
      await tester.pumpWidget(
        MaterialApp(
          home: VaultGate(
            openVault: (requestPolicy) async {
              policy = await requestPolicy(
                KeyCapabilities(
                  hardwareBacked: hardware,
                  sharing: hardware,
                  userPresence: hardware,
                ),
              );
              created++;
              return EncryptedNotesRepository(
                store: MemoryStore(),
                vaultKey: Uint8List(32),
                deviceId: 'a' * 64,
              );
            },
          ),
        ),
      );
      // The loading spinner remains active behind the modal.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Save the vault key on this device?'), findsOneWidget);
      expect(created, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(created, 0);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(created, 1);
      expect(policy!.allowSoftware, !hardware);
      expect(find.text('New note'), findsOneWidget);
    });
  }
}
