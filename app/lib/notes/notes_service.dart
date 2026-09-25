import 'dart:math';

import '../crypto/encrypted_note_operation.dart';
import '../vault/opened_vault.dart';
import 'encrypted_operation_log.dart';
import 'note_record.dart';
import 'notes_projection.dart';

final class NotesService {
  NotesService({
    required EncryptedOperationLog log,
    required String deviceId,
    NotesProjection projection = const NotesProjection(),
    DateTime Function()? clock,
    Random? random,
  }) : _log = log, // ignore: prefer_initializing_formals
       _deviceId = deviceId,
       _projection = projection, // ignore: prefer_initializing_formals
       _clock = clock ?? DateTime.now,
       _random = random ?? Random.secure() {
    _requireIdentifier(deviceId, 'deviceId');
  }

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
    _requireIdentifier(noteId, 'noteId');
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

NotesService createNotesService(OpenedVault vault) =>
    NotesService(
      log: EncryptedOperationLog(store: vault.store, vaultKey: vault.vaultKey),
      deviceId: vault.deviceId,
    );
