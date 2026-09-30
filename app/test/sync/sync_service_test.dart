import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:e2ee_notes/storage/filesystem_blob_store.dart';
import 'package:e2ee_notes/sync/sync_service.dart';

void main() {
  test('sync merges objects in both directions', () async {
    final localRoot = await Directory.systemTemp.createTemp('sync-local-');
    final remoteRoot = await Directory.systemTemp.createTemp('sync-remote-');
    addTearDown(() => localRoot.delete(recursive: true));
    addTearDown(() => remoteRoot.delete(recursive: true));

    final local = FilesystemBlobStore(localRoot);
    final remote = FilesystemBlobStore(remoteRoot);

    await local.putIfAbsent('a.json', Uint8List.fromList([1]));
    await remote.putIfAbsent('b.json', Uint8List.fromList([2]));
    await remote.putIfAbsent('a.json', Uint8List.fromList([1]));

    await syncBlobStores(local, remote);

    expect(await local.get('a.json'), [1]);
    expect(await local.get('b.json'), [2]);
    expect(await remote.get('a.json'), [1]);
    expect(await remote.get('b.json'), [2]);
  });

  test('sync is idempotent', () async {
    final localRoot = await Directory.systemTemp.createTemp('sync-local-');
    final remoteRoot = await Directory.systemTemp.createTemp('sync-remote-');
    addTearDown(() => localRoot.delete(recursive: true));
    addTearDown(() => remoteRoot.delete(recursive: true));

    final local = FilesystemBlobStore(localRoot);
    final remote = FilesystemBlobStore(remoteRoot);

    await local.putIfAbsent('a.json', Uint8List.fromList([1]));

    await syncBlobStores(local, remote);
    await syncBlobStores(local, remote);

    expect((await local.list('')).length, 1);
    expect((await remote.list('')).length, 1);
  });
}
