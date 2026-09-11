# TPMローカル鍵の保存形式 v1

`vault-key.tpm`は32バイトの保管庫鍵Kを端末内で保護するためのファイルです。
`KEY_ENVELOPE_V1.md`の端末間受け渡し用JSONとは互換性がありません。
ファイルの先頭4バイトでOSと形式のバージョンを識別します。
不明な形式、サイズ不正、復元に失敗するデータを、新規作成の契機にしてはいけません。

## Windows：`45 54 57 01`

ヘッダーに続けて、RSA-2048による256バイトの暗号文を保存します。全体で260バイトです。
暗号化方式はOAEP、ハッシュはSHA-256、ラベルは空です。

鍵はMicrosoft Platform Crypto Providerの現在のユーザー用ストアに保存します。
鍵名は`yozen.e2ee-notes.vault-wrap.v1`です。秘密鍵のエクスポートは許可しません。
この鍵名・暗号方式を変更する場合は、既存データを復元できる移行方式が必要です。

## Linux：`45 54 4c 01`

ヘッダーの後に、tpm2-tssのMU関数によって直列化した以下の構造体を順に保存します。

1. `TPM2B_PRIVATE`：TPMによって暗号化・完全性保護されたsealed objectの秘密部分。
2. `TPM2B_PUBLIC`：sealed objectの公開部分。

MUの規定に従うバイト順を使用し、構造体のメモリ表現を直接保存しません。
末尾の余分なデータは拒否します。ファイル全体の上限は8192バイトです。

親鍵はowner階層から`TPM2_CreatePrimary`で生成します。
テンプレートはRSA-2048、SHA-256、AES-128-CFB、RSA schemeはNULL、指数は既定値、uniqueは空です。
属性はfixedTPM・fixedParent・sensitiveDataOrigin・userWithAuth・restricted・decrypt・noDAです。
親鍵の再生成には同じowner seedと同じテンプレートが必要です。

sealed objectはKEYEDHASH、SHA-256、schemeはNULL、属性はfixedTPM・fixedParent・userWithAuth・noDAです。
認証値とauthPolicyは空で、sensitive dataにKを格納します。
復元したデータは32バイトでなければ拒否します。

このバージョンはPCRやユーザー入力の認証値による制限を含みません。
