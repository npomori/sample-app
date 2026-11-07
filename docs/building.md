# 参加アプリの作り方

このリポジトリは、認証サーバーに連携する参加アプリの参考実装です。認証の骨格はパッケージ `astro-participant-auth` です。新しい参加アプリは、そのパッケージに依存し、識別子と業務画面を置きます。

手順は次です。

1. Astro のサーバー描画プロジェクトを作る。このリポジトリを業務画面の例にする
2. 認証サーバーへアプリを登録する
3. `astro-participant-auth` に依存する。公開するまでは、リポジトリを隣に置き `file:../astro-participant-auth` で依存する
4. `APP_ID` とオリジンを変える
5. integration、`src/fetch.ts`、`src/env.d.ts`、CSS の `@source` を接続する
6. 業務画面を置く
7. [verification.md](verification.md) と [testing.md](testing.md) で確認する

## 位置づけ

プロトコルの正本は、認証サーバーの [participant-app.md](https://github.com/czbone/astro-user-webauthn2/blob/main/planning/participant-app.md)、[multi-app-auth.md](https://github.com/czbone/astro-user-webauthn2/blob/main/planning/multi-app-auth.md)、[app-permissions](https://github.com/czbone/astro-user-webauthn2/blob/main/planning/app-permissions/README.md)、[ロールと認可](https://github.com/czbone/astro-user-webauthn2/blob/main/planning/auth-app-role-authorization-spec.md) です。

このアプリの画面と確認方法は `docs/` に記載しています。作るものの仕様が食い違う場合は `docs/` に従います。権限の決め方が食い違う場合は [grant.md](../planning/app-permissions/grant.md) に従います。

判定の分岐は [access.md](access.md)、接続の制限は [connections.md](connections.md) です。この手引きは、その表と手順を写しません。骨格の分け方は [library.md](library.md) です。

## 境界

参加アプリが担う機能は次のとおりです。

- 未ログイン時に `{AUTH_ORIGIN}/auth/handoff` へ送る引き渡し
- `/callback` でコードを消費し、ホスト専用の `__Host-session` を発行する処理
- 実効許可が `allow` の場合に限った入場
- `POST /logout`
- 共有テーブルの参照

これらは `astro-participant-auth` が実装します。参加アプリが担わない機能は次のとおりです。

- ログイン、パスキー儀式、メール、ユーザー作成
- `App` と `AppGrant` の作成と変更
- 公開パス。未ログインの画面は本文を出さない
- 認証サーバーの HTTP 呼び出し

## 認証サーバーへの登録と環境

アプリを起動する前に、認証サーバーの管理画面で登録します。

| 項目 | 値 |
| --- | --- |
| アプリ ID | `APP_ID` と同一 |
| オリジン | `APP_ORIGIN`。パスは含めない |
| 戻り先 URL | `APP_ORIGIN/callback` |
| 既定の利用許可 | `allow`、または行が無い利用者を入れない設定 |

アプリごとに変える値は、[.env.example](../.env.example) の `APP_ID` と `APP_ORIGIN` です。`AUTH_ORIGIN` は認証サーバーのオリジンのままにします。これら2つのオリジンには、それぞれ異なる値を設定します。ホスト専用 Cookie はポート番号では分離されないため、`localhost` の別ポートではなく、別のホスト名を使います。

`APP_ID` は `^[a-z0-9-]{1,32}$` です。検証は `astro-participant-auth` が行います。

PostgreSQL と Redis の接続文字列、許す操作、`REDIS_KEY_PREFIX` と `SESSION_MAX_AGE_SECONDS` は [connections.md](connections.md) です。起動コマンドはリポジトリの [README](../README.md) です。共有テーブルのロール作成とマイグレーションは、このアプリでは実行しません。共有テーブルの Prisma Client はライブラリが生成します。

## 接続

リクエストの順は `createParticipantFetch` が固定します。参加アプリの [src/fetch.ts](../src/fetch.ts) は、仮想モジュールと業務の更新を渡すだけです。`POST /logout` はライブラリが登録します。アプリ側では繰り返しません。

```ts
import { App } from 'astro/app'
import { actions, middleware, pages } from 'astro/hono'
import { createParticipantFetch } from 'astro-participant-auth'

export default createParticipantFetch({
  App,
  middleware,
  actions,
  pages,
  mutations: [],
  routes() {}
})
```

[astro.config.mjs](../astro.config.mjs) で integration を足します。この参考実装の表示名は「参加アプリ」です。

```ts
integrations: [participantAuth({ displayName: '参加アプリ' })]
```

[src/env.d.ts](../src/env.d.ts) で `App.Locals.access` を `PageAccess` に接続します。

```ts
declare namespace App {
  interface Locals {
    access: import('astro-participant-auth').PageAccess
  }
}
```

参加アプリの CSS は、ライブラリの `.astro` を `@source` の対象に含めます。この参考実装は [src/styles/global.css](../src/styles/global.css) から、隣の `astro-participant-auth/src` を指します。

分岐の一覧は [access.md](access.md) です。入場、引き渡し、ログアウト、`/callback`、`/logged-out`、`/grants`、`/roles`、共有テーブルの参照はライブラリにあります。

## 業務画面

[src/pages/index.astro](../src/pages/index.astro) の本文を、そのアプリのものに変えます。ヘッダの表示名は integration の `displayName` です。画面へ直書きしません。`/grants` と `/roles` はライブラリが注入します。分け方は [access.md](access.md) です。

業務画面は `src/pages` に追加し、Astro のサーバー側で HTML を描画します。レイアウトは `astro-participant-auth/layout` です。ページでは `Astro.locals.access` だけを参照し、セッションの再解決処理は書きません。`kind` が `public` の場合は権限が解決されていないため、エラーにします。

```astro
---
import Layout from 'astro-participant-auth/layout'

const access = Astro.locals.access
if (access.kind === 'public') throw new Error('画面の権限が解決されていません')
---
```

入場後の画面分けは、サーバーが読んだ `User.role` と、後から足すアプリ内ロールで行います。クライアントが送ったロール名では分けません。`kind` が `ok` のときだけ業務を出します。入場できたあとの 403 でも、セッションの TTL は延ばします。

新しい画面は公開パスにしません。`/callback` と `/logged-out` 以外の GET と HEAD は、未ログインなら引き渡しを始めます。

## 更新を足すとき

アプリ内ロールを定義したアプリは、業務のメソッドとパスを `mutations` に追加し、同じパスを `routes` で登録します。`/api` と `src/pages/api` は使いません。許可リストに無いパスは、`routes` で登録しても入場ミドルウェアが止め、404「見つかりません」を返します。

`Origin` が `APP_ORIGIN` と完全に一致する場合だけ受け付けます。未認証の更新には 401「ログインが必要です」を返します。引き渡しは開始しません。

アプリ内ロールの定義がない間、受け付ける更新は `POST /logout` だけです。

アプリ内ロールは、`public` 以外のスキーマに `User.id` をキーにして置きます。そのスキーマだけ、このアプリがマイグレーションします。`AppGrant` には書きません。共有テーブルのクライアントへ、アプリのモデルは足しません。

## 変えないこと

- Cookie 名は `__Host-session` と `__Host-handoff` です。どちらも `Domain` を付けません
- セッション Cookie の値は、引き渡し JSON の `token` だけです。新しいセッショントークンは作りません
- 引き渡しコードの消費は `GETDEL` です
- `state` と `redirectUri` は定数時間で比較します
- Redis の操作は `GET`、`GETDEL`、`EXPIRE`、`DEL`、`SREM`、`SMEMBERS` だけです
- `User.role` は入場に使いません。入場後の画面分けに読みます
- セッションストアの差し替え、Cookie 名の変更、公開パスの追加は、ライブラリのオプションにしません

## 確認

登録したあとの手動確認は [verification.md](verification.md) です。骨格の自動テストは `astro-participant-auth` で実行します。分け方は [testing.md](testing.md) です。

`APP_ID` やオリジンを変えたアプリの統合テストは、ライブラリが上書きする `APP_ID=app` などの値を、そのアプリの値に合わせます。定数はライブラリの `src/test/integration-env.ts` です。
