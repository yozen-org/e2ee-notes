import 'dart:convert';
import 'dart:typed_data';

/// Opaque, versioned persistence data. Storage copies [encode] without interpreting it.
final class KeyRecord {
  KeyRecord(String provider, Map<String, Object?> data)
    : _json = jsonEncode({'version': 1, 'provider': provider, 'data': data});
  KeyRecord._(this._json);
  final String _json;

  factory KeyRecord.decode(Uint8List bytes) {
    final json = utf8.decode(bytes);
    final value = jsonDecode(json);
    if (value is! Map<String, dynamic> ||
        value['version'] != 1 ||
        value['provider'] is! String ||
        value['data'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid key record');
    }
    return KeyRecord._(json);
  }

  Uint8List encode() => Uint8List.fromList(utf8.encode(_json));
  // Used by implementations inside this package, not by persistence adapters.
  String get provider => (jsonDecode(_json) as Map)['provider'] as String;
  Map<String, dynamic> get data =>
      (jsonDecode(_json) as Map)['data'] as Map<String, dynamic>;
}
