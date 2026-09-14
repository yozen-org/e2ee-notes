import 'dart:typed_data';

import 'key_record.dart';

final class GeneratedKey {
  GeneratedKey(Uint8List vaultKey, this.record)
    : _vaultKey = Uint8List.fromList(vaultKey);
  final Uint8List _vaultKey;
  Uint8List get vaultKey => Uint8List.fromList(_vaultKey);
  final KeyRecord record;
}
