-- Test: finalizers running during KGC_GENMAJOR incremental sweep.
-- Finalizers that write to OLD tables (barrierback) and create new objects
-- (barrierf) must work correctly during the major collection phase.
-- Covers: gc_finalize age reset, barrierback assertion, barrier != KGC_INC.

local jit = require"jit"
jit.off()

local oldmode = collectgarbage("generational", 20, 10)

-- Create tables and age them to OLD.
local containers = {}
for i = 1, 30 do containers[i] = { id = i } end
for i = 1, 10 do collectgarbage("step") end

-- Create finalizable udata that writes into OLD tables (triggers barrierback).
for wave = 1, 5 do
  for i = 1, 20 do
    local u = newproxy(true)
    local idx = ((wave - 1) * 4 + (i % 30)) + 1
    if idx > 30 then idx = (idx % 30) + 1 end
    getmetatable(u).__gc = function()
      containers[idx].gc_wave = wave
      containers[idx].gc_data = { finalized = true, wave = wave }
    end
  end
end

-- Heavy allocation to force major collection.
for i = 1, 100 do
  local _ = {}
  for j = 1, 200 do _[j] = { i, j, ("F"):rep(128) } end
  collectgarbage("step")
end

-- Run enough steps to complete major and finalization.
for i = 1, 300 do collectgarbage("step") end
collectgarbage()
collectgarbage()

-- Verify containers survived and finalizer writes are intact.
for i = 1, 30 do
  assert(type(containers[i]) == "table", "container "..i.." not a table")
  assert(containers[i].id == i, "container "..i.." id corrupted")
end

-- Test resurrection: finalizers that keep a reference to the dying object.
local resurrected = {}
for i = 1, 20 do
  local u = newproxy(true)
  getmetatable(u).__gc = function(self)
    resurrected[#resurrected + 1] = self
  end
end

-- Force major again.
for i = 1, 100 do
  local _ = {}
  for j = 1, 200 do _[j] = { ("R"):rep(128) } end
  collectgarbage("step")
end
for i = 1, 300 do collectgarbage("step") end
collectgarbage()
collectgarbage()

assert(#resurrected > 0, "no objects were resurrected during major")

-- Verify resurrected objects survive subsequent collections.
for i = 1, 10 do collectgarbage() end
for i = 1, #resurrected do
  assert(type(resurrected[i]) == "userdata", "resurrected object corrupted")
end

collectgarbage(oldmode)
print("OK")
