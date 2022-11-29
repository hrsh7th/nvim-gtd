local LSP = require('gtd.kit.LSP')
local Worker = require('gtd.kit.Lua.Worker')
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
    if context.fname == '' then
      return {}
    end

    -- search root dir.
    local root_dir
    for dir in vim.fs.parents(vim.uri_to_fname(definition_params.textDocument.uri)) do
      if vim.fn.isdirectory(dir .. "/.git") == 1 then
        root_dir = dir
        break
      end
    end
    if not root_dir then
      return {}
    end

    -- Search file via IO.walk.
    local paths = Worker.new(function(root_dir, fname)
      local paths = {}
      return require('gtd.kit.IO').walk(root_dir, function(_, entry)
        if entry.path:match(vim.pesc(fname)) then
          table.insert(paths, entry.path)
        end
      end):next(function()
        return paths
      end)
    end)(root_dir, context.fname):await()

    Async.schedule():await()

    return vim.tbl_map(function(path)
      return {
        uri = vim.uri_from_fname(path),
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
    end, paths)
  end)
end

return Source
