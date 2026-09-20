import 'dart:typed_data';

import 'package:e2ee_notes/home_page.dart';
import 'package:e2ee_notes/notes/notes_repository_factory/encrypted_notes_repository_factory.dart';
import 'package:e2ee_notes/vault/opened_vault.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_keys/secure_keys.dart';

import 'support/callback_vault_opener.dart';
import 'widget_test.dart' show MemoryStore;

void main() {
  testWidgets(
    'shows an opening failure and retries with the requested policy',
    (tester) async {
      var attempts = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(
            notesRepositoryFactory: const EncryptedNotesRepositoryFactory(),
            vaultOpener: CallbackVaultOpener((requestPolicy) async {
              attempts++;
              if (attempts == 1) throw StateError('failed');
              final policy = await requestPolicy(
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
            }),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('Could not open vault'), findsOneWidget);
      expect(attempts, 1);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Save the vault key on this device?'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(attempts, 2);
      expect(find.text('Your notes, your keys, your storage.'), findsOneWidget);
    },
  );
}
