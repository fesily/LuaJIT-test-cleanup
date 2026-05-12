-- Regression test: lj_gc_barrierback assertion in gen-gc during GCSfinalize.
-- Bug: the assert (state != GCSfinalize) fires in debug builds when a __gc
-- finalizer stores into an OLD+BLACK table, triggering barrierback.
-- This is legitimate in gen-gc mode where finalizers run during GCSfinalize.

local jit = require"jit"
jit.off()

collectgarbage("generational")

local N = 20
local containers = {}
for i = 1, N do containers[i] = { id = i } end
for i = 1, 5 do collectgarbage() end

-- Finalizer stores into OLD+BLACK tables during GCSfinalize.
do
  local u = newproxy(true)
  getmetatable(u).__gc = function()
    for i = 1, N do
      containers[i].gc_data = { wave = 1 }
    end
  end
end

collectgarbage()

-- Multiple GC cycles to verify grayagain consistency.
for round = 1, 200 do
  for j = 1, 300 do local _ = { ("z"):rep(128) } end
  for i = 1, N do
    assert(type(containers[i]) == "table" and containers[i].id == i,
           "container "..i.." corrupted at round "..round)
  end
end

print("OK")
