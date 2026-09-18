import '../../vault/opened_vault.dart';
import '../encrypted_notes_repository.dart';
import 'notes_repository_factory.dart';

final class EncryptedNotesRepositoryFactory implements NotesRepositoryFactory {
  const EncryptedNotesRepositoryFactory();

  @override
  EncryptedNotesRepository create(OpenedVault vault) {
    return EncryptedNotesRepository(
      store: vault.store,
      vaultKey: vault.vaultKey,
      deviceId: vault.deviceId,
    );
  }
}
