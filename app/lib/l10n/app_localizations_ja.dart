// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'E2EE Notes';

  @override
  String get vaultSubtitle => 'ローカル暗号化 vault · 利用可能な場合はハードウェア保護';

  @override
  String couldNotOpenVault(String error) {
    return 'vault を開けませんでした: $error';
  }

  @override
  String get retry => '再試行';

  @override
  String couldNotLoadNotes(String error) {
    return 'ノートを読み込めませんでした: $error';
  }

  @override
  String get newNote => '新しいノート';

  @override
  String get editNote => 'ノートを編集';

  @override
  String get untitled => '無題';

  @override
  String get deleteNote => '削除';

  @override
  String get noteTitleLabel => 'タイトル';

  @override
  String get noteBodyLabel => '本文';

  @override
  String get encryptAndSave => '暗号化して保存';

  @override
  String couldNotSaveNote(String error) {
    return 'ノートを保存できませんでした: $error';
  }

  @override
  String get emptyNotesHeadline => 'あなたのノート、あなたの鍵、あなたのストレージ。';

  @override
  String get emptyNotesBody => 'ノートを作成してください。暗号化された操作だけが保存されます。';

  @override
  String get saveVaultKeyQuestion => 'このデバイスに vault キーを保存しますか？';

  @override
  String get saveVaultKeyHardware => 'このデバイスのハードウェアで、ノートを復号する鍵を保護します。';

  @override
  String get saveVaultKeySoftware =>
      'ハードウェア保護は利用できません。このデバイスでは鍵はハードウェア保護なしで保存されます。';

  @override
  String get cancel => 'キャンセル';

  @override
  String get continueAction => '続行';
}
