local ffi = require"ffi"
local jutil = require"jit.util"

local age_name = {
  [0] = "new",
  [1] = "survival",
  [2] = "old0",
  [3] = "old1",
  [4] = "old",
  [5] = "touched1",
  [6] = "touched2",
}

collectgarbage()
collectgarbage("generational")

local arr = ffi.new("uint8_t[?]", 32)
assert(age_name[jutil.gcage(arr)] == "new", "variable-size cdata is missing a generational age")

collectgarbage("step")
assert(age_name[jutil.gcage(arr)] ~= nil, "variable-size cdata lost its generational age after a step")

print("OK")