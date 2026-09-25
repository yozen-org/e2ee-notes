import 'dart:convert';
import 'dart:typed_data';

import '../crypto/encrypted_note_operation.dart';
import '../storage/blob_store.dart';

final class EncryptedOperationLog {
  EncryptedOperationLog({
    required BlobStore store,
    required Uint8List vaultKey,
    OperationCipher? cipher,
  }) : _store = store, // ignore: prefer_initializing_formals
       _vaultKey = Uint8List.fromList(vaultKey),
       _cipher = cipher ?? OperationCipher() {
    if (vaultKey.length != 32) {
      throw ArgumentError.value(
        vaultKey.length,
        'vaultKey length',
        'must be 32',
      );
    }
  }

  static const operationPrefix = 'operations/';

  final BlobStore _store;
  final Uint8List _vaultKey;
  final OperationCipher _cipher;

  Future<List<NoteOperation>> readAll() async {
    final operations = <NoteOperation>[];
    for (final key in await _store.list(operationPrefix)) {
      if (!key.endsWith('.json')) continue;
      final objectId = key.substring(operationPrefix.length, key.length - 5);
      final decoded = jsonDecode(utf8.decode(await _store.get(key)));
      if (decoded is! Map<String, Object?>) {
        throw const FormatException(
          'encrypted operation must be a JSON object',
        );
      }
      operations.add(
        await _cipher.decrypt(
          encrypted: EncryptedOperation.fromJson(decoded),
          vaultKey: _vaultKey,
          storageObjectId: objectId,
        ),
      );
    }

    operations.sort((left, right) {
      final timestamp = left.timestampMicros.compareTo(right.timestampMicros);
      return timestamp != 0
          ? timestamp
          : left.operationId.compareTo(right.operationId);
    });
    return operations;
  }

  Future<void> append(NoteOperation operation) async {
    final encrypted = await _cipher.encrypt(
      operation: operation,
      vaultKey: _vaultKey,
      objectId: operation.operationId,
    );
    await _store.putIfAbsent(
      '$operationPrefix${operation.operationId}.json',
      Uint8List.fromList(utf8.encode(jsonEncode(encrypted.toJson()))),
    );
  }
}
