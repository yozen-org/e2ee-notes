import 'dart:typed_data';

void validateVaultKey(Uint8List key) {
  if (key.length != 32) {
    throw const FormatException('invalid vault-key length');
  }
}

void requireMatchingVaultKeys(Uint8List expected, Uint8List actual) {
  validateVaultKey(expected);
  validateVaultKey(actual);
  var difference = 0;
  for (var index = 0; index < 32; index++) {
    difference |= expected[index] ^ actual[index];
  }
  if (difference != 0) {
    throw const FormatException('vault keys differ');
  }
}
