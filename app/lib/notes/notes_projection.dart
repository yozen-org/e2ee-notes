import '../crypto/encrypted_note_operation.dart';
import 'note_record.dart';

final class NotesProjection {
  const NotesProjection();

  List<NoteRecord> project(List<NoteOperation> operations) {
    final notes = <String, NoteRecord>{};
    for (final operation in operations) {
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
}
