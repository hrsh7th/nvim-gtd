# nvim-gtd

LSP's Go To Definition plugin for neovim.

This plugin is highly experimental.
The breakin changes will be applied without notice.

# Usage

```
require('gtd').setup {
  sources = {
    { name = 'lsp' },
    { name = 'vim' },
  }
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
