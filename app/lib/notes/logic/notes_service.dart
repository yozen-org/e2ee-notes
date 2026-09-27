import 'dart:math';

import '../../../crypto/encrypted_note_operation.dart';
import '../../../vault/opened_vault.dart';
import 'encrypted_operation_log.dart';
import 'note_record.dart';
import 'notes_projection.dart';
import 'room_key.dart';

final class NotesService {
  NotesService({
    required EncryptedOperationLog log,
    required String deviceId,
    NotesProjection projection = const NotesProjection(),
    DateTime Function()? clock,
    Random? random,
  }) : _log = log, // ignore: prefer_initializing_formals
       _deviceId = deviceId, // ignore: prefer_initializing_formals
       _projection = projection, // ignore: prefer_initializing_formals
       _clock = clock ?? DateTime.now,
       _random = random ?? Random.secure();

  final EncryptedOperationLog _log;
  final String _deviceId;
  final NotesProjection _projection;
  final DateTime Function() _clock;
  final Random _random;
  int _nextSequence = 1;

  Future<List<NoteRecord>> loadNotes() async {
    final operations = await _log.readAll();
    _syncSequence(operations);
    return _projection.project(operations);
  }

  Future<NoteRecord> save({
    String? noteId,
    required String title,
    required String body,
  }) async {
    final operations = await _log.readAll();
    _syncSequence(operations);
    final actualNoteId = noteId ?? _identifier();
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
    await _log.append(operation);
    return NoteRecord(
      id: actualNoteId,
      title: title,
      body: body,
      modifiedAt: now,
    );
  }

  Future<void> delete(String noteId) async {
    final operations = await _log.readAll();
    _syncSequence(operations);
    await _log.append(
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

  void _syncSequence(List<NoteOperation> operations) {
    for (final operation in operations) {
      if (operation.deviceId == _deviceId &&
          operation.sequence >= _nextSequence) {
        _nextSequence = operation.sequence + 1;
      }
    }
  }

  String _identifier() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}

Future<NotesService> createNotesService(OpenedVault vault) async {
  final room = await RoomKeyStore(
    store: vault.store,
    rootKey: vault.vaultKey,
  ).loadOrCreate();
  return NotesService(
    log: EncryptedOperationLog(store: vault.store, room: room),
    deviceId: vault.deviceId,
  );
}
