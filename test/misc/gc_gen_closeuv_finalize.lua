-- Regression test: lj_gc_closeuv during GCSfinalize in gen-gc mode.
-- Bug: closing an upvalue from a coroutine resumed inside a __gc finalizer
-- could leave the upvalue in an inconsistent state (white+OLD via makewhite).

local jit = require"jit"
jit.off()

collectgarbage("generational")

local results = {}

-- Create coroutines with upvalues that will be closed during finalization.
local coros = {}
for i = 1, 20 do
  coros[i] = coroutine.create(function()
    local val = { id = i, data = ("C"):rep(128) }
    coroutine.yield(function() return val end)
    return val
  end)
  local ok, getter = coroutine.resume(coros[i])
  assert(ok and getter)
  results[i] = getter
end

-- Age to OLD.
for i = 1, 5 do collectgarbage() end

-- Finalizer resumes coroutines during GCSfinalize, closing their upvalues.
local resumed = false
do
  local u = newproxy(true)
  getmetatable(u).__gc = function()
    if resumed then return end
    resumed = true
    for i = 1, 20 do
      if coroutine.status(coros[i]) == "suspended" then
        coroutine.resume(coros[i])
      end
    end
  end
end

collectgarbage()

-- Force more collections.
for round = 1, 20 do
  for j = 1, 200 do local _ = { ("x"):rep(128) } end
  collectgarbage()
end

-- Verify upvalue values are still correct.
for i = 1, 20 do
  local v = results[i]()
  assert(type(v) == "table" and v.id == i,
         "closure "..i..": expected id="..i..", got "..tostring(v and v.id))
end

print("OK")
