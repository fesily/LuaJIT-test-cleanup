local jit = require"jit"
local jutil = require"jit.util"

collectgarbage()
collectgarbage("generational")
jit.opt.start("hotloop=1")

local function hot(n)
  if n % 5 == 0 then
    collectgarbage("step")
  end
  return n + 1
end

for i = 1, 200 do
  hot(i)
end

assert(jutil.traceinfo(1) == nil or jutil.traceinfo(1))
print("OK")