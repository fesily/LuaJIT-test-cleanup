-- Regression test: mode switching (gen<->inc) from __gc finalizer.
-- Rapidly switching GC modes during finalization must not corrupt state.

local jit = require"jit"
jit.off()

collectgarbage("generational")

local stable = {}
for i = 1, 100 do stable[i] = { id = i, data = ("S"):rep(128) } end
for i = 1, 5 do collectgarbage() end

local objects = {}
local switched = false
do
  local u = newproxy(true)
  getmetatable(u).__gc = function()
    if switched then return end
    switched = true
    for i = 1, 50 do objects[i] = { id = i, data = ("M"):rep(128) } end
    pcall(collectgarbage, "incremental")
    for i = 51, 100 do objects[i] = { id = i, data = ("I"):rep(128) } end
    pcall(collectgarbage, "generational")
    for i = 101, 150 do objects[i] = { id = i, data = ("G"):rep(128) } end
  end
end

collectgarbage()
for round = 1, 20 do
  for j = 1, 300 do local _ = { ("x"):rep(64) } end
  collectgarbage()
end

-- Verify stable objects survived.
for i = 1, 100 do
  assert(stable[i].id == i, "stable["..i.."] corrupted")
end

-- Verify objects created during finalization survived.
local alive = 0
for i = 1, 150 do
  if objects[i] and type(objects[i]) == "table" and objects[i].id == i then
    alive = alive + 1
  end
end
assert(alive >= 100, "too few objects survived mode switch: "..alive)

print("OK")
