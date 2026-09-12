# Windows・LinuxのTPM対応

WindowsとLinuxでは、起動時に`TpmVaultKeyStorage`を選択し、共通の`VaultKeyProvider`へ渡します。
TPM 2.0がない端末では従来のソフトウェア鍵を使用します。
すでに`vault-key.tpm`がある場合は、TPMが使えなくてもソフトウェア鍵には切り替えず、復元エラーを返します。
権限不足やTPM操作の失敗もエラーとして扱います。

## コードの配置

- `app/lib/src/vault_key_provider.dart`：全保存方式に共通の鍵の復元・移行・新規作成。
- `app/lib/src/vault_key_storage/tpm_vault_key_storage.dart`：TPMによるKの保護・復元と保存。
- `app/lib/src/vault_key_files/tpm_protected_key_file.dart`：保護済み鍵の保存。
- `packages/secure_keys/lib/src/tpm/tpm_keys.dart`：TPMによる鍵の保護・復元の契約。
- `packages/secure_keys/lib/src/tpm/method_channel_tpm_keys.dart`：Flutterからネイティブ実装への接続。
- `packages/secure_keys/windows/tpm_key_store.cpp`：WindowsのCNGによる鍵のラップ。
- `packages/secure_keys/linux/tpm_key_store.cc`：LinuxのTPM 2.0によるseal・unseal。
- `packages/secure_keys/linux/tpm_context.cc`：TPMへの接続とリソースの解放。
- `packages/secure_keys/linux/tpm_sealed_blob.cc`：TPMの保存データの直列化。

## 鍵を開く流れ

1. 保護済み鍵があれば復元する。
2. Apple用の鍵ファイルがあれば、別方式の鍵を勝手に生成せず停止する。
3. TPMがなければソフトウェア鍵を使う。
4. 既存のソフトウェア鍵があれば、そのKを保護する形に移行する。
5. 鍵がなければ、Kをメモリ上で生成する。

Storageは保護した直後にKを復元し、元のKと一致することを確認します。
Providerは保存後にもStorageから読み直し、一致を確認してからKを返します。
保存には同じディレクトリ配下の一時ファイルとrenameを使います。
新規Kを平文ファイルへは書き込みません。移行元の平文鍵は、保護済み鍵を保存してから一致を確認して削除します。
保存後、削除前に終了した場合は、次回の復元時に同じ確認と削除を行います。

既存の保管庫と同様に、同じ保存先を複数プロセスから同時に初期化する用途には未対応です。
ファイルのflushとrenameを行いますが、電源断に対するディレクトリエントリの永続化保証までは実装していません。

## Windows

Windows SDKに含まれるCNGとTPM Base Servicesを使います。追加の暗号ライブラリは不要です。
FlutterのWindows開発環境と、利用可能なTPM 2.0が必要です。

Microsoft Platform Crypto Providerに、現在のWindowsユーザー用のRSA-2048鍵を作成します。
この鍵は複数の保管庫のKを包むために再利用し、既存鍵を上書きしません。
KはRSA-OAEP-SHA256で暗号化して`vault-key.tpm`に保存します。
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

Dartのテストは、TPMの境界だけをFakeに置き換え、実際のProviderとファイル保存を通します。
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
