# アーキテクチャ

```text
Flutter UI
    |
アプリケーションサービス
    +-- E2EEコア
    +-- ハードウェア鍵のインターフェース
    +-- ストレージのインターフェース
             +-- ファイルシステム
             +-- S3/R2、WebDAV、Drive（今後対応）
```

E2EEコアは、バージョン付きの平文モデル、認証付き暗号化、操作の順序付け、
競合、スナップショットを担当します。Flutter、ファイルシステムAPI、
クラウドSDK、プラットフォーム固有の鍵APIはインポートしません。

ストレージアダプターが受け取るのは、内容を解釈しないバイト列とオブジェクトキーだけです。
保管庫の鍵や復号済みのメモは受け取りません。ハードウェア鍵アダプターは、
取り出せない受信者鍵を生成し、その公開鍵ドキュメントを出力し、
保管庫の鍵エンベロープをアンラップ（保護された鍵を復元）します。
同期処理は担当しません。

| プラットフォーム | ハードウェアで保護する受信者鍵 |
| --- | --- |
| macOS/iOS | Swift経由のSecure Enclave |
| Android | Android Keystore（StrongBoxを優先） |
| Windows | CNG Platform Crypto Provider / TPM |
| Linux | TPM 2.0のリソースマネージャーデバイス |

ハードウェア対応の判断は、端末が実際に提供する機能に基づきます。
クライアントは、どの端末でも同じ保護水準があるかのように扱うのではなく、
鍵がハードウェアで保護されているかどうかを報告しなければなりません。

```text
メモを編集
   -> 正規化された操作
   -> 保管庫の鍵 K による認証付き暗号化
   -> 変更されない暗号化オブジェクト
   -> 選択したストレージアダプター
```

別の認可済み端末は、同じ `K` をアンラップし、変更されないオブジェクトの一覧を取得して、
端末内で認証・復号を行い、メモの状態を再構築します。

アプリの初期化処理では、プラットフォームのアプリケーションサポートディレクトリに、
保管庫の鍵と端末IDを用意します。Secure Enclaveを備えたApple端末では、
保護済みの鍵があれば復元し、既存のソフトウェア鍵があれば同じ鍵を保護する形に移行します。
どちらもなければ、鍵をメモリ上で生成します。受信者鍵ハンドルと鍵エンベロープを保存し、
新規の鍵を平文ファイルには書き込みません。移行時は鍵の保護・検証・保存が完了した後、
元のソフトウェア鍵ファイルを削除します。WindowsとLinuxではTPM 2.0でKを保護します。
TPMがない端末と、ハードウェアアダプターが未実装のプラットフォームでは、
ソフトウェア鍵へのフォールバックを引き続き使用します。
TPMで保護済みの鍵が復元できない場合は、フォールバックせず停止します。
設定と制約は[TPM対応](TPM.md)を参照してください。
ストレージプロバイダーのルートに当たるのは、`storage/`サブディレクトリだけです。

初期のDart製ファイルシステムアダプターは、通常の単一プロセスでのアプリ利用において、
既存オブジェクトが変更されないことを保証します。並行して同期処理を行う前に、
複数プロセス間での原子的な作成と、プロバイダー側での条件付き書き込みに対応する必要があります。

## 起動時の依存関係の組み立て

`app/lib/src/vault_bootstrap.dart`のswitch式でOSに応じた`VaultKeySelector`を選びます。
`LocalVault`は`keySelectorFactory`を受け取り、保存ディレクトリを準備してから
Selectorの`select()`で`VaultKeyService`を組み立てます。

```text
vault_bootstrap → OSに対応するVaultKeySelector
                         ↓ select()
                   VaultKeyService
                     ├─ EncryptionKey
                     ├─ DecryptionKey
                     ├─ VaultKeyRepository
                     └─ 移行元のPlaintextVaultKeyRepository（必要な場合）
```

`app/lib/src/vault_key_selection/`の各Selectorが、保存済みの鍵参照と端末の利用可否を判断します。
Secure EnclaveのCapabilitiesとTPMの`isAvailable()`はこの段階で使い、Serviceへ渡しません。
既存の保護鍵を優先し、その復元に失敗しても平文保存へ切り替えません。
不完全なApple鍵ファイルや別方式の保護鍵があれば、鍵を生成せずエラーにします。
平文用Selectorも保護鍵ファイルを確認し、未対応OSで別のKを作ることを防ぎます。

Secure Enclaveでは、保存済みハンドルから`openRecipientKey`で同じ鍵を再取得します。
公開鍵はハンドルからネイティブ側で導くため、既存の`recipient-public.json`がなくても復元できます。
新規作成時だけ受信者鍵を生成し、公開鍵側と秘密鍵側の操作をServiceに渡します。
TPMでは既存のネイティブ接続を使う暗号化・復号アダプターを渡します。
Windowsの永続鍵の取得とLinuxのストレージ親鍵の再構成は、引き続きネイティブ実装が担当します。

## 鍵の操作・保存・ライフサイクルの境界

`VaultKeyService`は32バイトのKの生成・復元・平文鍵からの移行を担当します。
OS、Capabilities、ハンドル、エンベロープの形式を知りません。
保護する場合は`EncryptionKey`と`DecryptionKey`の両方を必須で受け取ります。
署名は現在のVaultの処理で使わないため、`SigningKey`は依存に含めません。
平文保存は明示的な`VaultKeyService.plaintext`で構成し、暗号化したことにはしません。

`app/lib/src/vault_key_repository/`は保存形式ごとの読み書きを担当します。
共通契約は`exists()`・`read()`・`write(bytes)`だけで、暗号操作や利用可否判定は含みません。
保護用Repositoryが受け取るのは暗号化済みバイト列です。
Secure Enclave用はハンドル・エンベロープ・公開鍵ドキュメント、TPM用は保護済みblobを保存します。
ファイル名と保存形式は従来どおりです。

Serviceは暗号化直後に復号してKの一致を確認し、保存後にも読み直して再度復号・検証します。
移行元の平文ファイルは、これらの検証と元ファイルとの一致確認に成功してから削除します。
保存後に終了して平文鍵が残った場合も、次回の復元時に同じ確認を行います。

テストでは本番と同じSelector・Service・Repositoryを通し、ネイティブ接続を代替実装へ差し替えます。
Service単体のテストでは操作能力とRepositoryを差し替え、保存先に暗号文が渡ることや
保存後の検証に失敗した際に移行元を残すことを確認します。

## 鍵の操作能力の契約

`packages/secure_keys/lib/src/`には、Vaultに依存しない以下のインターフェースを定義しています。
`package:secure_keys/secure_keys.dart`からまとめてインポートできます。
現在のVaultでは`EncryptionKey`と`DecryptionKey`を使います。
残りの操作能力は契約のみで、署名・検証などの実装は追加していません。

| インターフェース | 操作 |
| --- | --- |
| `KeyGenerator<K>` | `generate()`で型Kの鍵オブジェクトを生成する |
| `SigningKey` | `sign(message)`でメッセージに署名する |
| `VerificationKey` | `verify(message: ..., signature: ...)`で署名を検証する |
| `DecryptionKey` | `decrypt(ciphertext)`で復号する |
| `EncryptionKey` | `encrypt(plaintext)`で暗号化する |
| `KeyAgreementKey` | `deriveSharedSecret(encodedPeerPublicKey)`で共有秘密を導く |

各操作は非同期で、メッセージ・署名・暗号文・共有秘密は`Uint8List`で受け渡します。
署名・検証の入力は事前計算したダイジェストではなくメッセージです。
署名が一致しない場合は`false`、接続や権限などの操作失敗は例外で伝えます。
鍵生成の戻り値Kは鍵を操作するオブジェクトを想定し、秘密鍵の生バイト列の取得を要求しません。
アルゴリズムや署名・暗号文・公開鍵の符号化形式は、実装を接続する際に対応する鍵型の契約として定めます。
鍵の再取得、永続化、Vaultの組み立てはこれらの操作能力に含めません。

公開APIは`secure_keys.dart`（操作能力）、`secure_enclave.dart`（既存のSecure Enclave接続）、
`tpm.dart`（既存のTPM接続）から参照します。
各方式のDart実装は`src/secure_enclave/`と`src/tpm/`に配置しています。
ネイティブ実装はFlutterプラグインの規約に従い、各OSのディレクトリに配置します。

## 現在接続している暗号操作の範囲

`SecureEnclaveEncryptionKey`・`SecureEnclaveDecryptionKey`は既存の
`wrapVaultKey`・`unwrapVaultKey`へのアダプターです。
入力平文は32バイト、暗号文は従来のエンベロープJSONのUTF-8バイト列です。
暗号スイートは`P256-HKDF-SHA256-AES256GCM`で、暗号化は受信者公開鍵を使い、
復号は選択済みのSecure Enclave鍵ハンドルを使います。

`TpmEncryptionKey`・`TpmDecryptionKey`も入力平文は32バイトです。
Windowsでは既存のRSA-OAEPによるラップ、Linuxでは既存のseal・unsealを使います。
暗号文はOS固有の保護済みblobで、Windows・Linux間の相互復号には対応しません。
Linuxのsealを公開鍵暗号や鍵共有として公開しているわけではありません。
これらは現在のKの保護に必要な操作を接続したもので、任意長のメッセージ暗号化や
任意の鍵を選ぶ汎用ネイティブAPIへの拡張は行っていません。
