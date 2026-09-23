import 'package:flutter/material.dart';
import 'package:secure_keys/secure_keys.dart';

import '../../l10n/app_localizations.dart';

Future<KeyPolicy> showKeyPolicyDialog(
  BuildContext context,
  KeyCapabilities capabilities,
) async {
  final l10n = AppLocalizations.of(context)!;
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(l10n.saveVaultKeyQuestion),
      content: Text(
        capabilities.hardwareBacked
            ? l10n.saveVaultKeyHardware
            : l10n.saveVaultKeySoftware,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.continueAction),
        ),
      ],
    ),
  );
  if (accepted != true) throw StateError('Vault opening cancelled');
  return KeyPolicy(allowSoftware: !capabilities.hardwareBacked);
}
