-- Regression test: lj_gc_separateudata boundary safety in gen-gc.
-- Dead finalizable userdata separated by lj_gc_separateudata must not
-- corrupt the udatasurvival/udataold/udatarold boundary pointers.

local jit = require"jit"
jit.off()

collectgarbage("generational")

local old_ud = {}
for i = 1, 50 do
  local u = newproxy(true)
  getmetatable(u).__gc = function() end
  getmetatable(u).__index = { id = i }
  old_ud[i] = u
end
for i = 1, 5 do collectgarbage() end

-- Create SURVIVAL userdata then kill them.
local surv = {}
for i = 1, 10 do
  local u = newproxy(true)
  getmetatable(u).__gc = function() end
  getmetatable(u).__index = { id = 100 + i }
  surv[i] = u
end
collectgarbage()
surv = nil

-- NEW userdata.
local new_ud = {}
for i = 1, 10 do
  local u = newproxy(true)
  getmetatable(u).__gc = function() end
  getmetatable(u).__index = { id = 200 + i }
  new_ud[i] = u
end

-- Collection separates dead surv userdata.
collectgarbage()

for round = 1, 20 do
  for j = 1, 200 do local _ = { ("x"):rep(64) } end
  collectgarbage()
end

-- Verify old userdata survived.
for i = 1, 50 do
  assert(old_ud[i] ~= nil, "old_ud["..i.."] lost")
  assert(getmetatable(old_ud[i]).__index.id == i, "old_ud["..i.."] corrupted")
end
for i = 1, 10 do
  assert(new_ud[i] ~= nil, "new_ud["..i.."] lost")
end

print("OK")
