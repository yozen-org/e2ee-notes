import 'package:flutter/foundation.dart';

import '../key_policy/request_key_policy.dart';
import '../vault_opener/vault_opener.dart';
import 'vault_state.dart';

final class VaultController extends ChangeNotifier {
  VaultController({required this._vaultOpener});

  final VaultOpener _vaultOpener;
  VaultState _state = const VaultNotOpened();
  bool _disposed = false;

  VaultState get state => _state;

  Future<void> open(RequestKeyPolicy requestPolicy) async {
    if (_state is VaultOpening) return;
    _setState(const VaultOpening());
    try {
      final vault = await _vaultOpener(requestPolicy);
      if (!_disposed) _setState(VaultOpened(vault));
    } on Object catch (error, stackTrace) {
      if (!_disposed) _setState(VaultOpenFailed(error, stackTrace));
    }
  }

  void _setState(VaultState state) {
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
