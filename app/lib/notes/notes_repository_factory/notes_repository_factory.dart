import '../../vault/opened_vault.dart';
import '../encrypted_notes_repository.dart';

abstract interface class NotesRepositoryFactory {
  EncryptedNotesRepository create(OpenedVault vault);
}
