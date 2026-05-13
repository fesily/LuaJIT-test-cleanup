-- Test: generational GC major collection lifecycle.
-- Forces minor→major (KGC_GENMAJOR) transition via memory pressure,
-- runs through the 2-cycle incremental countdown, and returns to gen mode.
-- Covers: genstep threshold, minor2inc, genmajor countdown, major2gen, promote2old.

local jit = require"jit"
jit.off()

local oldmode = collectgarbage("generational", 20, 10)

-- Create anchor data that must survive the major collection.
local anchors = {}
for i = 1, 100 do
  anchors[i] = { id = i, data = ("A"):rep(64) }
end

-- Age anchors to OLD by running several minor collections.
for i = 1, 10 do collectgarbage("step") end

-- Allocate heavily to force minor→major transition.
-- With genminormul=20, genmajormul=10, thresholds are very tight.
for round = 1, 50 do
  local garbage = {}
  for j = 1, 500 do
    garbage[j] = { round, j, ("x"):rep(128) }
  end
  collectgarbage("step")
end

-- Run many GC steps to ensure major completes (2 full incremental cycles).
for i = 1, 200 do
  collectgarbage("step")
end

-- Force a full collection to clean up.
collectgarbage()
collectgarbage()

-- Verify anchors survived the entire major cycle.
for i = 1, 100 do
  assert(type(anchors[i]) == "table", "anchor "..i.." is not a table")
  assert(anchors[i].id == i, "anchor "..i.." id corrupted")
  assert(anchors[i].data == ("A"):rep(64), "anchor "..i.." data corrupted")
end

-- Stress: repeat the transition multiple times.
for cycle = 1, 5 do
  local data = {}
  for i = 1, 50 do data[i] = { cycle = cycle, i = i } end
  for i = 1, 5 do collectgarbage("step") end
  for i = 1, 500 do
    local _ = { cycle, i, ("G"):rep(256) }
  end
  for i = 1, 200 do collectgarbage("step") end
  collectgarbage()
  for i = 1, 50 do
    assert(data[i].cycle == cycle, "cycle "..cycle.." data["..i.."] corrupted")
  end
end

collectgarbage(oldmode)
print("OK")
