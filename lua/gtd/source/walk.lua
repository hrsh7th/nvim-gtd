local kit = require('gtd.kit')
local LSP = require('gtd.kit.LSP')
local Worker = require('gtd.kit.Lua.Worker')
local Async = require('gtd.kit.Async')

---@class gtd.source.walk.Option
---@field public root_markers string[]
---@field public ignore_patterns string[] # The Lua pattern strings.

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
---@param option gtd.source.walk.Option
---@return gtd.kit.LSP.TextDocumentDefinitionResponse
function Source:execute(definition_params, context, option)
  option = kit.merge(option or {}, {
    root_markers = { '.git', 'tsconfig.json', 'package.json' },
    ignore_patterns = { '/node_modules', '/.git' },
  })

  return Async.run(function()
    if not context.fname then
      return {}
    end

    -- search root dir.
    local root_dir
    for dir in vim.fs.parents(vim.uri_to_fname(definition_params.textDocument.uri)) do
      for _, marker in ipairs(option.root_markers) do
        if vim.fn.isdirectory(dir .. '/' .. marker) == 1 then
          root_dir = dir
          break
        end
      end
      if root_dir then
        break
      end
    end
    if not root_dir then
      return {}
    end

    -- Search file via IO.walk.
    local paths = Worker.new(function(root_dir, fname, ignore_patterns)
      local IO = require('gtd.kit.IO')
      local paths = {}
      return IO.walk(root_dir, function(_, entry)
        for _, pattern in ipairs(ignore_patterns) do
          if string.match(entry.path, pattern) then
            return IO.WalkStatus.SkipDir
          end
        end
        if entry.path:find(fname, 1, true) then
          table.insert(paths, entry.path)
        end
      end):next(function()
        return paths
      end)
    end)(root_dir, self:_normalize_fname(context), option.ignore_patterns):await()

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

---@param context gtd.Context
---@return string
function Source:_normalize_fname(context)
  local fname = context.fname or ''
  fname = fname:gsub('^[%./]*/', '')
  return fname
end

return Source
