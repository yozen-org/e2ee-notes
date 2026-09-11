import 'dart:io';
import 'dart:typed_data';

import 'package:storage_api/storage_api.dart';

// 保存キーをルート配下のファイルに対応付けるローカル保存アダプター。
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
    // 同じ内容の再保存は許容し、違う内容なら競合にする。複数プロセス間の原子的な作成は未対応。
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
      final relative = entity.absolute.path.substring(_root.path.length + 1);
      final key = relative.replaceAll(Platform.pathSeparator, '/');
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

  // 空のキー・絶対パス・親への移動を拒否し、OSの区切り文字に変換する。
  String _pathFor(String key) {
    if (key.isEmpty || key.startsWith('/') || key.split('/').contains('..')) {
      throw ArgumentError.value(key, 'key', 'must be a relative object key');
    }
    return '${_root.path}${Platform.pathSeparator}${key.replaceAll('/', Platform.pathSeparator)}';
  }

  bool _sameBytes(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }
}
