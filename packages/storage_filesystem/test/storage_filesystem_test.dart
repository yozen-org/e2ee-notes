// 同一内容の再保存と競合、親ディレクトリへの移動の拒否を確認する。
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:storage_api/storage_api.dart';
import 'package:storage_filesystem/storage_filesystem.dart';

void main() {
  test('objects are immutable and idempotent', () async {
    final directory = await Directory.systemTemp.createTemp('e2ee-notes-');
    addTearDown(() => directory.delete(recursive: true));
    final store = FilesystemBlobStore(directory);
    final original = Uint8List.fromList([1, 2, 3]);

    await store.putIfAbsent('operations/a', original);
    await store.putIfAbsent('operations/a', original);
    expect(await store.get('operations/a'), original);
    expect(await store.list('operations/'), ['operations/a']);
    await expectLater(
      store.putIfAbsent('operations/a', Uint8List.fromList([4])),
      throwsA(isA<ObjectConflict>()),
    );
  });

  test('rejects parent traversal', () {
    final store = FilesystemBlobStore(Directory.systemTemp);
    expect(() => store.get('../secret'), throwsArgumentError);
  });
}
