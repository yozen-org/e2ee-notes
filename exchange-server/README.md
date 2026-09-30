# Exchange Server

暗号化されたオブジェクトを端末間で継続同期するための、ゼロ知識の永続 BlobStore
サーバー。仕様は [`spec/EXCHANGE_SERVER_V1.md`](../spec/EXCHANGE_SERVER_V1.md)。

[Hono](https://hono.dev) による参照実装です。同じコードが Cloudflare Workers と
Node.js（VPS など）の両方で動きます。サーバーはキーと値を不透明なバイト列として
扱い、内容を復号できません。

## 実行形態

ストレージだけを差し替えて、同じルーティング・ロジックを再利用します。

| 形態 | ストレージ | 起動方法 |
|---|---|---|
| Cloudflare Workers | KV | `wrangler deploy` |
| セルフホスト（Node.js） | インメモリ | `npm start` |

## API

- `PUT /v1/objects/{key}` — オブジェクト保存（不変・追記）
- `GET /v1/objects/{key}` — 取得
- `GET /v1/objects?prefix={prefix}` — キー一覧
- `DELETE /v1/objects/{key}` — 削除

## Cloudflare Workers にデプロイ

```sh
npm install
wrangler kv namespace create OBJECTS
# wrangler.jsonc の id を上記の出力に差し替える
wrangler deploy
```

## セルフホスト（Node.js / VPS）

```sh
npm install
npm start
# 既定で http://localhost:8787
```

Docker や任意の VPS 上で単一プロセスとして動かせます。

## 環境変数

- `MAX_PAYLOAD_BYTES`: 値の最大サイズ（既定 1 MiB）
- `PORT`: セルフホスト時のポート（既定 8787）

## セルフホスト

仕様は言語非依存です。このエンドポイントを満たす任意の実装（Go など）と相互運用できます。
クライアント側で「交換サーバー URL」を設定できます。
