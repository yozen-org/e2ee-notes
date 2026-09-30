import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Derives the server namespace for a vault from its vault key.
///
/// The namespace addresses this vault's objects on the server. It is a one-way
/// derivation, so it does not reveal the vault key. The domain separator keeps
/// this derivation independent from any other use of the vault key.
Future<String> vaultNamespace(Uint8List vaultKey) async {
  final domain = utf8.encode('yozen.e2ee-notes.sync-namespace.v1');
  final digest = await Sha256().hash([...domain, ...vaultKey]);
  return digest.bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
