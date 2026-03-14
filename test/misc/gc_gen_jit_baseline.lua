local jit = require"jit"
local jutil = require"jit.util"

collectgarbage()
collectgarbage("generational")

jit.opt.start("hotloop=1")

local function hot(n)
  local sum = 0
  for i = 1, 200 do
    sum = sum + n + i
  end
  return sum
end

for i = 1, 50 do
  hot(i)
end

assert(jutil.traceinfo(1), "trace not recorded in generational mode")

for i = 1, 50 do
  collectgarbage("step")
  hot(i)
end

assert(jutil.traceinfo(1), "trace lost after generational steps")
print("OK")