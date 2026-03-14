local ffi = require"ffi"
local jit = require"jit"
local jutil = require"jit.util"

ffi.cdef[[
typedef struct gc_t { int x; } gc_t;
]]

local finalized = 0
local gc_t = ffi.metatype("gc_t", {
  __gc = function()
    finalized = finalized + 1
  end,
})

collectgarbage()
collectgarbage("generational")
jit.opt.start("hotloop=1")

local function alloc_batch(n)
  for i = 1, n do
    local obj = gc_t()
    obj.x = i
  end
end

for _ = 1, 2 do
  alloc_batch(20)
end

assert(jutil.traceinfo(1), "trace not recorded for finalizable cdata allocation")

local expected = 2 * 20

for _ = 1, 120 do
  collectgarbage("step")
  if finalized >= expected then
    break
  end
end

assert(finalized == expected, finalized)
print("OK")