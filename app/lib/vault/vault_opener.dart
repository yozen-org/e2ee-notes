import '../notes/encrypted_notes_repository.dart';
import 'request_key_policy.dart';

typedef VaultOpener = Future<EncryptedNotesRepository> Function(
  RequestKeyPolicy requestPolicy,
);
