# Windows・LinuxのTPM対応

`PlatformSecureKey` が Windows と Linux では `TpmSecureKey` を選びます。
アプリは `SecureKey` と1つの `VaultKeyStorage` を利用し、TPM 固有の保存形式を扱いません。
TPM がない端末での新規保存には、ソフトウェア方式への明示的な同意が必要です。
既存の保護済み鍵があれば、TPM が使えなくても別の鍵には切り替えず、復元エラーを返します。

## コードの配置

- `packages/secure_keys/lib/src/platform_secure_key.dart`：方式の選択と方針の適用。
- `packages/secure_keys/lib/src/tpm/tpm_secure_key.dart`：共通 API による生成・保護・復元。
- `packages/secure_keys/lib/src/tpm/tpm_keys.dart`：ネイティブの protect/unprotect の契約。
- `app/lib/vault/vault_key_service.dart`：鍵情報の保存と再読込による検証。
- `app/lib/vault/file_vault_key_storage.dart`：レコードのファイル保存。
- `app/lib/vault/legacy_vault_key_migration.dart`：旧形式の読込と検証。

新規の保護済み blob は `vault-key.json` のレコード内に保存します。
旧 `vault-key.tpm` も読み込めます。鍵は保護直後と保存後に復元・照合します。
保存には一時ファイルと rename を使います。旧平文鍵は保護済みレコードとの一致を確認後に削除します。
同時に複数プロセスで初期化する用途や、電源断時のディレクトリエントリの永続化保証は未対応です。

## Windows

Windows SDKに含まれるCNGとTPM Base Servicesを使います。追加の暗号ライブラリは不要です。
FlutterのWindows開発環境と、利用可能なTPM 2.0が必要です。

Microsoft Platform Crypto Providerに、現在のWindowsユーザー用のRSA-2048鍵を作成します。
この鍵は複数の保管庫のKを包むために再利用し、既存鍵を上書きしません。
KはRSA-OAEP-SHA256で暗号化し、保存レコードに含めます。
TPMの鍵を開けない場合、復元処理は代わりの鍵を生成しません。

## Linux

ビルドには`tpm2-tss`のESAPI・MU・TCTI Loaderが必要です。
Ubuntu系では、FlutterのLinux開発依存に加えて以下を導入します。

```sh
sudo apt install libtss2-dev
```

実行時にはこれらの共有ライブラリとdevice TCTIが必要です。
本番の接続先は`device:/dev/tpmrm0`で、環境変数からエミュレーターへ自動的に切り替わる構成にはしていません。
ユーザーにデバイスへのアクセス権限が必要です。設定はディストリビューションのTPMデバイス管理に従ってください。

owner階層の認証値が空である構成を対象にしています。認証値を設定済みのTPMではエラーになります。
アプリがTPMのclear・provision・認証値変更を行うことはありません。
owner階層から同じテンプレートでストレージ親鍵を再生成し、Kを含むsealed objectを保存・復元します。
TPMとのKの受け渡しには、salt付きHMACセッションとAES-CFBによるパラメーター暗号化を使います。
永続ハンドルの予約やFAPIの外部メタデータストアは使いません。

## 保護の範囲

この実装は端末内でのKの保存用です。端末間で送るエンベロープとは別の形式です。
復元後のKはアプリのメモリ上に存在します。メモ本体の暗号化は従来どおりアプリ側で行います。

PCRによる起動状態への束縛、PIN、生体認証は追加していません。
WindowsではユーザーのCNG鍵ストア、Linuxでは保存先のファイル権限とTPMデバイスのアクセス権限が利用者を制限します。
Linuxではsealed object自体に追加のパスワードを設定していないため、保存ファイルとTPMへのアクセスを両方持つプロセスは復元できます。
物理TPMと仮想TPMをリモート証明で判別する機能もありません。

TPMを初期化・交換した場合は鍵を復元できません。
WindowsではCNG鍵ストアの削除でも復元できなくなります。
`vault-key.tpm`だけを別端末へコピーしても復元できず、端末紛失時の復旧機能は別途必要です。

## 検証

Dartのテストは、TPMの境界だけをFakeに置き換え、実際のSecureKey・Service・ファイル保存を通します。
ネイティブの検証用実行ファイルはFlutterなしでもビルドできます。

```sh
cmake -S packages/secure_keys/native_test -B build/tpm-tests
cmake --build build/tpm-tests --config Debug
ctest --test-dir build/tpm-tests -C Debug --output-on-failure
```

通常のCTestはTPM不要の入力検証を行います。
Windowsの実機では、次の追加テストがTPM鍵を作成・利用します。

```powershell
build/tpm-tests/Debug/tpm_key_store_test.exe --tpm
```

Linuxのエミュレーターテストには`libtpms`と`tpm2-tss`のlibtpms TCTIが必要です。
以下は隔離した二つのTPM状態を使い、別TPMでの復元失敗も確認します。

```sh
test_state=$(mktemp -d)
build/tpm-tests/tpm_key_store_test "libtpms:$test_state/first" "libtpms:$test_state/second"
```

エミュレーターの接続先を指定するのは検証用実行ファイルだけです。
TPM実機での再起動後の復元、OSの権限設定、Flutterアプリの動作確認は対象OSで別途行います。

## 参照

- [MicrosoftのCNG Key Storage Providers](https://learn.microsoft.com/en-us/windows/win32/seccertenroll/cng-key-storage-providers)
- [NCryptEncrypt](https://learn.microsoft.com/en-us/windows/win32/api/ncrypt/nf-ncrypt-ncryptencrypt)
- [TPM2_CreateのESAPI](https://tpm2-tss.readthedocs.io/en/latest/group___esys___create.html)
- [TPM2_UnsealのESAPI](https://tpm2-tss.readthedocs.io/en/latest/group___esys___unseal.html)
