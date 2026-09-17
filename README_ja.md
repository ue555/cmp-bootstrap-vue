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
- `vetur-tags.json`と`vetur-attributes.json`のドキュメントを表示
- `vue` filetypeでのみ有効
- プロジェクトごとに結果を60秒間キャッシュ
- パッケージ名とVeturメタデータのパスを設定可能

## 必要要件

- Neovim 0.7以降
- [nvim-cmp](https://github.com/hrsh7th/nvim-cmp)
- `bootstrap-vue`または`bootstrap-vue-next`を含むプロジェクト

パッケージが`dependencies`または`devDependencies`に記載され、
プロジェクトの`node_modules`以下からVeturメタデータを読み込める必要があります。

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
  notification_level = vim.log.levels.WARN,
})
```

| 設定 | 型 | デフォルト | 内容 |
|---|---|---|---|
| `vetur_tags_path` | string | `"dist/vetur-tags.json"` | 各パッケージからのタグメタデータ相対パス |
| `vetur_attributes_path` | string | `"dist/vetur-attributes.json"` | 各パッケージからの属性メタデータ相対パス |
| `supported_packages` | string[] | 上記参照 | `package.json`で確認するパッケージ |
| `notification_level` | number | `vim.log.levels.WARN` | 通知する最低severity |

設定したメタデータのパスが存在しない場合は、パッケージ内の`dist/`、
`lib/`、ルートディレクトリも確認します。

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
3. インストールされた各パッケージからVeturメタデータを読み込みます。
4. カーソル位置がタグ名または属性の入力位置かを判定します。
5. 対応する補完候補を`nvim-cmp`へ返します。

複数の対応パッケージに同名コンポーネントがある場合は、
`supported_packages`で先に指定されたパッケージを補完に使用します。

## 制限事項

- 現在のファイルから最も近い`package.json`をプロジェクトとして扱います。
- パッケージは
  `<project-root>/node_modules/<package-name>`から参照できる必要があります。
- 親ディレクトリにhoistされたworkspace依存関係は検索しません。
- キャッシュ時間は60秒固定です。
- Vetur JSONメタデータが必要です。`web-types.json`には対応していません。

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
