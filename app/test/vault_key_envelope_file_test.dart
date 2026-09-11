import 'dart:convert';
import 'dart:io';

import 'package:e2ee_notes/src/vault_key_files/vault_key_envelope_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory directory;
  late File file;
  late VaultKeyEnvelopeFile envelopeFile;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('e2ee-envelope-');
    file = File(p.join(directory.path, 'vault-key.envelope.json'));
    envelopeFile = VaultKeyEnvelopeFile(directory);
  });

  tearDown(() => directory.delete(recursive: true));

  test('reads and writes the existing envelope JSON format', () async {
    final document = {
      'version': 1,
      'suite': 'P256-HKDF-SHA256-AES256GCM',
      'recipientKeyID': 'a' * 64,
      'ephemeralPublicKey': 'test-public-key',
      'sealedKey': 'test-sealed-key',
    };
    expect(await envelopeFile.exists(), isFalse);
    await file.writeAsString(jsonEncode(document));
    expect(await envelopeFile.exists(), isTrue);
    final envelope = await envelopeFile.read();
    expect(envelope.toMap(), document);
    await envelopeFile.write(envelope);
    expect(jsonDecode(await file.readAsString()), document);
  });

  for (final invalidJson in ['[]', 'null', '{']) {
    test('rejects malformed envelope data: $invalidJson', () async {
      await file.writeAsString(invalidJson);
      await expectLater(envelopeFile.read(), throwsFormatException);
      expect(await file.readAsString(), invalidJson);
    });
  }
}
