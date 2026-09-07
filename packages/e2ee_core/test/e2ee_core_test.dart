import 'package:e2ee_core/e2ee_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes a versioned note operation', () {
    const operation = NoteOperation(
      operationId: 'op-1',
      noteId: 'note-1',
      deviceId: 'device-1',
      sequence: 1,
      timestampMicros: 42,
      kind: NoteOperationKind.create,
      title: 'hello',
      body: 'encrypted later',
    );

    expect(operation.toJson()['version'], 1);
    expect(operation.toJson()['kind'], 'create');
    expect(operation.toJson()['title'], 'hello');
  });
}
