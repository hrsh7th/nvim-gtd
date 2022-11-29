local uv = require('luv')
local AsyncTask = require('gtd.kit.Async.AsyncTask')

---@class gtd.kit.Lua.WorkerOption
---@field public runtimepath string[]

local Worker = {}
Worker.__index = Worker

---Create a new thread.
---@param runner function
function Worker.new(runner)
  local self = setmetatable({}, Worker)
  self.runner = string.dump(runner)
  return self
end

---Call worker function.
---@return gtd.kit.Async.AsyncTask
function Worker:__call(...)
  local args_ = { ... }
  return AsyncTask.new(function(resolve, reject)
    uv.new_work(function(runner, args, option)
      args = vim.json.decode(args)
      option = vim.json.decode(option)

      --Initialize cwd.
      require('luv').chdir(option.cwd)

      --Initialize package.loaders.
      table.insert(package.loaders, 2, vim._load_package)

      --Run runner function.
      local ok, res = pcall(function()
        return require('gtd.kit.Async.AsyncTask').resolve(assert(loadstring(runner))(unpack(args))):sync()
      end)

      res = vim.json.encode(res)

      --Return error or result.
      if not ok then
        return res, nil
      else
        return nil, res
      end
    end, function(err, res)
      if err then
        reject(vim.json.decode(err))
      else
        resolve(vim.json.decode(res))
      end
    end):queue(
      self.runner,
      vim.json.encode(args_),
      vim.json.encode({
        cwd = vim.fn.getcwd(),
      })
    )
  end)
end

return Worker
