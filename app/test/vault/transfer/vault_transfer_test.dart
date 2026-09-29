import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_keys/secure_keys.dart';
import 'package:secure_keys/src/envelope_secure_key.dart';
import 'package:e2ee_notes/notes/logic/notes_service.dart';
import 'package:e2ee_notes/vault/transfer/vault_exporter.dart';
import 'package:e2ee_notes/vault/transfer/vault_importer.dart';
import 'package:e2ee_notes/vault/transfer/vault_transfer.dart';
import 'package:e2ee_notes/vault/vault_opener/filesystem_vault_opener.dart';

import '../../../../packages/secure_keys/test/support/fake_tpm_keys.dart';

void main() {
  test('exporting and importing restores the same notes', () async {
    final sourceRoot = await Directory.systemTemp.createTemp('transfer-source-');
    final receiverRoot = await Directory.systemTemp.createTemp(
      'transfer-receiver-',
    );
    addTearDown(() => sourceRoot.delete(recursive: true));
    addTearDown(() => receiverRoot.delete(recursive: true));

    final sourceKeys = PlatformSecureKey.withHardware(
      EnvelopeSecureKey(backend: FakeTpmKeys(), provider: 'tpm'),
    );
    final receiverKeys = PlatformSecureKey.withHardware(
      EnvelopeSecureKey(backend: FakeTpmKeys(), provider: 'tpm'),
    );

    final sourceVault = await FilesystemVaultOpener(
      secureKey: sourceKeys,
    ).openAt(sourceRoot, requestKeyPolicy: (_) async => const KeyPolicy());
    final notes = await createNotesService(sourceVault);
    await notes.save(title: 'Shared', body: 'A note from another device');

    final recipientKey = await receiverKeys.createRecipientKey(
      policy: const KeyPolicy(),
    );
    final transfer = await VaultExporter(
      secureKey: sourceKeys,
    ).export(vault: sourceVault, recipient: recipientKey.publicKey);

    final imported = await VaultImporter(
      secureKey: receiverKeys,
    ).importAt(
      receiverRoot,
      transfer: transfer,
      recipientKey: recipientKey,
      policy: const KeyPolicy(),
    );

    final restored = await (await createNotesService(imported)).loadNotes();
    expect(restored.single.title, 'Shared');
    expect(restored.single.body, 'A note from another device');
  });

  test('VaultTransfer round-trips through JSON', () {
    final transfer = VaultTransfer(
      vaultKeyEnvelope: const VaultKeyEnvelope(
        version: 1,
        suite: 'P256-HKDF-SHA256-AES256GCM',
        recipientKeyId: 'id',
        ephemeralPublicKey: 'ephemeral',
        sealedKey: 'sealed',
      ),
      objects: {'room.json': Uint8List.fromList([1, 2, 3])},
    );

    final restored = VaultTransfer.fromJson(
      jsonDecode(jsonEncode(transfer.toJson())) as Map<String, Object?>,
    );

    expect(restored.vaultKeyEnvelope.toMap(), transfer.vaultKeyEnvelope.toMap());
    expect(restored.objects['room.json'], [1, 2, 3]);
  });
}
