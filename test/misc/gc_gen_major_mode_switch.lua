-- Test: mode switching during and after KGC_GENMAJOR.
-- Switching between generational and incremental modes while a major
-- collection is in progress must not corrupt GC state.
-- Covers: lj_gc_changemode, lj_gc_fullgc with GENMAJOR, enterinc/entergen.

local jit = require"jit"
jit.off()

-- Test 1: Switch to incremental mid-major, then back to gen.
do
  collectgarbage("generational", 20, 10)
  local data = {}
  for i = 1, 50 do data[i] = { id = i, payload = ("D"):rep(64) } end
  for i = 1, 10 do collectgarbage("step") end

  -- Force major via heavy allocation.
  for i = 1, 80 do
    local _ = {}
    for j = 1, 200 do _[j] = { ("X"):rep(128) } end
    collectgarbage("step")
  end

  -- Switch to incremental mid-major — should abort major cleanly.
  collectgarbage("incremental")

  -- Run some incremental GC steps.
  for i = 1, 50 do collectgarbage("step") end
  collectgarbage()

  -- Switch back to generational.
  collectgarbage("generational", 20, 10)
  for i = 1, 20 do collectgarbage("step") end

  -- Verify data survived all transitions.
  for i = 1, 50 do
    assert(data[i].id == i, "test1: data["..i.."] corrupted")
  end
end

-- Test 2: fullgc (collectgarbage("collect")) during major phase.
do
  collectgarbage("generational", 20, 10)
  local data = {}
  for i = 1, 50 do data[i] = { id = i, payload = ("C"):rep(64) } end
  for i = 1, 10 do collectgarbage("step") end

  -- Force major.
  for i = 1, 80 do
    local _ = {}
    for j = 1, 200 do _[j] = { ("Y"):rep(128) } end
    collectgarbage("step")
  end

  -- Full GC during major — should reset kind to INC then run full cycle.
  collectgarbage("collect")

  -- Continue in gen mode.
  for i = 1, 20 do collectgarbage("step") end

  for i = 1, 50 do
    assert(data[i].id == i, "test2: data["..i.."] corrupted")
  end
end

-- Test 3: Rapid mode switching stress test.
do
  local data = {}
  for i = 1, 30 do data[i] = { id = i } end

  for round = 1, 10 do
    collectgarbage("generational", 20, 10)
    for i = 1, 30 do
      data[i]["round_"..round] = { round }
    end
    -- Allocate to potentially trigger major.
    for i = 1, 50 do
      local _ = {}
      for j = 1, 100 do _[j] = { ("Z"):rep(64) } end
      collectgarbage("step")
    end
    collectgarbage("incremental")
    collectgarbage("step")
    collectgarbage("step")
  end

  collectgarbage()
  for i = 1, 30 do
    assert(data[i].id == i, "test3: data["..i.."] corrupted")
    assert(type(data[i].round_10) == "table", "test3: data["..i.."] missing round_10")
  end
end

collectgarbage("incremental")
print("OK")
