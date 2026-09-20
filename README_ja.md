# cmp-bootstrap-vue

[English](README.md)

Bootstrap Vueコンポーネントに対応した
[nvim-cmp](https://github.com/hrsh7th/nvim-cmp)用の補完ソースです。
現在のプロジェクトにインストールされたVeturメタデータを読み込み、
Vueファイルでコンポーネントとpropを補完します。

## 機能

- Vue 2用の`bootstrap-vue`とVue 3用の`bootstrap-vue-next`に対応
- `<b-button>`や`<BButton>`などのコンポーネントタグを補完
- コンポーネントの属性とpropを補完
- **NEW:** `class=""`属性内でBootstrapのCSSクラスを補完（`fs-5`、`mb-1`、`text-muted`などのユーティリティクラスや、`btn`、`container`などのコンポーネントクラス）
- メタデータファイルからドキュメントを表示
- 複数のメタデータ形式に対応：VeturとWeb-types.json
- `bootstrap-vue-next`のメタデータが見つからない場合、自動的に`bootstrap-vue`のメタデータにフォールバック
- `vue` filetypeでのみ有効
- プロジェクトごとに結果を60秒間キャッシュ
- パッケージ名とメタデータのパスを設定可能

## 必要要件

- Neovim 0.7以降
- [nvim-cmp](https://github.com/hrsh7th/nvim-cmp)
- `bootstrap-vue`または`bootstrap-vue-next`を含むプロジェクト
- **クラス補完のため:** `node_modules/bootstrap/dist/css/bootstrap.css`にCSSファイルを含む`bootstrap`パッケージ

パッケージが`dependencies`または`devDependencies`に記載されている必要があります。

### メタデータ形式のサポート

プラグインは以下の順序でコンポーネントメタデータを検索します：

1. **Vetur形式**：`vetur-tags.json`と`vetur-attributes.json`
2. **web-types.json**：JetBrains IDE形式
3. **フォールバックパッケージ**：`bootstrap-vue-next`用に`bootstrap-vue`のメタデータを使用

**bootstrap-vue-nextユーザーへの重要な注意**：`bootstrap-vue-next`はVeturやweb-types.jsonのメタデータファイルを提供していないため、このプラグインは自動的に`bootstrap-vue`のメタデータにフォールバックします。`bootstrap-vue-next`プロジェクトで補完を有効にするには、`bootstrap-vue`を開発依存関係としてインストールしてください：

```bash
npm install -D bootstrap-vue
# または
yarn add -D bootstrap-vue
# または
pnpm add -D bootstrap-vue
```

これにより、プロジェクトで`bootstrap-vue-next`コンポーネントを使用しながら、プラグインは`bootstrap-vue`のメタデータを補完に使用できます。

**⚠️ フォールバックの制限事項**：
- **`bootstrap-vue`未インストールの場合**：`bootstrap-vue-next`プロジェクトで補完候補が0件になります
- **コンポーネントの精度**：フォールバックはVue 2（`bootstrap-vue`）のメタデータを使用するため、Vue 3（`bootstrap-vue-next`）には存在しないコンポーネントが含まれる可能性があります。例えば、Vue 2の古いアイコンコンポーネント（`b-icon-alarm`など）が補完候補に表示されても、`bootstrap-vue-next`では利用できない場合があります
- **ベストプラクティス**：このフォールバックは一時的な解決策としてのみ使用してください。bootstrap-vue-nextプロジェクトに公式なメタデータサポートをリクエストすることを検討してください

## インストール

プラグインをインストールした後、`nvim-cmp`のsourcesへ
`{ name = "bootstrap-vue" }`を追加してください。

### nvpm

nvpm設定にプラグインを追加します。

```json
{
  "plugins": [
    {
      "url": "ue555/cmp-bootstrap-vue"
    }
  ]
}
```

続けて`nvim-cmp`を設定します。

```lua
local cmp = require("cmp")

cmp.setup({
  sources = cmp.config.sources({
    { name = "nvim_lsp" },
    { name = "bootstrap-vue" },
  }),
})
```

### lazy.nvim

```lua
{
  "hrsh7th/nvim-cmp",
  dependencies = {
    "ue555/cmp-bootstrap-vue",
  },
  config = function()
    local cmp = require("cmp")

    cmp.setup({
      sources = cmp.config.sources({
        { name = "nvim_lsp" },
        { name = "bootstrap-vue" },
      }),
    })
  end,
}
```

### ローカル開発版

```lua
vim.opt.runtimepath:prepend("/home/ue555/dev/cmp-bootstrap-vue")

local cmp = require("cmp")
cmp.setup({
  sources = {
    { name = "bootstrap-vue" },
  },
})
```

## 使い方

開始タグまたは終了タグの入力中にコンポーネントを補完します。

```vue
<template>
  <b-
  </b-
</template>
```

コンポーネント名の後に空白を入力すると、属性を補完します。

```vue
<template>
  <b-button 
</template>
```

判定する補完コンテキストは次のとおりです。

| 入力 | 補完内容 |
|---|---|
| `<b-` | コンポーネントタグ |
| `<b-button` | コンポーネントタグ |
| `</b-` | 終了タグ |
| `<b-button ` | 属性とprop |
| `<div class="` | BootstrapのCSSクラス |
| `<b-button class="fs-` | BootstrapのCSSクラス |
| タグ外のテキスト | 補完なし |

## 設定

設定は省略できます。

```lua
require("cmp_bootstrap_vue").setup({
  vetur_tags_path = "dist/vetur-tags.json",
  vetur_attributes_path = "dist/vetur-attributes.json",
  supported_packages = {
    "bootstrap-vue",
    "bootstrap-vue-next",
  },
  fallback_packages = {
    ["bootstrap-vue-next"] = "bootstrap-vue",
  },
  notification_level = vim.log.levels.WARN,
})
```

| 設定 | 型 | デフォルト | 内容 |
|---|---|---|---|
| `vetur_tags_path` | string | `"dist/vetur-tags.json"` | 各パッケージからのタグメタデータ相対パス |
| `vetur_attributes_path` | string | `"dist/vetur-attributes.json"` | 各パッケージからの属性メタデータ相対パス |
| `supported_packages` | string[] | 上記参照 | `package.json`で確認するパッケージ |
| `fallback_packages` | table | `{ ["bootstrap-vue-next"] = "bootstrap-vue" }` | メタデータが見つからない場合のフォールバックパッケージ |
| `notification_level` | number | `vim.log.levels.WARN` | 通知する最低severity |

### メタデータ読み込み戦略

プラグインは各パッケージに対して以下のフォールバック戦略を使用します：

1. Vetur形式を試す（`vetur-tags.json`と`vetur-attributes.json`）
   - 設定されたパス
   - `dist/vetur-*.json`
   - `lib/vetur-*.json`
   - ルート`vetur-*.json`

2. web-types.json形式を試す
   - `dist/web-types.json`
   - ルート`web-types.json`

3. それでも見つからず、フォールバックパッケージが設定されている場合、フォールバックパッケージのメタデータを使用

## キャッシュAPI

空の結果を含む読み込み結果を、プロジェクトごとに60秒間キャッシュします。

```lua
local bootstrap_vue = require("cmp_bootstrap_vue")

-- 現在のプロジェクトのキャッシュを削除
bootstrap_vue.clear_cache()

-- 指定したプロジェクトのキャッシュを削除
bootstrap_vue.clear_cache("/path/to/project")

-- すべてのプロジェクトのキャッシュを削除
bootstrap_vue.clear_all_caches()
-- 次の呼び出しも同じ動作です
bootstrap_vue.clear_cache("all")

-- キャッシュを削除し、次回の補完時に再読み込み
bootstrap_vue.reload()
```

`reload()`は現在のプロジェクトのキャッシュを削除します。
メタデータは次の補完要求時に遅延読み込みされます。

## 仕組み

1. 現在のVueファイルから最も近い`package.json`を検索します。
2. `dependencies`と`devDependencies`から設定対象のパッケージを確認します。
3. インストールされた各パッケージからメタデータを読み込みます：
   - まずVetur形式を試す
   - Veturが見つからない場合、web-types.jsonにフォールバック
   - どちらも見つからない場合、設定されたフォールバックパッケージを使用
4. BootstrapのCSSファイル（`node_modules/bootstrap/dist/css/bootstrap.css`）を解析して全てのCSSクラス名を抽出します
5. カーソル位置がタグ名、属性、またはclass値の入力位置かを判定します。
6. 対応する補完候補を`nvim-cmp`へ返します。

複数の対応パッケージに同名コンポーネントがある場合は、
`supported_packages`で先に指定されたパッケージを補完に使用します。

## 制限事項

- 現在のファイルから最も近い`package.json`をプロジェクトとして扱います。
- パッケージは
  `<project-root>/node_modules/<package-name>`から参照できる必要があります。
- 親ディレクトリにhoistされたworkspace依存関係は検索しません。
- キャッシュ時間は60秒固定です。
- **bootstrap-vue-nextメタデータのフォールバック**：
  - `bootstrap-vue-next`はメタデータファイルを提供していないため、フォールバックとして`bootstrap-vue`をインストールする必要があります
  - フォールバックメタデータはVue 2版であり、Vue 3には存在しないコンポーネントが含まれる可能性があります
  - コンポーネントが実際に`node_modules`に存在するかの検証は行われません
  - フォールバックメタデータ使用時、存在しないコンポーネントが補完候補に含まれる可能性があります

依存関係が親ディレクトリへhoistされている場合は、使用しているパッケージ
マネージャーに対応したリンクをプロジェクトの`node_modules`へ作成するか、
そのプロジェクトへ依存関係をインストールしてください。

## トラブルシューティング

補完が表示されない場合は、次を確認してください。

1. `:set filetype?`の結果が`vue`であること
2. 最も近い`package.json`に対象パッケージが記載されていること
3. `node_modules`以下にパッケージとVetur JSONファイルが存在すること
4. `nvim-cmp`のsourceに`{ name = "bootstrap-vue" }`があること
5. `:messages`に警告またはエラーがないこと

検出されたパッケージは次のコマンドで確認できます。

```vim
:lua local u = require("cmp_bootstrap_vue.utils"); print(vim.inspect(u.detect_bootstrap_packages(u.find_project_root())))
```

詳細な通知を有効にする設定：

```lua
require("cmp_bootstrap_vue").setup({
  notification_level = vim.log.levels.DEBUG,
})
```

## 開発

テストには[plenary.nvim](https://github.com/nvim-lua/plenary.nvim)を使用します。

```bash
make test
```

同等のコマンド：

```bash
nvim --headless \
  -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"
```

## ライセンス

MIT
