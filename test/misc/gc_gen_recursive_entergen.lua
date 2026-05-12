-- Regression test: recursive entergen from collectgarbage in __gc finalizer.
-- Calling collectgarbage("generational") from a __gc callback during gen-gc
-- finalization must not cause infinite recursion or state corruption.

local jit = require"jit"
jit.off()

collectgarbage("generational")

local depth = 0
local max_depth = 0

for i = 1, 5 do
  local u = newproxy(true)
  getmetatable(u).__gc = function()
    depth = depth + 1
    if depth > max_depth then max_depth = depth end
    if depth < 5 then
      pcall(collectgarbage, "generational")
    end
    depth = depth - 1
  end
end

local t1 = os.clock()
for round = 1, 100 do
  collectgarbage()
  for j = 1, 500 do local _ = { ("x"):rep(64) } end
  assert(os.clock() - t1 < 10, "TIMEOUT: likely infinite loop")
end

print("OK")
