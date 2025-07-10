local M = {}

local yield_marker = {}

local function resume(thread, ...)
  --- @type [boolean, {}, string|fun(callback: fun(...))]]
  local ret = { coroutine.resume(thread, ...) }
  local stat = ret[1]

  if not stat then
    error(debug.traceback(thread, ret[2]), 0)
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

---Executes a future with a callback when it is done
--- @param async_fn function: the future to execute
--- @param ... any
function M.run(async_fn, ...)
  resume(coroutine.create(async_fn), ...)
end

local function check(err, ...)
  if err then
    error(err, 0)
  end
  return ...
end

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
--- @param argc integer The number of arguments of func. Must be included.
--- @param func function A callback style function to be converted. The last argument must be the callback.
--- @return function: Returns an async function
--- @overload fun(func: function): function
function M.wrap(argc, func)
  if type(argc) == 'function' then
    func = argc
    argc = 1
  end
  assert(type(argc) == 'number')
  assert(type(func) == 'function')
  return function(...)
    return M.await(argc, func, ...)
  end
end

M.scheduler = M.wrap(vim.schedule)

return M
