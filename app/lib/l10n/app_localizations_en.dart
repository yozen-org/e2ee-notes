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
}
