local LSP = require('gtd.kit.LSP')
local Async = require('gtd.kit.Async')

local Source = {}
Source.__index = Source

---Create new source.
function Source.new()
  return setmetatable({}, Source)
end

---Return LSP.PositionEncodingKind.
---@return gtd.kit.LSP.PositionEncodingKind
function Source:get_position_encoding_kind()
  return LSP.PositionEncodingKind.UTF8
end

---@param definition_params gtd.kit.LSP.DefinitionParams
---@param context gtd.Context
---@return gtd.kit.LSP.TextDocumentDefinitionResponse
function Source:execute(definition_params, context)
  return Async.run(function()
    if not context.fname then
      return {}
    end

    -- Search file via `findfile`.
    local dpath = vim.fs.dirname(vim.uri_to_fname(definition_params.textDocument.uri))
    local found = vim.fn.findfile(context.fname:gsub('^[%./]+', ''), dpath .. ';')
    if found == '' then
      return {}
    end

    return {
      uri = vim.uri_from_fname(vim.fn.fnamemodify(found, ':p')),
      range = {
        start = {
          line = context.row,
          character = context.col,
        },
        ['end'] = {
          line = context.row,
          character = context.col,
        },
      }
    }
  end)
end

return Source
