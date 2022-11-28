local Async = require('gtd.kit.Async')
local RegExp = require('gtd.kit.Vim.RegExp')

local Source = {}
Source.__index = Source

function Source.new()
  return setmetatable({}, Source)
end

---@param params gtd.kit.LSP.DefinitionParams
---@return gtd.kit.LSP.TextDocumentDefinitionResponse
function Source:execute(params)
  return Async.run(function()
    local bufnr = vim.uri_to_bufnr(params.textDocument.uri)
    local dname = vim.fs.dirname(vim.uri_to_fname(params.textDocument.uri))
    local fpath = RegExp.extract_at(
      vim.api.nvim_buf_get_lines(
        bufnr,
        params.position.line,
        params.position.line + 1,
        false
      )[1],
      [[\f\+]],
      params.position.character + 1
    ):gsub('^%./', '')
    local found = vim.fn.findfile(fpath, dname .. ';')
    if found == '' then
      return {}
    end
    return {
      uri = vim.uri_from_fname(found),
    }
  end)
end

return Source
