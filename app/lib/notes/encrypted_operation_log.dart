import 'dart:convert';
import 'dart:typed_data';

import '../crypto/encrypted_note_operation.dart';
import '../storage/blob_store.dart';
import 'room.dart';

final class EncryptedOperationLog {
  EncryptedOperationLog({
    required BlobStore store,
    required Room room,
    OperationCipher? cipher,
  }) : _store = store, // ignore: prefer_initializing_formals
       _room = room, // ignore: prefer_initializing_formals
       _cipher = cipher ?? OperationCipher() {
    if (room.key.length != 32) {
      throw ArgumentError.value(
        room.key.length,
        'room key length',
        'must be 32',
      );
    }
  }

  final BlobStore _store;
  final Room _room;
  final OperationCipher _cipher;

  String get _prefix => 'rooms/${_room.id}/operations/';

  Future<List<NoteOperation>> readAll() async {
    final operations = <NoteOperation>[];
    for (final key in await _store.list(_prefix)) {
      if (!key.endsWith('.json')) continue;
      final objectId = key.substring(_prefix.length, key.length - 5);
      final decoded = jsonDecode(utf8.decode(await _store.get(key)));
      if (decoded is! Map<String, Object?>) {
        throw const FormatException(
          'encrypted operation must be a JSON object',
        );
      }
      operations.add(
        await _cipher.decrypt(
          encrypted: EncryptedOperation.fromJson(decoded),
          key: _room.key,
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
      key: _room.key,
      objectId: operation.operationId,
    );
    await _store.putIfAbsent(
      '$_prefix${operation.operationId}.json',
      Uint8List.fromList(utf8.encode(jsonEncode(encrypted.toJson()))),
    );
  }
}
