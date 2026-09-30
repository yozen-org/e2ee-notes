import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:secure_keys/secure_keys.dart';

import '../../l10n/app_localizations.dart';
import '../../notes/logic/notes_service.dart';
import '../../notes/ui/notes_screen.dart';
import '../../sync/exchange_server_settings.dart';
import '../../sync/server_settings_screen.dart';
import '../../sync/sync_vault.dart';
import '../opened_vault.dart';
import '../vault_root.dart';
import 'import_vault.dart';
import 'pairing_qr.dart';

/// Entry point for pairing two devices. The vault key is exchanged directly
/// via QR; the encrypted operation log is synced over the exchange server.
class PairingScreen extends StatelessWidget {
  const PairingScreen({
    required this.secureKey,
    required this.vault,
    super.key,
  });

  final SecureKey secureKey;
  final OpenedVault vault;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pairingTitle)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: Text(l10n.pairingSend),
            subtitle: Text(l10n.pairingSendSubtitle),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _SendPage(secureKey: secureKey, vault: vault),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: Text(l10n.pairingReceive),
            subtitle: Text(l10n.pairingReceiveSubtitle),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => _ReceivePage(secureKey: secureKey)),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text(l10n.serverSettings),
            subtitle: Text(l10n.serverSettingsSubtitle),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ServerSettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _SendPage extends StatefulWidget {
  const _SendPage({required this.secureKey, required this.vault});

  final SecureKey secureKey;
  final OpenedVault vault;

  @override
  State<_SendPage> createState() => _SendPageState();
}

class _SendPageState extends State<_SendPage> {
  String? _envelopeQr;

  Future<void> _scanRecipient() async {
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _ScanPage()),
    );
    if (value == null || !mounted) return;
    try {
      final recipient = decodeRecipientQr(value);
      final envelope = await widget.secureKey.envelope(
        widget.vault.vaultKey,
        recipient,
      );
      if (mounted) setState(() => _envelopeQr = encodeEnvelopeQr(envelope));
    } on Object {
      if (mounted) _showError();
    }
  }

  void _showError() {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.scanQrFailed)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final qr = _envelopeQr;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pairingSendTitle)),
      body: qr == null
          ? Center(
            child: FilledButton(
              onPressed: _scanRecipient,
              child: Text(l10n.scanRecipientQr),
            ),
          )
          : Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                QrImageView(data: qr, size: 240),
                const SizedBox(height: 16),
                Text(l10n.showQrToOther),
              ],
            ),
          ),
    );
  }
}

class _ReceivePage extends StatefulWidget {
  const _ReceivePage({required this.secureKey});

  final SecureKey secureKey;

  @override
  State<_ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<_ReceivePage> {
  RecipientKey? _recipientKey;
  String? _publicKeyQr;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      final key = await widget.secureKey.createRecipientKey(
        policy: const KeyPolicy(),
      );
      if (mounted) {
        setState(() {
          _recipientKey = key;
          _publicKeyQr = encodeRecipientQr(key.publicKey);
        });
      }
    } on Object {
      if (mounted) _showError();
    }
  }

  Future<void> _scanEnvelope() async {
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _ScanPage()),
    );
    final key = _recipientKey;
    if (value == null || key == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final envelope = decodeEnvelopeQr(value);
      final root = await vaultRoot();
      final vault = await importVault(
        root,
        secureKey: widget.secureKey,
        envelope: envelope,
        recipientKey: key,
        policy: const KeyPolicy(),
      );
      await syncVault(vault, serverUrl: await loadExchangeServerUrl());
      final service = await createNotesService(vault);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => NotesScreen(
              service: service,
              secureKey: widget.secureKey,
              vault: vault,
            ),
          ),
          (_) => false,
        );
      }
    } on Object {
      if (mounted) {
        setState(() => _busy = false);
        _showError();
      }
    }
  }

  void _showError() {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.pairingFailed)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_busy) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final qr = _publicKeyQr;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pairingReceiveTitle)),
      body: qr == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                QrImageView(data: qr, size: 240),
                const SizedBox(height: 16),
                Text(l10n.showQrToOther),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _scanEnvelope,
                  child: Text(l10n.scanAndContinue),
                ),
              ],
            ),
          ),
    );
  }
}

class _ScanPage extends StatefulWidget {
  const _ScanPage();

  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> {
  bool _handled = false;

  void _handle(String value) {
    if (_handled) return;
    _handled = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.scanQrTitle)),
      body: MobileScanner(
        onDetect: (capture) {
          for (final barcode in capture.barcodes) {
            final value = barcode.rawValue;
            if (value != null) {
              _handle(value);
              break;
            }
          }
        },
      ),
    );
  }
}
