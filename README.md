# cmp-bootstrap-vue

[日本語](README_ja.md)

An [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) source for Bootstrap Vue
components. It reads the Vetur metadata installed in the current project and
provides component and prop completion in Vue files.

## Features

- Supports `bootstrap-vue` for Vue 2 and `bootstrap-vue-next` for Vue 3
- Completes component tags such as `<b-button>` and `<BButton>`
- Completes component attributes and props
- Shows documentation from `vetur-tags.json` and `vetur-attributes.json`
- Activates only for the `vue` filetype
- Caches results separately for each project for 60 seconds
- Supports configurable package names and Vetur metadata paths

## Requirements

- Neovim 0.7 or later
- [nvim-cmp](https://github.com/hrsh7th/nvim-cmp)
- A project containing `bootstrap-vue` or `bootstrap-vue-next`

The package must be listed in `dependencies` or `devDependencies`, and its
Vetur metadata must be available below the project's `node_modules`
directory.

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
  notification_level = vim.log.levels.WARN,
})
```

| Option | Type | Default | Description |
|---|---|---|---|
| `vetur_tags_path` | string | `"dist/vetur-tags.json"` | Tag metadata path relative to each package |
| `vetur_attributes_path` | string | `"dist/vetur-attributes.json"` | Attribute metadata path relative to each package |
| `supported_packages` | string[] | See above | Packages checked in `package.json` |
| `notification_level` | number | `vim.log.levels.WARN` | Minimum notification severity |

If the configured metadata path is unavailable, the plugin also checks the
package's `dist/`, `lib/`, and root directories.

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
3. Reads Vetur metadata from each installed package.
4. Determines whether the cursor is in a tag-name or attribute context.
5. Returns the appropriate `nvim-cmp` completion items.

If multiple supported packages define the same component, the first package
in `supported_packages` is used for completion.

## Limitations

- Package discovery uses the nearest `package.json`.
- Packages must be accessible at
  `<project-root>/node_modules/<package-name>`.
- Hoisted workspace dependencies are not searched in parent directories.
- The cache duration is fixed at 60 seconds.
- Vetur JSON metadata is required; `web-types.json` is not supported.

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
