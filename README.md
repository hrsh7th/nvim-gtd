# nvim-gtd

LSP's Go To Definition plugin for neovim.

This plugin is highly experimental.
The breaking changes will be applied without notice.

# Concept

- Run `textDocument/definition` and `gf` in one mapping.
- Open the path as much as possible

# Usage

```lua
---@class gtd.kit.App.Config.Schema
---@field public sources { name: string, option?: table }[] # Specify the source that will be used to search for the definition
---@field public get_buffer_path fun(): string # Specify the function to get the current buffer path. It's useful for searching path from terminal buffer etc.
---@field public on_context fun(context: gtd.Context) # Modify context on user-land.
---@field public on_cancel fun(params: gtd.Params)
---@field public on_nothing fun(params: gtd.Params)
---@field public on_location fun(params: gtd.Params, location: gtd.kit.LSP.LocationLink)
---@field public on_locations fun(params: gtd.Params, locations: gtd.kit.LSP.LocationLink[])

-- The `findup` and `lsp` source are enabled by default (at the moment).
require('gtd').setup {
  ... gtd.kit.App.Config.Schema ...
}

vim.keymap.set('n', 'gf<CR>', function()
  require('gtd').exec({ command = 'edit' })
end)
vim.keymap.set('n', 'gfs', function()
  require('gtd').exec({ command = 'split' })
end)
vim.keymap.set('n', 'gfv', function()
  require('gtd').exec({ command = 'vsplit' })
end)
```

# Sources

The following sources are built-in.

#### lsp

(Default: enabled)

Find definitions via LSP `textDocument/definition`.

#### findfile

(Default: enabled)

Find definitions via `vim.fn.findfile` with `;` flag.

#### walk

(Default: disabled)

Traverse all filepaths under project.
The ignore pattern isn't implemented yet so it might be slow.

|*option-name*|*type*|*description*|
|root_markers|string[]|Specify root markers like `{ '.git', 'tsconfig.json' }`.|
|ignore_patterns|string[]|Specify ignore patterns like `{ '/node_modules', '/.git' }`|

