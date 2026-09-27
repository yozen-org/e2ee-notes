import 'package:e2ee_notes/crypto/encrypted_note_operation.dart';
import 'package:e2ee_notes/notes/logic/notes_projection.dart';
import 'package:flutter_test/flutter_test.dart';

NoteOperation op({
  required int sequence,
  required NoteOperationKind kind,
  String noteId = 'note-a',
  String? title,
  String? body,
  int timestampMicros = 0,
}) =>
    NoteOperation(
      operationId: 'op-$sequence',
      noteId: noteId,
      deviceId: 'device',
      sequence: sequence,
      timestampMicros: timestampMicros,
      kind: kind,
      title: title,
      body: body,
    );

void main() {
  const projection = NotesProjection();

  test('replays create, update, and delete into current notes', () {
    final notes = projection.project([
      op(sequence: 1, kind: NoteOperationKind.create, title: 'First', body: 'one'),
      op(
        sequence: 2,
        kind: NoteOperationKind.update,
        title: 'First v2',
        body: 'one-two',
      ),
      op(
        sequence: 3,
        kind: NoteOperationKind.create,
        noteId: 'note-b',
        title: 'Second',
        body: 'two',
      ),
      op(sequence: 4, kind: NoteOperationKind.delete, noteId: 'note-b'),
    ]);

    expect(notes, hasLength(1));
    expect(notes.single.title, 'First v2');
    expect(notes.single.body, 'one-two');
  });

  test('sorts notes by modified time descending', () {
    final notes = projection.project([
      op(
        sequence: 1,
        kind: NoteOperationKind.create,
        noteId: 'note-a',
        title: 'Old',
        timestampMicros: 100,
      ),
      op(
        sequence: 2,
        kind: NoteOperationKind.create,
        noteId: 'note-b',
        title: 'New',
        timestampMicros: 200,
      ),
    ]);

    expect(notes.map((note) => note.title), ['New', 'Old']);
  });
}
