local jit = require"jit"
local jutil = require"jit.util"

jit.off()

local age_name = {
  [0] = "new",
  [1] = "survival",
  [2] = "old0",
  [3] = "old1",
  [4] = "old",
  [5] = "touched1",
  [6] = "touched2",
}

local function gcage(obj)
  return age_name[jutil.gcage(obj)]
end

local function run_once()
  collectgarbage()
  collectgarbage("generational")

  do
    local anchor = {}
    collectgarbage()
    assert(gcage(anchor) == "old")
    anchor[1] = {x = {234}}
    assert(gcage(anchor) == "touched1")
    collectgarbage("step")
    collectgarbage("step")
    assert(anchor[1].x[1] == 234)
  end

  do
    local old = {10}
    collectgarbage()

    local co = coroutine.create(function()
      local value
      local fn = function()
        return value[1]
      end
      value = coroutine.yield(fn)
      coroutine.yield()
    end)

    local ok, fn = coroutine.resume(co)
    assert(ok and type(fn) == "function")
    collectgarbage("step")

    old[1] = {"hello"}
    assert(coroutine.resume(co, {123}))
    co = nil

    collectgarbage("step")
    assert(fn() == 123)
    assert(old[1][1] == "hello")

    collectgarbage("step")
    assert(fn() == 123)
    assert(old[1][1] == "hello")
  end

  collectgarbage("incremental")
end

for i = 1, 200 do
  run_once()
  if i % 20 == 0 then
    io.stdout:write("iter ", i, "\n")
  end
end

print("OK")
