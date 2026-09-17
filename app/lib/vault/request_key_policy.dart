import 'package:secure_keys/secure_keys.dart';

typedef RequestKeyPolicy = Future<KeyPolicy> Function(
  KeyCapabilities capabilities,
);
