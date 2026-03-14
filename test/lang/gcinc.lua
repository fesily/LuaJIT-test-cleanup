print('testing incremental garbage collection')

local jit = require"jit"

jit.off()

assert(collectgarbage("isrunning"))

collectgarbage()

local oldmode = collectgarbage("incremental")

assert(collectgarbage("generational") == "incremental")
assert(collectgarbage("generational") == "generational")
assert(collectgarbage("incremental") == "generational")
assert(collectgarbage("incremental") == "incremental")

local function gcinfo()
  return collectgarbage("count") * 1024
end

local function dosteps(stepsize)
  collectgarbage()
  local objects = {}
  for i = 1, 100 do
    objects[i] = {{}}
    local scratch = {}
  end
  local before = gcinfo()
  local steps = 0
  repeat
    steps = steps + 1
  until collectgarbage("step", stepsize)
  assert(gcinfo() < before)
  return steps
end

collectgarbage("stop")
assert(dosteps(10) < dosteps(2))
collectgarbage("restart")
assert(collectgarbage("isrunning"))

do
  collectgarbage()
  collectgarbage("stop")
  collectgarbage("step")
  local before = gcinfo()
  repeat
    for i = 1, 1000 do
      _G.__gcinc_tmp = {}
    end
  until gcinfo() > 2 * before
  collectgarbage("restart")
  _G.__gcinc_tmp = nil
end

do
  local weak = setmetatable({}, {__mode = "kv"})
  local key, value = {}, {}
  weak[key] = value
  key = nil
  value = nil
  collectgarbage()
  assert(next(weak) == nil)
end

collectgarbage(oldmode)

print('OK')
