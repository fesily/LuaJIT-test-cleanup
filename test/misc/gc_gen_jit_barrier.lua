-- Test: JIT write barrier must not corrupt grayagain list in generational GC.
-- Regression test for a bug where asm_tbar (JIT table barrier) did not check
-- the object age, causing duplicate grayagain entries and list corruption
-- when a TOUCHED2 table was written to in JIT-compiled code.

local jit = require"jit"

jit.opt.start("hotloop=1")

collectgarbage("generational")

-- Scenario 1: basic JIT + gen GC interaction
do
  local t = {}
  for i = 1, 1000 do t[i] = {x=i, y=i*2} end
  for i = 1, 500 do t[i] = nil end
  collectgarbage()
  for i = 1, 800 do t[500+i] = {x=i, y=i*2} end
  collectgarbage()
end

-- Scenario 2: repeated writes to the same table in a JIT-compiled loop
-- (exercises barrier on TOUCHED2 objects)
do
  local t = {}
  for i = 1, 100 do
    t[1] = {i}
    if i % 20 == 0 then collectgarbage() end
  end
end

-- Scenario 3: minor-to-major transition under JIT
do
  local tabs = {}
  for round = 1, 5 do
    for i = 1, 500 do
      tabs[i] = {round, i}
    end
    collectgarbage()
  end
end

-- Scenario 4: mode switching with JIT-compiled writes
do
  local t = {}
  collectgarbage("generational")
  for i = 1, 200 do t[i] = {i} end
  collectgarbage("incremental")
  for i = 1, 200 do t[i] = {i + 1000} end
  collectgarbage("generational")
  for i = 1, 200 do t[i] = {i + 2000} end
  collectgarbage()
end

print("OK")
