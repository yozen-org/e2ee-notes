// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'E2EE Notes';

  @override
  String couldNotOpenVault(String error) {
    return 'Could not open vault: $error';
  }

  @override
  String get retry => 'Retry';

  @override
  String couldNotLoadNotes(String error) {
    return 'Could not load notes: $error';
  }

  @override
  String get newNote => 'New note';

  @override
  String get editNote => 'Edit note';

  @override
  String get untitled => 'Untitled';

  @override
  String get deleteNote => 'Delete';

  @override
  String get encryptAndSave => 'Encrypt & save';

  @override
  String couldNotSaveNote(String error) {
    return 'Could not save note: $error';
  }

  @override
  String get saveVaultKeyQuestion => 'Save the vault key on this device?';

  @override
  String get saveVaultKeyHardware =>
      'Use this device\'s hardware to protect the key that unlocks your notes.';

  @override
  String get saveVaultKeySoftware =>
      'Hardware protection is unavailable. The key will be stored without hardware protection on this device.';

  @override
  String get cancel => 'Cancel';

  @override
  String get continueAction => 'Continue';

  @override
  String get pairingTitle => 'Device pairing';

  @override
  String get pairingSend => 'Send from this device';

  @override
  String get pairingSendSubtitle =>
      'Scan the other device\'s QR code to hand over this device\'s data';

  @override
  String get pairingReceive => 'Receive from another device';

  @override
  String get pairingReceiveSubtitle =>
      'Bring another device\'s data into this one';

  @override
  String get pairingSendTitle => 'Send';

  @override
  String get scanRecipientQr => 'Scan the other device\'s QR code';

  @override
  String get showQrToOther => 'Have the other device scan this QR code';

  @override
  String get pairingReceiveTitle => 'Receive';

  @override
  String get scanAndContinue => 'Scan to continue';

  @override
  String get scanQrTitle => 'Scan QR code';

  @override
  String get scanQrFailed => 'Failed to read the QR code';

  @override
  String get pairingFailed => 'Operation failed';

  @override
  String get serverSettings => 'Exchange server settings';

  @override
  String get serverSettingsSubtitle => 'Configure the sync server URL';

  @override
  String get serverSettingsLabel =>
      'Exchange server URL (you can point it at a self-hosted server)';

  @override
  String get saved => 'Saved';

  @override
  String get save => 'Save';
}
