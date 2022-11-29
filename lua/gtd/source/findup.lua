local Async = require('gtd.kit.Async')
local RegExp = require('gtd.kit.Vim.RegExp')

local Source = {}
Source.__index = Source

function Source.new()
  return setmetatable({}, Source)
end

---@param definition_params gtd.kit.LSP.DefinitionParams
---@param context gtd.Context
---@return gtd.kit.LSP.TextDocumentDefinitionResponse
function Source:execute(definition_params, context)
  return Async.run(function()
    local dpath = vim.fs.dirname(vim.uri_to_fname(definition_params.textDocument.uri))
    local texts = vim.api.nvim_buf_get_lines(
      context.bufnr,
      definition_params.position.line,
      definition_params.position.line + 1,
      false
    )
    local fpath = RegExp.extract_at(texts[1] or '', [[\f\+]], definition_params.position.character + 1)
    if fpath == '' then
      return {}
    end
    local found = vim.fn.findfile(fpath:gsub('^%./', ''), dpath .. ';')
    if found == '' then
      return {}
    end
    return {
      uri = vim.uri_from_fname(vim.fn.fnamemodify(found, ':p')),
      range = {
        start = {
          line = 0,
          character = 0
        },
        ['end'] = {
          line = 0,
          character = 0
        }
      }
    }
  end)
end

return Source
