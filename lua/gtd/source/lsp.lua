local kit = require('gtd.kit')
local Async = require('gtd.kit.Async')
local Client = require('gtd.kit.LSP.Client')

local Source = {}
Source.__index = Source

function Source.new()
  local self = setmetatable({}, Source)
  return self
end

function Source:get_position_encoding_kind()
  return 'utf-8'
end

---@param params gtd.kit.LSP.DefinitionParams
function Source:execute(params)
  return Async.run(function()
    local locations = {}
    for _, client in ipairs(vim.lsp.get_active_clients({ bufnr = 0 })) do
      local server_capabilities = client.server_capabilities --[[@as gtd.kit.LSP.ServerCapabilities]]
      if server_capabilities.definitionProvider then
        ---@type gtd.kit.LSP.TextDocumentDefinitionResponse
        local response = Client.new(client):textDocument_definition({
          textDocument = params.textDocument,
          position = params.position, -- TODO: Fix position encoding
        }):await()
        if response then
          if response.range then
            locations = kit.concat(locations, { response })
          else
            locations = kit.concat(locations, response)
          end
        end
      end
    end
    return locations
  end)
end

return Source
