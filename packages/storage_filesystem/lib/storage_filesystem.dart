import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:storage_api/storage_api.dart';

final class FilesystemBlobStore implements BlobStore {
  FilesystemBlobStore(Directory root) : _root = root.absolute;
  final Directory _root;

  @override
  Future<Uint8List> get(String key) async {
    final file = File(_pathFor(key));
    if (!await file.exists()) throw ObjectNotFound(key);
    return file.readAsBytes();
  }

  @override
  Future<void> putIfAbsent(String key, Uint8List value) async {
    final file = File(_pathFor(key));
    await file.parent.create(recursive: true);

    if (await file.exists()) {
      final existing = await file.readAsBytes();
      if (!_sameBytes(existing, value)) throw ObjectConflict(key);
      return;
    }
    await file.writeAsBytes(value, flush: true);
  }

  @override
  Future<List<String>> list(String prefix) async {
    if (!await _root.exists()) return const [];
    final result = <String>[];
    await for (final entity in _root.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final relative = p.relative(entity.path, from: _root.path);
      final key = p.posix.joinAll(p.split(relative));
      if (key.startsWith(prefix)) result.add(key);
    }
    return result..sort();
  }

  @override
  Future<void> delete(String key) async {
    final file = File(_pathFor(key));
    if (!await file.exists()) throw ObjectNotFound(key);
    await file.delete();
  }

  String _pathFor(String key) {
    if (key.isEmpty || key.startsWith('/') || key.split('/').contains('..')) {
      throw ArgumentError.value(key, 'key', 'must be a relative object key');
    }
    final path = p.joinAll([_root.path, ...key.split('/')]);
    if (!p.isWithin(_root.path, path)) {
      throw ArgumentError.value(
        key,
        'key',
        'must stay within the storage root',
      );
    }
    return path;
  }

  bool _sameBytes(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }
}
