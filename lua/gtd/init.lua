local kit = require('gtd.kit')
local Config = require('gtd.kit.App.Config')
local LSP = require('gtd.kit.LSP')
local Async = require('gtd.kit.Async')

---@class gtd.kit.App.Config.Schema
---@field public sources { name: string }[]
---@field public on_nothing fun(context: gtd.Context, )
---@field public on_location fun(context: gtd.Context, location: gtd.kit.LSP.LocationLink)
---@field public on_locations fun(context: gtd.Context, locations: gtd.kit.LSP.LocationLink[])

---@class gtd.Source
---@field public name string
---@field public get_position_encoding_kind? fun(): gtd.kit.LSP.PositionEncodingKind
---@field public execute fun(self: gtd.Source, params: gtd.kit.LSP.DefinitionParams): gtd.kit.Async.AsyncTask

---@class gtd.Context
---@field public command string

local gtd = {}

gtd.config = Config.new({
  on_nothing = function(_)
    print('Nothing found')
  end,
  on_location = function(context, location)
    gtd._open(context, location)
  end,
  on_locations = function(context, locations)
    vim.ui.select(locations, {
      prompt = 'Select file',
      format_item = function(location)
        return vim.uri_to_fname(location.targetUri)
      end,
    }, function(location)
      gtd._open(context, location)
    end)
  end
})

gtd.setup = gtd.config:create_setup_interface()

---@type table<string, gtd.Source>
gtd.registry = {}

---@param name string
---@param source gtd.Source
function gtd.register_source(name, source)
  source.get_position_encoding_kind = source.get_position_encoding_kind or function()
    return LSP.PositionEncodingKind.UTF16
  end
  gtd.registry[name] = source
end

---@param context { command: string }
---@param config? gtd.kit.App.Config.Schema
function gtd.exec(context, config)
  config = kit.merge(config or {}, gtd.config:get())

  ---@type gtd.kit.LSP.DefinitionParams
  local params = vim.lsp.util.make_position_params()
  Async.run(function()
    for _, source_config in ipairs(config.sources) do
      local source = gtd.registry[source_config.name]
      if source then
        local locations = gtd._normalize(source:execute(params):await())
        if #locations > 0 then
          return locations
        end
      end
    end
    return {}
  end):next(function(locations --[[ @as gtd.kit.LSP.LocationLink[] ]])
    if #locations == 0 then
      gtd.config:get().on_nothing(context)
    elseif #locations == 1 then
      gtd.config:get().on_location(context, locations[1])
    else
      gtd.config:get().on_locations(context, locations)
    end
  end)
end

---Normalize textDocument/definition response.
---@param locations gtd.kit.LSP.Location | gtd.kit.LSP.LocationLink | (gtd.kit.LSP.Location | gtd.kit.LSP.LocationLink)[] | nil
---@return (gtd.kit.LSP.Location | gtd.kit.LSP.LocationLink)[]
function gtd._normalize(locations)
  if not locations then
    return {}
  end
  if locations.uri then
    locations = { locations }
  end
  if locations.targetUri then
    locations = { locations }
  end
  local new_locations = {}
  for _, location in ipairs(locations) do
    if location.uri then
      table.insert(new_locations, {
        targetUri = location.uri,
        targetRange = location.range,
        targetSelectionRange = location.targetSelectionRange,
      })
    else
      table.insert(new_locations, location)
    end
  end
  return new_locations
end

---Open LocationLink.
---@param context gtd.Context
---@param location gtd.kit.LSP.LocationLink
function gtd._open(context, location)
  vim.cmd[context.command] { args = { vim.uri_to_fname(location.targetUri) } }
  if location.targetSelectionRange then
    vim.api.nvim_win_set_cursor(0, { location.targetSelectionRange.start.line + 1, location.targetSelectionRange.start.character })
  end
end

gtd.register_source('vim', require('gtd.source.vim').new())
gtd.register_source('lsp', require('gtd.source.lsp').new())

return gtd
