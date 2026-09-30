import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_keys/secure_keys.dart';
import 'package:secure_keys/src/envelope_secure_key.dart';
import 'package:e2ee_notes/vault/pairing/import_vault.dart';

import '../../../../packages/secure_keys/test/support/fake_tpm_keys.dart';

void main() {
  test('importVault accepts the envelope and opens an empty vault', () async {
    final root = await Directory.systemTemp.createTemp('pairing-import-');
    addTearDown(() => root.delete(recursive: true));

    final receiverKeys = PlatformSecureKey.withHardware(
      EnvelopeSecureKey(backend: FakeTpmKeys(), provider: 'tpm'),
    );
    final senderKeys = PlatformSecureKey.withHardware(
      EnvelopeSecureKey(backend: FakeTpmKeys(), provider: 'tpm'),
    );

    final recipientKey = await receiverKeys.createRecipientKey(
      policy: const KeyPolicy(),
    );
    final vaultKey = Uint8List.fromList(List.generate(32, (i) => i));
    final envelope = await senderKeys.envelope(vaultKey, recipientKey.publicKey);

    final imported = await importVault(
      root,
      secureKey: receiverKeys,
      envelope: envelope,
      recipientKey: recipientKey,
      policy: const KeyPolicy(),
    );

    expect(imported.vaultKey, vaultKey);
    expect(await imported.store.list(''), isEmpty);
  });
}
