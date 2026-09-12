import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:secure_keys/secure_enclave.dart';

import '../vault_key_files/recipient_key_handle_file.dart';
import '../vault_key_files/vault_key_envelope_file.dart';
import 'vault_key_repository.dart';

final class SecureEnclaveVaultKeyRepository implements VaultKeyRepository {
  SecureEnclaveVaultKeyRepository(this.root, this.recipient);

  final Directory root;
  final RecipientKey recipient;

  @override
  Future<bool> exists() => VaultKeyEnvelopeFile(root).exists();

  @override
  Future<Uint8List> read() async => Uint8List.fromList(
    utf8.encode(jsonEncode((await VaultKeyEnvelopeFile(root).read()).toMap())),
  );

  @override
  Future<void> write(Uint8List bytes) async {
    final envelope = VaultKeyEnvelope.fromMap(
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
    );
    await RecipientKeyHandleFile(root).write(recipient.handle);
    await VaultKeyEnvelopeFile(root).write(envelope);
    await File(p.join(root.path, 'recipient-public.json'))
        .writeAsString(jsonEncode(recipient.publicKey.toMap()), flush: true);
  }
}
