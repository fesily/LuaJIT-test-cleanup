-- Regression test: coroutine + upvalue interactions in gen-gc.
-- Resuming OLD coroutines that create NEW upvalues must not lose values.

local jit = require"jit"
jit.off()

collectgarbage("generational")

local N = 20
local getters = {}
local coros = {}

local function capture_upvals(n)
  local vals = {}
  for i = 1, n do
    local v = { id = i, data = ("V"):rep(128) }
    vals[i] = v
    coroutine.yield(function() return v end)
  end
  return vals
end

for i = 1, N do
  local co = coroutine.create(capture_upvals)
  local ok, getter = coroutine.resume(co, 5)
  assert(ok and getter)
  getters[#getters + 1] = getter
  coros[i] = co
end

-- Age to OLD.
for i = 1, 5 do collectgarbage() end

-- Resume OLD coroutines to create NEW open upvalues.
for i = 1, N do
  for j = 2, 5 do
    local ok, getter = coroutine.resume(coros[i])
    if ok and type(getter) == "function" then
      getters[#getters + 1] = getter
    end
  end
end

-- GC cycles.
for round = 1, 10 do
  for j = 1, 500 do local _ = { ("x"):rep(64) } end
  collectgarbage()
end

-- Verify all captured upvalues are valid.
for i, getter in ipairs(getters) do
  local v = getter()
  assert(type(v) == "table" and v.id ~= nil,
         "getter "..i..": corrupted value")
end

print("OK")
