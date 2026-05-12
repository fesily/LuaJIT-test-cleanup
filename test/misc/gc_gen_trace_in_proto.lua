-- Regression test: gc_traverse_proto must call gc_marktrace in gen GC mode.
--
-- Bug: gc_traverse_proto guarded gc_marktrace with (kind == KGC_INC),
-- skipping it entirely during generational young collections. This means
-- gc_traverse_trace never runs for the trace, so:
--   1. IR_KGC constants (strings/protos) in the trace are not marked
--   2. Linked traces (side exits) are not marked through the chain
--
-- Traces themselves survive as OLD+BLACK (set by lj_gc_barriertrace),
-- but their children may not. In practice most IR_KGC objects are also
-- reachable via proto constants, so the bug is hard to trigger as a crash.
-- This test exercises the path and verifies trace integrity after heavy
-- gen GC pressure, serving as a regression guard for the fix.

local jutil = require("jit.util")

-- Must be in generational mode.
collectgarbage("generational")

-- Create multiple functions that will each get their own trace.
-- Side traces create linked trace chains that gc_traverse_trace must walk.
local function make_worker(id)
  return function(t)
    local sum = 0
    for i = 1, 100 do
      -- Branch to create side traces.
      if t.mode == 1 then
        sum = sum + i * id
      elseif t.mode == 2 then
        sum = sum + i + id
      else
        sum = sum - i
      end
    end
    return sum
  end
end

-- Compile traces for several workers.
jit.opt.start("hotloop=3", "hotexit=3")
local workers = {}
for i = 1, 8 do
  workers[i] = make_worker(i)
end

-- Warm up: compile root + side traces.
local ctrl = { mode = 1 }
for _ = 1, 30 do
  for _, w in ipairs(workers) do w(ctrl) end
end
ctrl.mode = 2
for _ = 1, 30 do
  for _, w in ipairs(workers) do w(ctrl) end
end
ctrl.mode = 3
for _ = 1, 30 do
  for _, w in ipairs(workers) do w(ctrl) end
end

-- Record which traces exist.
local trace_ids = {}
for i = 1, 1000 do
  if jutil.traceinfo(i) then
    trace_ids[#trace_ids + 1] = i
  end
end
assert(#trace_ids > 0, "no traces compiled")

-- Heavy gen GC pressure: allocate lots of garbage, force young collections.
-- This ages objects and exercises the mark/sweep cycle many times.
for round = 1, 80 do
  local garbage = {}
  for i = 1, 5000 do
    garbage[i] = { tostring(i), { i } }
  end
  garbage = nil
  collectgarbage("collect")
  collectgarbage("collect")
end

-- Verify all traces survived.
local survived = 0
for _, id in ipairs(trace_ids) do
  if jutil.traceinfo(id) then
    survived = survived + 1
  end
end
assert(survived == #trace_ids,
  string.format("traces lost: %d/%d survived", survived, #trace_ids))

-- Execute through all code paths — must produce correct results,
-- not crash from stale IR_KGC references.
for _, mode in ipairs({1, 2, 3}) do
  ctrl.mode = mode
  for _, w in ipairs(workers) do
    local r = w(ctrl)
    assert(type(r) == "number", "bad result after GC")
  end
end

-- One more GC + execute cycle.
collectgarbage("collect")
collectgarbage("collect")
for _, w in ipairs(workers) do
  assert(type(w(ctrl)) == "number")
end

print("OK")
