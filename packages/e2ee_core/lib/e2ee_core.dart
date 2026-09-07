/// Platform-neutral data model for E2EE Notes.
library;

enum NoteOperationKind { create, update, delete }

final class NoteOperation {
  const NoteOperation({
    required this.operationId,
    required this.noteId,
    required this.deviceId,
    required this.sequence,
    required this.timestampMicros,
    required this.kind,
    this.baseOperationId,
    this.title,
    this.body,
  });

  final String operationId;
  final String noteId;
  final String deviceId;
  final int sequence;
  final int timestampMicros;
  final NoteOperationKind kind;
  final String? baseOperationId;
  final String? title;
  final String? body;

  Map<String, Object?> toJson() => {
    'version': 1,
    'operationID': operationId,
    'noteID': noteId,
    'deviceID': deviceId,
    'sequence': sequence,
    'timestampMicros': timestampMicros,
    'kind': kind.name,
    if (baseOperationId case final value?) 'baseOperationID': value,
    if (title case final value?) 'title': value,
    if (body case final value?) 'body': value,
  };
}
