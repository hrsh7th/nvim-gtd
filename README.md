# nvim-gtd

LSP's Go To Definition plugin for neovim.

This plugin is highly experimental.
The breaking changes will be applied without notice.

# Concept

- Run `textDocument/definition` and `gf` in one mapping.
- Open the path as much as possible

# Usage

```
---@class gtd.kit.App.Config.Schema
---@field public sources { name: string }[]
---@field public get_buffer_path fun(): string
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

