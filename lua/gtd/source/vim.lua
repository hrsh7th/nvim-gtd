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
    local dname = vim.fs.dirname(vim.uri_to_fname(definition_params.textDocument.uri))
    local texts = vim.api.nvim_buf_get_lines(
      context.bufnr,
      definition_params.position.line,
      definition_params.position.line + 1,
      false
    )
    local fpath = RegExp.extract_at(texts[1] or '', [[\k\+]], definition_params.position.character + 1)
    if fpath == '' then
      return {}
    end
    fpath = vim.fn.expand(fpath)
    vim.pretty_print({ fpath = fpath })
    if fpath:sub(1, 1) == '/' and vim.fn.filereadable(fpath) == 1 and not vim.fn.isdirectory(fpath) == 0 then
      return {
        uri = vim.uri_from_fname(vim.fn.fnemdmodify(fpath, ':p'))
      }
    end
    local found = vim.fn.findfile(fpath, dname .. ';')
    if found == '' then
      return {}
    end
    return {
      uri = vim.uri_from_fname(vim.fn.expand(dname .. '/' .. found)),
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
