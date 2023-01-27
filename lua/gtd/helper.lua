local helper = {}

---@param context gtd.Context
function helper.fix_diff(context)
  if context.fname then
    if vim.tbl_contains({ 'diff', 'git', 'gitcommit' }, vim.bo[context.bufnr].filetype) then
      if context.fname:match('^a/') then
        context.fname = context.fname:gsub('^a/', '')
      elseif context.fname:match('^b/') then
        context.fname = context.fname:gsub('^b/', '')
      end
    end
  end
end

return helper
