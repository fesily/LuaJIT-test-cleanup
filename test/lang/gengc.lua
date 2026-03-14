-- Generational GC regression tests adapted for the current LuaJIT port.

print('testing generational garbage collection')

local debug = require"debug"
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

local function gccolor(obj)
  return jutil.gccolor(obj)
end

assert(collectgarbage("isrunning"))

collectgarbage()

local oldmode = collectgarbage("generational")

assert(collectgarbage("generational") == "generational")
assert(collectgarbage("incremental") == "generational")
assert(collectgarbage("generational") == "incremental")

-- Ensure that a table barrier evolves correctly across minor collections.
do
  local anchor = {}
  collectgarbage()
  assert(gcage(anchor) == "old")

  anchor[1] = {x = {234}}
  assert(gcage(anchor) == "touched1")
  assert(gcage(anchor[1]) == "new")

  collectgarbage("step")
  assert(gcage(anchor) == "touched2")
  assert(gcage(anchor[1]) == "survival")

  collectgarbage("step")
  assert(gcage(anchor) == "old")
  assert(gcage(anchor[1]) == "old1")
  assert(anchor[1].x[1] == 234)
end

-- Ensure that removing an OLD1 object from the allgc list does not corrupt the boundary.
do
  local old = {10}
  collectgarbage()
  assert(gcage(old) == "old")

  setmetatable(old, {})
  assert(gcage(getmetatable(old)) == "new")

  collectgarbage("step")
  assert(gcage(getmetatable(old)) == "survival")

  collectgarbage("step")

  setmetatable(getmetatable(old), {__gc = function() end})
  collectgarbage("step")
end

-- Regression for finalizing an OLD1 object moved back to the beginning of allgc.
do
  local anchor = {false}

  local function gcf(obj)
    anchor[1] = obj
    assert(gcage(obj) == "old1")
    obj = nil
    collectgarbage("step")
    assert(getmetatable(anchor[1]).x == "+")
  end

  collectgarbage()
  local obj = {}
  collectgarbage("step")
  assert(gcage(obj) == "survival")

  setmetatable(obj, {__gc = gcf, x = "+"})
  assert(gcage(getmetatable(obj)) == "new")

  obj = nil
  collectgarbage("step")
end

-- Regression for all-weak tables kept on grayagain across minor collections.
do
  local weak = setmetatable({}, {__mode = "kv"})
  collectgarbage()
  assert(gcage(weak) == "old")

  weak[1] = {10}
  assert(gcage(weak) == "touched1")
  assert(gccolor(weak) == "gray")

  collectgarbage("step")
  assert(gcage(weak) == "touched2")
  assert(gccolor(weak) == "black")

  collectgarbage("step")
  assert(gcage(weak) == "old")

  weak[1] = {10}
  collectgarbage("step")
  assert(weak[1] == nil)
end

assert(collectgarbage("isrunning"))
collectgarbage(oldmode)

print('OK')
