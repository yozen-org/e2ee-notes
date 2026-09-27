import 'package:flutter/foundation.dart';

import '../key_policy/request_key_policy.dart';
import '../vault_opener/vault_opener.dart';
import 'vault_state.dart';

final class VaultController extends ValueNotifier<VaultState> {
  VaultController({required this._vaultOpener}) : super(const VaultNotOpened());

  final VaultOpener _vaultOpener;
  bool _disposed = false;

  Future<void> open({required RequestKeyPolicy requestKeyPolicy}) async {
    if (value is VaultOpening) return;
    value = const VaultOpening();
    try {
      final vault = await _vaultOpener.open(requestKeyPolicy: requestKeyPolicy);
      if (!_disposed) value = VaultOpened(vault);
    } on Object catch (error, stackTrace) {
      if (!_disposed) value = VaultOpenFailed(error, stackTrace);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
