local co = coroutine

local async_thread = {
  ---@type {[string]: boolean}
  threads = {},
}

function async_thread.inside()
  local id = string.format('%p', co.running())
  return async_thread.threads[id]
end

function async_thread.create(fn)
  local thread = co.create(fn)
  local id = string.format('%p', thread)
  async_thread.threads[id] = true
  return thread
end

function async_thread.finished(x)
  if co.status(x) == 'dead' then
    local id = string.format('%p', x)
    async_thread.threads[id] = nil
    return true
  end
  return false
end

local function execute(async_fn, ...)
  local thread = async_thread.create(async_fn)

  local function step(...)
    local ret = { co.resume(thread, ...) }
    local stat, err_or_fn, nargs = unpack(ret)

    if not stat then
      error(
        string.format(
          'The coroutine failed with this message: %s\n%s',
          err_or_fn,
          debug.traceback(thread)
        )
      )
    end

    if async_thread.finished(thread) then
      return
    end

    assert(type(err_or_fn) == 'function', 'type error :: expected func')

    local ret_fn = err_or_fn
    local args = { select(4, unpack(ret)) }
    args[nargs] = step
    ret_fn(unpack(args, 1, nargs))
  end

  step(...)
end

local M = {}

---@param func function
---@param argc integer
---@return function
function M.wrap(func, argc)
  ---@async
  return function(...)
    if not async_thread.inside() then
      return func(...)
    end
    return co.yield(func, argc, ...)
  end
end

function M.void(func)
  return function(...)
    if async_thread.inside() then
      return func(...)
    end
    execute(func, ...)
  end
end

M.scheduler = M.wrap(vim.schedule, 1)

return M
