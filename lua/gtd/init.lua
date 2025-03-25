local kit = require('gtd.kit')
local helper = require('gtd.helper')
local Config = require('gtd.kit.App.Config')
local LSP = require('gtd.kit.LSP')
local Async = require('gtd.kit.Async')
local RegExp = require('gtd.kit.Vim.RegExp')
local Position = require('gtd.kit.LSP.Position')

local POS_PATTERN = RegExp.get([=[[^[:digit:]]\d\+\%([^[:digit:]]\d\+\)\?]=])

---@class gtd.kit.App.Config.Schema
---@field public sources { name: string, option?: table }[] # Specify the source that will be used to search for the definition
---@field public get_buffer_path fun(): string # Specify the function to get the current buffer path. It's useful for searching path from terminal buffer etc.
---@field public on_event fun(event: gtd.Event)
---@field public on_context fun(context: gtd.Context) # Modify context on user-land.
---@field public on_cancel fun(params: gtd.Params)
---@field public on_nothing fun(params: gtd.Params)
---@field public on_location fun(params: gtd.Params, location: gtd.kit.LSP.LocationLink)
---@field public on_locations fun(params: gtd.Params, locations: gtd.kit.LSP.LocationLink[])

---@class gtd.Source
---@field public name string
---@field public get_position_encoding_kind? fun(): gtd.kit.LSP.PositionEncodingKind
---@field public execute fun(self: gtd.Source, params: gtd.kit.LSP.DefinitionParams, context: gtd.Context, option?: table): gtd.kit.Async.AsyncTask

---@class gtd.Params
---@field public command string

---@class gtd.Context
---@field public mode string
---@field public bufnr integer
---@field public text string
---@field public fname? string
---@field public row integer # 0-origin utf8 byte index
---@field public col integer # 0-origin utf8 byte index
---@field public is_obsolete fun(): boolean

local gtd = {}

---@enum gtd.Event
gtd.Event = {
  Start = 'Start',
  Cancel = 'Cancel',
  Nothing = 'Nothing',
  Location = 'Location',
  Locations = 'Locations',
  Finish = 'Finish',
}

gtd.config = Config.new({
  sources = {
    { name = 'lsp_definition' },
    { name = 'lsp_type_definition' },
    { name = 'lsp_implementation' },
    { name = 'findup' },
  },
  get_buffer_path = function()
    local name = vim.api.nvim_buf_get_name(0)
    if vim.fn.isdirectory(name) then
      return name
    end
    return vim.fn.getcwd()
  end,
  on_context = function(ctx)
    helper.fix_diff(ctx)
    helper.fix_scheme_fragment(ctx)
  end,
  on_event = function(_)
  end,
  on_cancel = function(_)
    print('Canceled')
  end,
  on_nothing = function(_)
    print('Nothing found')
  end,
  on_location = function(params, location)
    gtd.open(params, location)
  end,
  on_locations = function(params, locations)
    vim.ui.select(locations, {
      prompt = 'Select file',
      format_item = function(location)
        return vim.uri_to_fname(location.targetUri)
      end,
    }, function(location)
      if location then
        gtd.open(params, location)
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
    position = Position.cursor(LSP.PositionEncodingKind.UTF8),
  }
  local context = gtd._context()
  config.on_context(context)
  Async.run(function()
    config.on_event(gtd.Event.Start)
    for _, source_configs in ipairs(config.sources) do
      local unique_locations = {}
      for _, source_config in ipairs(kit.to_array(source_configs)) do
        local source = gtd.registry[source_config.name]
        if source then
          local encoding_fixed_params = kit.merge({
            position = Position.to(
              context.text,
              definition_params.position,
              LSP.PositionEncodingKind.UTF8,
              source:get_position_encoding_kind()
            )
          }, definition_params)
          local locations = source:execute(encoding_fixed_params, context, source_config.option)
          locations = locations:catch(function() return {} end)
          locations = locations:await()
          locations = gtd._normalize(locations, context, source:get_position_encoding_kind())
          for _, location in ipairs(locations) do
            unique_locations[location.targetUri] = location
          end
        end
      end
      if #vim.tbl_keys(unique_locations) > 0 then
        return vim.tbl_values(unique_locations)
      end
    end
    return {}
  end):next(function(locations --[[ @as gtd.kit.LSP.LocationLink[] ]])
    if #locations == 0 then
      config.on_event(gtd.Event.Nothing)
      config.on_nothing(params)
    elseif context.is_obsolete() then
      config.on_event(gtd.Event.Cancel)
      config.on_cancel(params)
    elseif #locations == 1 then
      config.on_event(gtd.Event.Location)
      config.on_location(params, locations[1])
    else
      config.on_event(gtd.Event.Locations)
      config.on_locations(params, locations)
    end
    config.on_event(gtd.Event.Finish)
  end):catch(function(err)
    print('[gtd] ' .. tostring(err))
    config.on_event(gtd.Event.Finish)
  end)
end

---Open LocationLink.
---@param params gtd.Params
---@param location gtd.kit.LSP.LocationLink
function gtd.open(params, location)
  local filename = vim.uri_to_fname(location.targetUri)

  local row, col = 1, 1
  if location.targetSelectionRange then
    row = location.targetSelectionRange.start.line + 1
    col = location.targetSelectionRange.start.character + 1
    if row ~= 1 or col ~= 1 then
      vim.cmd.normal({ 'm\'', bang = true })
    end
  end

  local skip = true
  skip = skip and vim.tbl_contains({ 'e', 'b' }, params.command:sub(1, 1))
  skip = skip and vim.fn.bufexists(filename) == 1
  skip = skip and vim.fn.bufnr(filename) == vim.api.nvim_get_current_buf()
  if not skip then
    vim.cmd[params.command]({
      filename,
      mods = {
        keepalt = true,
        keepjumps = true,
      }
    })
  end
  if row ~= 1 or col ~= 1 then
    vim.api.nvim_win_set_cursor(0, { row, col - 1 })
  end
end

---Normalize textDocument/definition response.
---@param locations gtd.kit.LSP.Location | gtd.kit.LSP.LocationLink | (gtd.kit.LSP.Location | gtd.kit.LSP.LocationLink)[] | nil
---@param context gtd.Context
---@param position_encoding_kind gtd.kit.LSP.PositionEncodingKind
---@return gtd.kit.LSP.LocationLink[]
function gtd._normalize(locations, context, position_encoding_kind)
  if not locations then
    return {}
  end
  if locations.uri then
    locations = { locations }
  end
  if locations.targetUri then
    locations = { locations }
  end

  ---@type table<string, gtd.kit.LSP.LocationLink>
  local new_locations = {}
  for _, location in ipairs(locations) do
    if location and location.uri then
      location = {
        targetUri = location.uri,
        targetRange = location.range,
        targetSelectionRange = location.range,
      }
    end
    local start = Position.to(
      context.text,
      location.targetRange.start,
      position_encoding_kind,
      LSP.PositionEncodingKind.UTF8
    )
    new_locations[location.targetUri] = {
      targetUri = location.targetUri,
      targetRange = {
        start = start,
        ['end'] = start
      },
      targetSelectionRange = {
        start = start,
        ['end'] = start
      },
    }
  end
  return vim.tbl_values(new_locations)
end

---@return gtd.Context
function gtd._context()
  local bufnr = vim.api.nvim_get_current_buf()
  local text = vim.api.nvim_get_current_line()
  local fname, _, fname_e = RegExp.extract_at(text or '', [[\f\+]], vim.api.nvim_win_get_cursor(0)[2] + 1)
  local row, col = 0, 0
  if fname then
    local fname_after = text:sub(fname_e)
    local pos_s, pos_e = POS_PATTERN:match_str(fname_after)
    if pos_s and pos_e then
      local extracted = fname_after:sub(pos_s + 2, pos_e)
      if extracted:match('^%d+') then
        row = tonumber(extracted:match('^%d+'), 10) - 1
      end
      if extracted:match('%D%d+$') then
        col = tonumber(extracted:match('%d+$'), 10) - 1
      end
    end
  end
  return {
    mode = vim.api.nvim_get_mode().mode,
    bufnr = bufnr,
    text = text,
    fname = fname,
    row = row,
    col = col,
    is_obsolete = function()
      local now = gtd._context()
      return now.mode:sub(1, 1) ~= 'n' or now.bufnr ~= bufnr
    end
  }
end

gtd.register_source('findup', require('gtd.source.findup').new())
gtd.register_source('walk', require('gtd.source.walk').new())
gtd.register_source('lsp', require('gtd.source.lsp_definition').new(true))
gtd.register_source('lsp_definition', require('gtd.source.lsp_definition').new())
gtd.register_source('lsp_type_definition', require('gtd.source.lsp_type_definition').new())
gtd.register_source('lsp_implementation', require('gtd.source.lsp_implementation').new())

return gtd
