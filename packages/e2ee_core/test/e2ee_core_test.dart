// 固定ベクターとの一致、暗号文の改ざん検出、保存キーの変更拒否を確認する。
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:e2ee_core/e2ee_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  const objectId =
      '1111111111111111111111111111111111111111111111111111111111111111';
  const operation = NoteOperation(
    operationId: objectId,
    noteId: '2222222222222222222222222222222222222222222222222222222222222222',
    deviceId:
        '3333333333333333333333333333333333333333333333333333333333333333',
    sequence: 1,
    timestampMicros: 1700000000000000,
    kind: NoteOperationKind.create,
    title: 'Hello',
    body: 'Encrypted note',
  );

  test('matches the independent operation-create vector', () async {
    final fixtureData = await File(
      p.join('..', '..', 'spec', 'test-vectors', 'operation-create-v1.json'),
    ).readAsString();
    final fixture = jsonDecode(fixtureData) as Map<String, Object?>;
    final expected = fixture['encryptedObject'] as Map<String, Object?>;
    final cipher = OperationCipher();

    final encrypted = await cipher.encrypt(
      operation: operation,
      vaultKey: _hex(fixture['vaultKeyHex'] as String),
      objectId: objectId,
      nonce: _hex(fixture['nonceHex'] as String),
    );

    expect(
      base64Encode(operation.encodeCanonical()),
      fixture['plaintextBase64'],
    );
    expect(encrypted.toJson(), expected);
    expect(
      await cipher.decrypt(
        encrypted: encrypted,
        vaultKey: _hex(fixture['vaultKeyHex'] as String),
        storageObjectId: objectId,
      ),
      isA<NoteOperation>()
          .having((value) => value.title, 'title', 'Hello')
          .having((value) => value.body, 'body', 'Encrypted note'),
    );
  });

  test('detects ciphertext modification', () async {
    final cipher = OperationCipher();
    final key = Uint8List(32);
    final encrypted = await cipher.encrypt(
      operation: operation,
      vaultKey: key,
      objectId: objectId,
    );
    final modified = Uint8List.fromList(encrypted.ciphertext)..[0] ^= 1;

    await expectLater(
      cipher.decrypt(
        encrypted: EncryptedOperation(
          objectId: encrypted.objectId,
          nonce: encrypted.nonce,
          ciphertext: modified,
        ),
        vaultKey: key,
        storageObjectId: objectId,
      ),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });

  test('rejects moving an object to another storage key', () async {
    final cipher = OperationCipher();
    final key = Uint8List(32);
    final encrypted = await cipher.encrypt(
      operation: operation,
      vaultKey: key,
      objectId: objectId,
    );

    await expectLater(
      cipher.decrypt(
        encrypted: encrypted,
        vaultKey: key,
        storageObjectId:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ),
      throwsFormatException,
    );
  });
}

Uint8List _hex(String value) {
  final result = Uint8List(value.length ~/ 2);
  for (var i = 0; i < result.length; i++) {
    result[i] = int.parse(value.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return result;
}
