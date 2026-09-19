import '../opened_vault.dart';

sealed class VaultState {
  const VaultState();
}

final class VaultNotOpened extends VaultState {
  const VaultNotOpened();
}

final class VaultOpening extends VaultState {
  const VaultOpening();
}

final class VaultOpened extends VaultState {
  const VaultOpened(this.vault);

  final OpenedVault vault;
}

final class VaultOpenFailed extends VaultState {
  const VaultOpenFailed(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}
