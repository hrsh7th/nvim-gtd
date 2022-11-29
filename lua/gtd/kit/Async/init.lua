local uv = require('luv')
local AsyncTask = require('gtd.kit.Async.AsyncTask')

local Async = {}

Async.___threads___ = {}

---Run async function immediately.
---@generic T: fun(...): gtd.kit.Async.AsyncTask
---@param runner T
---@param ... any
---@return gtd.kit.Async.AsyncTask
function Async.run(runner, ...)
  return Async.async(runner)(...)
end

---Create async function.
---@generic T: fun(...): gtd.kit.Async.AsyncTask
---@param runner T
---@return T
function Async.async(runner)
  return function(...)
    local args = { ... }
    local thread = coroutine.create(runner)
    return AsyncTask.new(function(resolve, reject)
      Async.___threads___[thread] = true

      local function next_step(ok, v)
        if coroutine.status(thread) == 'dead' then
          Async.___threads___[thread] = nil
          if not ok then
            AsyncTask.reject(v):next(resolve):catch(reject)
          else
            AsyncTask.resolve(v):next(resolve):catch(reject)
          end
          return
        end

        AsyncTask.resolve(v)
            :next(function(...)
              next_step(coroutine.resume(thread, true, ...))
            end)
            :catch(function(...)
              next_step(coroutine.resume(thread, false, ...))
            end)
      end

      next_step(coroutine.resume(thread, unpack(args)))
    end)
  end
end

---Await async task.
---@param task gtd.kit.Async.AsyncTask
---@return any
function Async.await(task)
  if not Async.___threads___[coroutine.running()] then
    error('`Async.await` must be called in async function.')
  end
  local ok, res = coroutine.yield(AsyncTask.resolve(task))
  if not ok then
    error(res)
  end
  return res
end

---Create async function from callback function.
---@generic T: ...
---@param runner fun(...: T)
---@param option? { schedule?: boolean, callback?: integer }
---@return fun(...: T): gtd.kit.Async.AsyncTask
function Async.promisify(runner, option)
  option = option or {}
  option.schedule = option.schedule or true
  option.callback = option.callback or nil
  return function(...)
    local args = { ... }
    return AsyncTask.new(function(resolve, reject)
      local max = #args + 1
      local pos = math.min(option.callback or max, max)
      table.insert(args, pos, function(err, ...)
        if not vim.is_thread() then
          if option.schedule and vim.in_fast_event() then
            resolve = vim.schedule_wrap(resolve)
            reject = vim.schedule_wrap(reject)
          end
        end
        if err then
          reject(err)
        else
          resolve(...)
        end
      end)
      runner(unpack(args))
    end)
  end
end

return Async
