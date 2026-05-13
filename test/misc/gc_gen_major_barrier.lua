-- Test: write barriers during KGC_GENMAJOR incremental phase.
-- Writing new values into old tables during major collection must not corrupt
-- the grayagain list or cause objects to be missed by atomic propagation.
-- Covers: barrierback TOUCHED1, correctgraylist, atomic grayagain (== KGC_GEN fix).

local jit = require"jit"
jit.off()

local oldmode = collectgarbage("generational", 20, 10)

-- Create tables and age them to OLD.
local old_tables = {}
for i = 1, 50 do
  old_tables[i] = { id = i }
end
for i = 1, 10 do collectgarbage("step") end

-- Force major collection via heavy allocation.
for i = 1, 50 do
  local _ = {}
  for j = 1, 200 do _[j] = { ("P"):rep(128) } end
  collectgarbage("step")
end

-- Now during the major incremental phase, write new values into old tables.
-- This triggers barrierback, setting tables to TOUCHED1 and adding to grayagain.
for step = 1, 100 do
  for i = 1, 50 do
    old_tables[i]["step_"..step] = { step = step, value = ("V"):rep(32) }
  end
  collectgarbage("step")
end

-- Complete major collection.
for i = 1, 200 do collectgarbage("step") end
collectgarbage()

-- Verify all writes survived the major collection + return to gen mode.
for i = 1, 50 do
  assert(old_tables[i].id == i, "table "..i.." id corrupted after major")
  for step = 1, 100 do
    local key = "step_"..step
    assert(type(old_tables[i][key]) == "table",
           "table "..i.." missing "..key)
    assert(old_tables[i][key].step == step,
           "table "..i.." "..key.." step corrupted")
  end
end

-- Now run many minor collections to test that correctgraylist properly
-- handled the TOUCHED1/TOUCHED2 age transitions after major.
for round = 1, 30 do
  for i = 1, 50 do
    old_tables[i]["post_"..round] = { round }
  end
  local garbage = {}
  for j = 1, 100 do garbage[j] = { round, ("M"):rep(64) } end
  collectgarbage("step")
end

collectgarbage()

-- Final verification.
for i = 1, 50 do
  assert(old_tables[i].id == i, "table "..i.." id corrupted after minor cycles")
  assert(type(old_tables[i].post_30) == "table",
         "table "..i.." post-major writes lost")
end

collectgarbage(oldmode)
print("OK")
