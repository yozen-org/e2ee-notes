import 'package:flutter/material.dart';
import 'package:secure_keys/secure_keys.dart';

Future<KeyPolicy> showKeyPolicyDialog(
  BuildContext context,
  KeyCapabilities capabilities,
) async {
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Save the vault key on this device?'),
      content: Text(
        capabilities.hardwareBacked
            ? 'Use this device’s hardware to protect the key that unlocks your notes.'
            : 'Hardware protection is unavailable. The key will be stored without hardware protection on this device.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  if (accepted != true) throw StateError('Vault opening cancelled');
  return KeyPolicy(allowSoftware: !capabilities.hardwareBacked);
}
