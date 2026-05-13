-- Regression test: lj_gc_barrieruv() missing age promotion in gen-gc mode.
--
-- Bug: storing a NEW value into an OLD closed upvalue via lj_gc_barrieruv
-- marks the value but doesn't age-promote it. The value gets swept in a
-- subsequent young collection → use-after-free / segfault.
--
-- Expected: PASS with fix, segfault/FAIL without fix.

if not pcall(collectgarbage, "generational") then
  print("SKIP: no gen-gc support")
  os.exit(0)
end

jit.off()
io.stdout:setvbuf("line")
io.stderr:setvbuf("line")

local function make_pair()
  local v
  return function() return v end, function(x) v = x end
end

local N = 10
local anchor = {}
for i = 1, N do
  local g, s = make_pair()
  anchor[i] = { get = g, set = s }
end

collectgarbage("collect")
debug.getregistry().__test = anchor
anchor = nil
collectgarbage("collect")

local reg = debug.getregistry()

for round = 1, 100 do
  -- Set NEW values via dead coroutine (no stack refs after)
  local co = coroutine.create(function()
    local a = reg.__test
    for i = 1, N do
      a[i].set({ id = i, round = round })
    end
  end)
  coroutine.resume(co)
  co = nil

  -- Trigger young GC cycles via allocation pressure
  for wave = 1, 5 do
    for j = 1, 1000 do
      local _ = { string.rep("x", 64) }
    end
  end

  -- Verify
  local a = reg.__test
  for i = 1, N do
    local got = a[i].get()
    if type(got) ~= "table" or got.id ~= i or got.round ~= round then
      io.stderr:write(string.format(
        "FAIL round %d, slot %d: got %s\n", round, i, tostring(got)))
      debug.getregistry().__test = nil
      os.exit(1)
    end
  end
end

debug.getregistry().__test = nil
print("PASS: gengc_barrieruv")
