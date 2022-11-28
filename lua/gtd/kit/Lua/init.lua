local Lua = {}

---Create gabage collection detector.
---@param callback fun(...: any): any
---@return userdata
function Lua.gc(callback)
  local gc = newproxy(true)
  if vim.is_thread() or os.getenv('NODE_ENV') == 'test' then
    getmetatable(gc).__gc = callback
  else
    getmetatable(gc).__gc = vim.schedule_wrap(callback)
  end
  return gc
end

return Lua
