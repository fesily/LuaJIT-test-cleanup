-- Regression test: gen-gc boundary pointer consistency.
-- Objects dying at different ages must not corrupt the survival/old/reallyold
-- boundary pointers used by sweepgen.

local jit = require"jit"
jit.off()

collectgarbage("generational")

local stable = {}
for i = 1, 200 do stable[i] = { id = i, payload = ("A"):rep(128) } end
for i = 1, 5 do collectgarbage() end

-- Create and kill objects at different ages.
local gen1 = {}
for i = 1, 50 do gen1[i] = { id = 1000+i, data = ("G1"):rep(64) } end
collectgarbage()

local gen2 = {}
for i = 1, 50 do gen2[i] = { id = 2000+i, data = ("G2"):rep(64) } end
gen1 = nil
collectgarbage()

-- Aggressive cycles with alternating live/dead objects.
for round = 1, 20 do
  local alive = {}
  for i = 1, 100 do
    alive[i] = { id = round * 1000 + i, x = ("L"):rep(64) }
    local _ = { id = round * 1000 + i + 100, x = ("D"):rep(64) }
  end
  collectgarbage()
  for i = 1, 100 do
    assert(alive[i].id == round * 1000 + i, "alive["..i.."] at round "..round)
  end
end

-- Mode switch stress.
collectgarbage("incremental")
collectgarbage()
collectgarbage("generational")
for round = 1, 10 do
  local objs = {}
  for i = 1, 200 do objs[i] = { id = 5000 + round * 100 + i } end
  for i = 1, 100 do objs[i] = nil end
  collectgarbage()
end

-- Verify stable objects survived everything.
for i = 1, 200 do
  assert(stable[i].id == i, "stable["..i.."] corrupted")
end

print("OK")
