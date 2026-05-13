-- Generational GC regression tests.
-- Tests for bugs found during gen GC implementation with JIT.

local jit = require"jit"

jit.off()

do --- udata_finalizer_separateudata
  -- Regression: lj_gc_separateudata must update gen GC sentinel pointers
  -- (udatasurvival/udataold/udatarold) when moving udata to mmudata list.
  -- Without this fix, sweepgen hits NULL before reaching the sentinel.
  local oldmode = collectgarbage("generational")
  local collected = {}
  for i = 1, 50 do
    local ud = newproxy(true)
    getmetatable(ud).__gc = function(self)
      collected[#collected + 1] = true
    end
  end
  for i = 1, 5 do
    collectgarbage("step")
  end
  collectgarbage()
  assert(#collected > 0, "finalizers should have run")
  collectgarbage(oldmode)
end

do --- udata_finalizer_stress
  -- Stress: many udata with __gc across multiple minor collections.
  local oldmode = collectgarbage("generational")
  local count = 0
  for round = 1, 10 do
    for i = 1, 20 do
      local ud = newproxy(true)
      getmetatable(ud).__gc = function() count = count + 1 end
    end
    collectgarbage("step")
  end
  collectgarbage()
  collectgarbage()
  assert(count > 0, "finalizers must run")
  collectgarbage(oldmode)
end

do --- finalizer_closes_upvalue
  -- Regression: lj_gc_closeuv must handle GCSfinalize state in gen GC.
  -- A __gc callback that causes upvalue closure should not crash.
  local oldmode = collectgarbage("generational")
  local results = {}
  for i = 1, 10 do
    local val = i
    local ud = newproxy(true)
    getmetatable(ud).__gc = function()
      results[#results + 1] = val
    end
  end
  collectgarbage()
  collectgarbage()
  assert(#results > 0, "finalizers with upvalues should run")
  collectgarbage(oldmode)
end

do --- finalizer_writes_table
  -- Regression: lj_gc_barrierback must allow GCSfinalize state in gen GC.
  -- A __gc callback that writes to a table should not crash.
  local oldmode = collectgarbage("generational")
  local anchor = {}
  collectgarbage()
  for i = 1, 20 do
    local ud = newproxy(true)
    getmetatable(ud).__gc = function()
      anchor[#anchor + 1] = "finalized"
    end
  end
  collectgarbage()
  collectgarbage()
  assert(#anchor > 0, "finalizers should write to table")
  collectgarbage(oldmode)
end

do --- finalizer_forward_barrier
  -- Regression: lj_gc_barrierf must allow GCSfinalize state in gen GC.
  -- A __gc callback that triggers a forward write barrier should not crash.
  local oldmode = collectgarbage("generational")
  local anchor = {}
  collectgarbage()
  for i = 1, 20 do
    local ud = newproxy(true)
    local meta = getmetatable(ud)
    meta.__gc = function(self)
      local t = {}
      t.value = tostring(i)
      anchor[#anchor + 1] = t
    end
  end
  collectgarbage()
  collectgarbage()
  assert(#anchor > 0)
  collectgarbage(oldmode)
end

do --- jit_trace_survives_major
  -- Regression: trace objects must have age set to G_NEW so they survive
  -- sweepgen correctly and don't get corrupted during major collection.
  jit.on()
  local oldmode = collectgarbage("generational")
  jit.opt.start("hotloop=1")
  local sum = 0
  local function hotloop(n)
    local s = 0
    for i = 1, n do s = s + i end
    return s
  end
  for round = 1, 20 do
    sum = sum + hotloop(100)
    local t = {}
    for i = 1, 500 do t[i] = {round, i} end
    collectgarbage()
  end
  assert(sum == 20 * 5050)
  collectgarbage(oldmode)
  jit.off()
end

do --- jit_major_collection_concat
  -- Regression: string concatenation in JIT triggers GC step which may
  -- enter incstep during KGC_GENMAJOR. Traces must not be corrupted.
  jit.on()
  local oldmode = collectgarbage("generational")
  jit.opt.start("hotloop=1")
  local results = {}
  for i = 1, 200 do
    results[i] = "item_" .. tostring(i) .. "_end"
    if i % 50 == 0 then
      for j = 1, 200 do
        local _ = {j, j+1, j+2}
      end
      collectgarbage()
    end
  end
  assert(#results == 200)
  assert(results[1] == "item_1_end")
  assert(results[200] == "item_200_end")
  collectgarbage(oldmode)
  jit.off()
end

do --- mixed_gc_modes_with_finalizers
  -- Switching between gen and inc modes while finalizers are pending.
  local count = 0
  collectgarbage("generational")
  for i = 1, 10 do
    local ud = newproxy(true)
    getmetatable(ud).__gc = function() count = count + 1 end
  end
  collectgarbage("incremental")
  collectgarbage()
  collectgarbage("generational")
  for i = 1, 10 do
    local ud = newproxy(true)
    getmetatable(ud).__gc = function() count = count + 1 end
  end
  collectgarbage()
  collectgarbage()
  assert(count > 0)
  collectgarbage("incremental")
end

do --- weak_table_touched_barrier
  -- Regression: correctgraylist asserted TOUCHED1 objects must be gray, but
  -- weak tables can be BLACK+TOUCHED1 after atomic propagation.
  local oldmode = collectgarbage("generational")
  for round = 1, 10 do
    local t = setmetatable({}, {__mode = "kv"})
    for i = 1, 20 do
      local ud = newproxy(true)
      getmetatable(ud).__gc = function() end
      t[ud] = i
    end
    collectgarbage("step")
  end
  collectgarbage(oldmode)
end

do --- trace_proto_survives_minor
  -- Regression: OLD traces must keep their proto alive during minor
  -- collections. Without gc_marktraceprotos, the proto is swept while
  -- the trace survives, corrupting T->startpt.
  jit.on()
  local oldmode = collectgarbage("generational")
  jit.opt.start("hotloop=1")
  for j = 1, 50 do
    loadstring("for i=1,100 do end")()
  end
  for k = 1, 20 do
    local garbage = {}
    for i = 1, 500 do garbage[i] = {k, i} end
    collectgarbage("step")
  end
  collectgarbage()
  collectgarbage(oldmode)
  jit.off()
end

do --- minor2inc_clears_gray_lists
  -- Regression: minor2inc must clear gray/grayagain/weak before entering
  -- sweep phase. Otherwise, traces on grayagain (from lj_gc_barriertrace)
  -- survive sweep while their referenced objects are freed, causing a crash
  -- in gc_traverse_trace during the next incremental mark phase.
  jit.on()
  local oldmode = collectgarbage("generational")
  jit.opt.start("hotloop=1")
  local function hotfunc(n)
    local s = 0
    for i = 1, n do s = s + i end
    return s
  end
  for i = 1, 20 do hotfunc(100) end
  for i = 1, 100 do
    local garbage = {}
    for j = 1, 500 do garbage[j] = {i, j} end
    collectgarbage("step")
  end
  collectgarbage()
  collectgarbage()
  collectgarbage(oldmode)
  jit.off()
end

do --- major_survives_full_cycle
  -- Basic test: trigger minor→major→gen transition and verify data survives.
  local oldmode = collectgarbage("generational", 20, 10)
  local data = {}
  for i = 1, 50 do data[i] = { id = i, val = ("M"):rep(32) } end
  for i = 1, 10 do collectgarbage("step") end
  for i = 1, 100 do
    local _ = {}
    for j = 1, 300 do _[j] = { ("x"):rep(128) } end
    collectgarbage("step")
  end
  for i = 1, 200 do collectgarbage("step") end
  collectgarbage()
  for i = 1, 50 do
    assert(data[i].id == i, "major cycle corrupted data["..i.."]")
  end
  collectgarbage(oldmode)
end

do --- major_finalizer_writes_old_table
  -- Regression: __gc writing to old table during major incremental sweep
  -- must not trigger assertion or corrupt grayagain list.
  local oldmode = collectgarbage("generational", 20, 10)
  local anchor = {}
  for i = 1, 20 do anchor[i] = { id = i } end
  for i = 1, 10 do collectgarbage("step") end
  for w = 1, 3 do
    for i = 1, 15 do
      local u = newproxy(true)
      getmetatable(u).__gc = function()
        anchor[((i - 1) % 20) + 1].gc = w
      end
    end
    for i = 1, 80 do
      local _ = {}
      for j = 1, 200 do _[j] = { ("F"):rep(128) } end
      collectgarbage("step")
    end
    for i = 1, 200 do collectgarbage("step") end
    collectgarbage()
  end
  for i = 1, 20 do
    assert(anchor[i].id == i, "finalizer corrupted anchor["..i.."]")
  end
  collectgarbage(oldmode)
end

do --- major_repeated_transitions
  -- Stress: force multiple minor→major→gen cycles in succession.
  local oldmode = collectgarbage("generational", 20, 10)
  local persistent = { alive = true }
  for cycle = 1, 8 do
    for i = 1, 60 do
      local _ = {}
      for j = 1, 300 do _[j] = { cycle, j, ("R"):rep(64) } end
      collectgarbage("step")
    end
    for i = 1, 200 do collectgarbage("step") end
    collectgarbage()
    assert(persistent.alive, "persistent table lost at cycle "..cycle)
  end
  collectgarbage(oldmode)
end
