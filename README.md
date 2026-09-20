# cmp-bootstrap-vue

[日本語](README_ja.md)

An [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) source for Bootstrap Vue
components. It reads the Vetur metadata installed in the current project and
provides component and prop completion in Vue files.

## Features

- Supports `bootstrap-vue` for Vue 2 and `bootstrap-vue-next` for Vue 3
- Completes component tags such as `<b-button>` and `<BButton>`
- Completes component attributes and props
- **NEW:** Completes Bootstrap CSS classes inside `class=""` attributes (e.g., utility classes like `fs-5`, `mb-1`, `text-muted`, and component classes like `btn`, `container`)
- Shows documentation from metadata files
- Multiple metadata format support: Vetur and web-types.json
- Automatic fallback to `bootstrap-vue` metadata when `bootstrap-vue-next` metadata is unavailable
- Activates only for the `vue` filetype
- Caches results separately for each project for 60 seconds
- Supports configurable package names and metadata paths

## Requirements

- Neovim 0.7 or later
- [nvim-cmp](https://github.com/hrsh7th/nvim-cmp)
- A project containing `bootstrap-vue` or `bootstrap-vue-next`
- **For class completion:** `bootstrap` package with CSS files in `node_modules/bootstrap/dist/css/bootstrap.css`

The package must be listed in `dependencies` or `devDependencies`.

### Metadata Format Support

The plugin searches for component metadata in the following order:

1. **Vetur format**: `vetur-tags.json` and `vetur-attributes.json`
2. **web-types.json**: JetBrains IDE format
3. **Fallback package**: Uses `bootstrap-vue` metadata for `bootstrap-vue-next`

**Important for bootstrap-vue-next users**: Since `bootstrap-vue-next` does not provide Vetur or web-types.json metadata files, this plugin automatically falls back to using `bootstrap-vue` metadata. To enable completion for `bootstrap-vue-next` projects, install `bootstrap-vue` as a dev dependency:

```bash
npm install -D bootstrap-vue
# or
yarn add -D bootstrap-vue
# or
pnpm add -D bootstrap-vue
```

This allows the plugin to use `bootstrap-vue`'s metadata for completion while you use `bootstrap-vue-next` components in your project.

**⚠️ Fallback Limitations**:
- **Without `bootstrap-vue` installed**: Completion will return 0 items for `bootstrap-vue-next` projects
- **Component accuracy**: The fallback uses Vue 2 (`bootstrap-vue`) metadata, which may include components that don't exist in Vue 3 (`bootstrap-vue-next`). For example, legacy icon components like `b-icon-alarm` from Vue 2 might appear in completions even though they may not be available in `bootstrap-vue-next`
- **Best practice**: Only use this fallback as a temporary solution. Consider requesting official metadata support from the bootstrap-vue-next project

## Installation

After installing the plugin, add `{ name = "bootstrap-vue" }` to your
`nvim-cmp` sources.

### nvpm

Add the plugin to your nvpm configuration:

```json
{
  "plugins": [
    {
      "url": "ue555/cmp-bootstrap-vue"
    }
  ]
}
```

Then configure `nvim-cmp`:

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

### Local development

```lua
vim.opt.runtimepath:prepend("/home/ue555/dev/cmp-bootstrap-vue")

local cmp = require("cmp")
cmp.setup({
  sources = {
    { name = "bootstrap-vue" },
  },
})
```

## Usage

Component completion is available while entering an opening or closing tag:

```vue
<template>
  <b-
  </b-
</template>
```

Attribute completion is available after the component name and a space:

```vue
<template>
  <b-button 
</template>
```

The source recognizes these contexts:

| Input | Completion |
|---|---|
| `<b-` | Component tags |
| `<b-button` | Component tags |
| `</b-` | Closing component tags |
| `<b-button ` | Attributes and props |
| `<div class="` | Bootstrap CSS classes |
| `<b-button class="fs-` | Bootstrap CSS classes |
| Text outside a tag | No results |

## Configuration

Configuration is optional:

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

| Option | Type | Default | Description |
|---|---|---|---|
| `vetur_tags_path` | string | `"dist/vetur-tags.json"` | Tag metadata path relative to each package |
| `vetur_attributes_path` | string | `"dist/vetur-attributes.json"` | Attribute metadata path relative to each package |
| `supported_packages` | string[] | See above | Packages checked in `package.json` |
| `fallback_packages` | table | `{ ["bootstrap-vue-next"] = "bootstrap-vue" }` | Fallback packages when metadata is not found |
| `notification_level` | number | `vim.log.levels.WARN` | Minimum notification severity |

### Metadata Loading Strategy

The plugin uses the following fallback strategy for each package:

1. Try Vetur format (`vetur-tags.json` and `vetur-attributes.json`)
   - Configured path
   - `dist/vetur-*.json`
   - `lib/vetur-*.json`
   - Root `vetur-*.json`

2. Try web-types.json format
   - `dist/web-types.json`
   - Root `web-types.json`

3. If still not found and a fallback package is configured, use the fallback package's metadata

## Cache API

Results, including empty results, are cached per project for 60 seconds.

```lua
local bootstrap_vue = require("cmp_bootstrap_vue")

-- Clear the current project's cache.
bootstrap_vue.clear_cache()

-- Clear one project's cache.
bootstrap_vue.clear_cache("/path/to/project")

-- Clear every project's cache.
bootstrap_vue.clear_all_caches()
-- Equivalent to:
bootstrap_vue.clear_cache("all")

-- Clear and reload on the next completion request.
bootstrap_vue.reload()
```

`reload()` clears the current project's cache. Metadata is loaded lazily on
the next completion request.

## How it works

1. Finds the nearest `package.json` above the current Vue file.
2. Checks configured packages in `dependencies` and `devDependencies`.
3. Reads metadata from each installed package:
   - Tries Vetur format first
   - Falls back to web-types.json if Vetur not found
   - Falls back to configured fallback package if neither format is found
4. Parses Bootstrap CSS file (`node_modules/bootstrap/dist/css/bootstrap.css`) to extract all CSS class names
5. Determines whether the cursor is in a tag-name, attribute, or class-value context.
6. Returns the appropriate `nvim-cmp` completion items.

If multiple supported packages define the same component, the first package
in `supported_packages` is used for completion.

## Limitations

- Package discovery uses the nearest `package.json`.
- Packages must be accessible at
  `<project-root>/node_modules/<package-name>`.
- Hoisted workspace dependencies are not searched in parent directories.
- The cache duration is fixed at 60 seconds.
- **bootstrap-vue-next metadata fallback**:
  - `bootstrap-vue-next` does not provide metadata files, so `bootstrap-vue` must be installed as a fallback
  - Fallback metadata is from Vue 2 and may include components not available in Vue 3
  - No validation is performed to check if components actually exist in `node_modules`
  - Completion suggestions may include non-existent components when using fallback metadata

For a hoisted dependency, create a package-manager-supported link in the
project's `node_modules` directory or install the dependency in that project.

## Troubleshooting

If completion is unavailable:

1. Confirm the buffer filetype with `:set filetype?`; it must be `vue`.
2. Confirm the package is declared in the nearest `package.json`.
3. Confirm the package and its Vetur JSON files exist under `node_modules`.
4. Confirm `{ name = "bootstrap-vue" }` is configured as an `nvim-cmp` source.
5. Run `:messages` to inspect warnings and errors.

Package detection can be inspected with:

```vim
:lua local u = require("cmp_bootstrap_vue.utils"); print(vim.inspect(u.detect_bootstrap_packages(u.find_project_root())))
```

Enable detailed notifications with:

```lua
require("cmp_bootstrap_vue").setup({
  notification_level = vim.log.levels.DEBUG,
})
```

## Development

Tests use [plenary.nvim](https://github.com/nvim-lua/plenary.nvim):

```bash
make test
```

The equivalent command is:

```bash
nvim --headless \
  -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"
```

## License

MIT
