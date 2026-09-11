// 同一内容の再保存と競合、親ディレクトリへの移動の拒否を確認する。
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
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

  test(
    'nested keys round-trip with a trailing separator on the root',
    () async {
      final directory = await Directory.systemTemp.createTemp('e2ee-paths-');
      addTearDown(() => directory.delete(recursive: true));
    // 結合APIが除去する末尾の区切りを、回帰テストの入力として意図的に付ける。
    final store = FilesystemBlobStore(
        Directory('${directory.path}${p.separator}'),
      );
      final content = Uint8List.fromList([1, 2, 3]);
      await store.putIfAbsent('operations/nested/note.json', content);
      expect(await store.list('operations/'), ['operations/nested/note.json']);
      expect(await store.get('operations/nested/note.json'), content);
      expect(
        await File(p.join(directory.path, 'operations', 'nested', 'note.json'))
            .readAsBytes(),
        content,
      );
      await store.delete('operations/nested/note.json');
      expect(await store.list('operations/'), isEmpty);
    },
  );

  test('rejects absolute paths outside the storage root', () async {
    final directory = await Directory.systemTemp.createTemp('e2ee-paths-');
    addTearDown(() => directory.delete(recursive: true));
    final store = FilesystemBlobStore(directory);
    await expectLater(
      store.get(p.join(directory.parent.path, 'outside')),
      throwsArgumentError,
    );
  });

  test('rejects parent traversal', () {
    final store = FilesystemBlobStore(Directory.systemTemp);
    expect(() => store.get('../secret'), throwsArgumentError);
  });
}
