local M = {}

local yield_marker = {}

local function resume(thread, ...)
  --- @type [boolean, string|{}, fun(callback: fun(...))]]
  local ret = { coroutine.resume(thread, ...) }
  local stat = ret[1]

  if not stat then
    local err = ret[2] --[[@as string]]
    error(debug.traceback(thread, err), 0)
  elseif coroutine.status(thread) == 'dead' then
    return
  end

  local marker, fn = ret[2], ret[3]

  assert(type(fn) == 'function', 'type error :: expected func')

  if marker ~= yield_marker or not vim.is_callable(fn) then
    return error('Unexpected coroutine.yield')
  end

  local ok, perr = pcall(fn, function(...)
    resume(thread, ...)
  end)
  if not ok then
    resume(thread, perr)
  end
end

--- Executes a future with a callback when it is done
--- @generic T, R
--- @param async_fn async fun(...:T...): R...
--- @param ... T...
function M.run(async_fn, ...)
  resume(coroutine.create(async_fn), ...)
end

local function check(err, ...)
  if err then
    error(err, 0)
  end
  return ...
end

--- @async
--- @generic T, R
--- @param argc integer
--- @param func fun(...:T..., cb: fun(...:R...))
--- @param ... T...
--- @return R...
function M.await(argc, func, ...)
  if type(argc) == 'function' then
    func = argc
    argc = 1
  end
  local nargs, args = select('#', ...), { ... }
  return check(coroutine.yield(yield_marker, function(callback)
    args[argc] = function(...)
      callback(nil, ...)
    end
    nargs = math.max(nargs, argc)
    return func(unpack(args, 1, nargs))
  end))
end

--- Creates an async function with a callback style function.
--- @generic T, R
--- @param argc integer
--- @param func fun(...:T..., cb: fun(...:R...)): any
--- @return async fun(...:T...):R...
--- @overload fun(func: fun(cb: fun(...:R...))): async fun()
function M.wrap(argc, func)
  if type(argc) == 'function' then
    func = argc
    argc = 1
  end
  assert(type(argc) == 'number')
  assert(type(func) == 'function')
  --- @async
  return function(...)
    return M.await(argc, func, ...)
  end
end

M.scheduler = M.wrap(vim.schedule)

return M
