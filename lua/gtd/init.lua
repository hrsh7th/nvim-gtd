local kit = require('gtd.kit')
local Config = require('gtd.kit.App.Config')
local LSP = require('gtd.kit.LSP')
local Async = require('gtd.kit.Async')
local Position = require('gtd.kit.LSP.Position')

---@class gtd.kit.App.Config.Schema
---@field public sources { name: string }[]
---@field public get_buffer_path fun(): string
---@field public on_nothing fun(params: gtd.Params, )
---@field public on_location fun(params: gtd.Params, location: gtd.kit.LSP.LocationLink)
---@field public on_locations fun(params: gtd.Params, locations: gtd.kit.LSP.LocationLink[])

---@class gtd.Source
---@field public name string
---@field public get_position_encoding_kind? fun(): gtd.kit.LSP.PositionEncodingKind
---@field public execute fun(self: gtd.Source, params: gtd.kit.LSP.DefinitionParams, context: gtd.Context): gtd.kit.Async.AsyncTask

---@class gtd.Params
---@field public command string

---@class gtd.Context
---@field public bufnr integer

local gtd = {}

gtd.config = Config.new({
  get_buffer_path = function()
    return vim.api.nvim_buf_get_name(0)
  end,
  on_nothing = function(_)
    print('Nothing found')
  end,
  on_location = function(params, location)
    gtd._open(params, location)
  end,
  on_locations = function(params, locations)
    vim.ui.select(locations, {
      prompt = 'Select file',
      format_item = function(location)
        return vim.uri_to_fname(location.targetUri)
      end,
    }, function(location)
      if location then
        gtd._open(params, location)
      else
        print('Canceled')
      end
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

---@param params { command: string }
---@param config? gtd.kit.App.Config.Schema
function gtd.exec(params, config)
  config = kit.merge(config or {}, gtd.config:get())

  ---@type gtd.kit.LSP.DefinitionParams
  local definition_params = {
    textDocument = {
      uri = vim.uri_from_fname(config.get_buffer_path())
    },
    position = Position.cursor(LSP.PositionEncodingKind.UTF16),
  }
  ---@type gtd.Context
  local context = {
    bufnr = vim.api.nvim_get_current_buf()
  }
  Async.run(function()
    for _, source_config in ipairs(config.sources) do
      local source = gtd.registry[source_config.name]
      if source then
        local locations = gtd._normalize(source:execute(definition_params, context):await())
        if #locations > 0 then
          return locations
        end
      end
    end
    return {}
  end):next(function(locations --[[ @as gtd.kit.LSP.LocationLink[] ]])
    if #locations == 0 then
      config.on_nothing(params)
    elseif #locations == 1 then
      config.on_location(params, locations[1])
    else
      config.on_locations(params, locations)
    end
  end):catch(function(err)
    print(err)
  end)
end

---Normalize textDocument/definition response.
---@param locations gtd.kit.LSP.Location | gtd.kit.LSP.LocationLink | (gtd.kit.LSP.Location | gtd.kit.LSP.LocationLink)[] | nil
---@return gtd.kit.LSP.LocationLink[]
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
    if location and location.uri then
      table.insert(new_locations, {
        targetUri = location.uri,
        targetRange = location.range,
        targetSelectionRange = location.range,
      })
    else
      table.insert(new_locations, location)
    end
  end
  return new_locations
end

---Open LocationLink.
---@param params gtd.Params
---@param location gtd.kit.LSP.LocationLink
function gtd._open(params, location)
  vim.cmd[params.command] { args = { vim.uri_to_fname(location.targetUri) } }
  if location.targetSelectionRange then
    local row = location.targetSelectionRange.start.line + 1
    local col = location.targetSelectionRange.start.character + 1
    if row ~= 1 or col ~= 1 then
      vim.api.nvim_win_set_cursor(0, { row, col - 1 })
    end
  end
end

gtd.register_source('vim', require('gtd.source.vim').new())
gtd.register_source('lsp', require('gtd.source.lsp').new())

return gtd
