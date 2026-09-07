import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:e2ee_core/e2ee_core.dart';
import 'package:storage_api/storage_api.dart';

final class NoteRecord {
  const NoteRecord({
    required this.id,
    required this.title,
    required this.body,
    required this.modifiedAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime modifiedAt;
}

final class EncryptedNotesRepository {
  EncryptedNotesRepository({
    required BlobStore store,
    required Uint8List vaultKey,
    required String deviceId,
    OperationCipher? cipher,
    DateTime Function()? clock,
    Random? random,
  }) : // The public parameter keeps the implementation behind this boundary.
       // ignore: prefer_initializing_formals
       _store = store,
       _vaultKey = Uint8List.fromList(vaultKey),
       _deviceId = deviceId,
       _cipher = cipher ?? OperationCipher(),
       _clock = clock ?? DateTime.now,
       _random = random ?? Random.secure() {
    _requireIdentifier(deviceId, 'deviceId');
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
  final String _deviceId;
  final OperationCipher _cipher;
  final DateTime Function() _clock;
  final Random _random;
  int _nextSequence = 1;

  Future<List<NoteRecord>> loadNotes() async {
    final operations = await _loadOperations();
    final notes = <String, NoteRecord>{};
    for (final operation in operations) {
      if (operation.deviceId == _deviceId &&
          operation.sequence >= _nextSequence) {
        _nextSequence = operation.sequence + 1;
      }
      switch (operation.kind) {
        case NoteOperationKind.create:
        case NoteOperationKind.update:
          notes[operation.noteId] = NoteRecord(
            id: operation.noteId,
            title: operation.title ?? '',
            body: operation.body ?? '',
            modifiedAt: DateTime.fromMicrosecondsSinceEpoch(
              operation.timestampMicros,
              isUtc: true,
            ),
          );
        case NoteOperationKind.delete:
          notes.remove(operation.noteId);
      }
    }
    final result = notes.values.toList()
      ..sort((left, right) => right.modifiedAt.compareTo(left.modifiedAt));
    return result;
  }

  Future<NoteRecord> save({
    String? noteId,
    required String title,
    required String body,
  }) async {
    await loadNotes();
    final actualNoteId = noteId ?? _identifier();
    _requireIdentifier(actualNoteId, 'noteId');
    final operationId = _identifier();
    final now = _clock().toUtc();
    final operation = NoteOperation(
      operationId: operationId,
      noteId: actualNoteId,
      deviceId: _deviceId,
      sequence: _nextSequence++,
      timestampMicros: now.microsecondsSinceEpoch,
      kind: noteId == null
          ? NoteOperationKind.create
          : NoteOperationKind.update,
      title: title,
      body: body,
    );
    await _write(operation);
    return NoteRecord(
      id: actualNoteId,
      title: title,
      body: body,
      modifiedAt: now,
    );
  }

  Future<void> delete(String noteId) async {
    await loadNotes();
    _requireIdentifier(noteId, 'noteId');
    await _write(
      NoteOperation(
        operationId: _identifier(),
        noteId: noteId,
        deviceId: _deviceId,
        sequence: _nextSequence++,
        timestampMicros: _clock().toUtc().microsecondsSinceEpoch,
        kind: NoteOperationKind.delete,
      ),
    );
  }

  Future<List<NoteOperation>> _loadOperations() async {
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

  Future<void> _write(NoteOperation operation) async {
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

  String _identifier() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  static void _requireIdentifier(String value, String name) {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
      throw ArgumentError.value(
        value,
        name,
        'must be 64 lowercase hex characters',
      );
    }
  }
}
