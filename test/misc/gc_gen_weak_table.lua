-- Regression test: weak table + gen-gc interaction.
-- Weak tables in gen-gc mode must correctly clear dead entries and
-- not corrupt the grayagain list via TOUCHED state changes.

local jit = require"jit"
jit.off()

collectgarbage("generational")

-- Weak-value table.
local wv = setmetatable({}, { __mode = "v" })
-- Weak-key table.
local wk = setmetatable({}, { __mode = "k" })

-- Populate and age.
local strong = {}
for i = 1, 50 do
  local k = { kid = i }
  local v = { vid = i }
  wv[i] = v
  wk[k] = i
  strong[i] = { k = k, v = v }
end
for i = 1, 5 do collectgarbage() end

-- Drop half the strong references.
for i = 1, 25 do
  strong[i] = nil
end
collectgarbage()

-- Weak entries for 1-25 should be cleared.
for i = 1, 25 do
  assert(wv[i] == nil, "wv["..i.."] not cleared")
end
-- Weak entries for 26-50 should survive.
for i = 26, 50 do
  assert(wv[i] ~= nil and wv[i].vid == i, "wv["..i.."] lost")
end

-- Stress: store into weak tables across GC cycles.
for round = 1, 50 do
  for i = 1, 20 do
    wv[100 + round * 20 + i] = { rid = round }
  end
  if round % 10 == 0 then collectgarbage() end
end
collectgarbage()

print("OK")
