# Cloudflare

`e2ee-notes` の交換サーバー（永続 BlobStore）の Cloudflare リソース
（Worker、KV namespace、カスタムドメイン）を OpenTofu で管理する。

単一 Worker が `PUT/GET/LIST/DELETE /v1/objects/{key}` を配信し、
`e2eenotes.yozen.org` で公開する。state は R2 bucket `yozen-tfstate` の
`e2ee-notes-exchange/terraform.tfstate` に保存する。

## Credential

credential は `exchange-server/.env`（Git 管理対象外）に置く。
`.env.example` をコピーして値を設定する。`with-env` が `.env` を読み込み、
Terraform 用の `TF_VAR_*` と R2 の `AWS_ENDPOINT_URL_S3` を組み立てて
子プロセスに渡す。

```sh
cp ../.env.example .env
chmod 600 ../.env
```

`.env` の項目:

- `CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ACCOUNT_ID` / `CLOUDFLARE_ZONE_ID`
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`（R2 tfstate 用）

```sh
./with-env tofu init -reconfigure
./with-env tofu plan
```

## DNS

Worker のカスタムドメイン `e2eenotes.yozen.org` は
`cloudflare_workers_custom_domain` で管理し、DNS record は Cloudflare が
自動で作成する。`yozen.org` の zone 自体は中央の `yozen` リポジトリで
管理しているため、DNS の切り離しで競合する場合は相談する。

## デプロイ手順（初回）

カスタムドメインは「Worker にデプロイメントが 1 つ以上ある」ことが前提なので、
**先に Worker と KV だけを apply → wrangler deploy → カスタムドメインを apply** の
順で進める。

1. Worker と KV namespace を作成する。

   ```sh
   ./with-env tofu apply -target=cloudflare_worker.exchange \
     -target=cloudflare_workers_kv_namespace.objects
   ```

2. KV namespace ID を確認し、`wrangler.jsonc` の `kv_namespaces[0].id` に設定する。

   ```sh
   ./with-env tofu output -raw kv_namespace_id
   ```

3. コードをデプロイする（最初のデプロイメントを作る）。

   ```sh
   cd ../.. # exchange-server ルート
   infra/cloudflare/with-env npm run deploy
   ```

4. カスタムドメインを apply する。

   ```sh
   cd infra/cloudflare
   ./with-env tofu apply
   ```

5. 疎通確認する。

   ```sh
   curl -X PUT --data-binary 'x' https://e2eenotes.yozen.org/v1/objects/probe/key
   curl https://e2eenotes.yozen.org/v1/objects/probe/key
   curl 'https://e2eenotes.yozen.org/v1/objects?prefix=probe/'
   ```

## 注意: KV の結果整合性

Cloudflare KV は結果整合（書き込みの反映に最大 ~60 秒、読み取りはエッジでキャッシュ
される）。`LIST` 直後に最新の書き込みが見えない、`DELETE` 直後に読み取りが残る場合が
ある。個人用途の継続同期（追記型・定期同期）では実用上問題ないが、強い一貫性が
必要な場合は R2 への切り替えを検討する。
