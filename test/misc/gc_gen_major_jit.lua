-- Test: JIT traces surviving major collection (KGC_GENMAJOR).
-- Compiled traces must not be corrupted when the GC transitions through
-- minor→major→gen. Trace protos must be kept alive by gc_marktraceprotos.
-- Covers: gc_marktraceprotos, barriertrace == KGC_GEN, trace age G_NEW.

local jit = require"jit"

-- Test 1: Existing traces survive major collection.
do
  jit.on()
  local oldmode = collectgarbage("generational", 20, 10)
  jit.opt.start("hotloop=1")

  local function hotloop(n)
    local s = 0
    for i = 1, n do s = s + i end
    return s
  end

  -- Compile the trace.
  for i = 1, 10 do hotloop(100) end

  -- Force major collection via heavy allocation.
  for round = 1, 50 do
    local garbage = {}
    for j = 1, 500 do garbage[j] = { round, j } end
    collectgarbage("step")
  end

  -- Complete major.
  for i = 1, 200 do collectgarbage("step") end
  collectgarbage()

  -- Verify trace still works after major→gen transition.
  local result = hotloop(100)
  assert(result == 5050, "trace result wrong after major: "..tostring(result))

  collectgarbage(oldmode)
  jit.off()
end

-- Test 2: Traces compiled during heavy allocation + major transition.
do
  jit.on()
  local oldmode = collectgarbage("generational", 20, 10)
  jit.opt.start("hotloop=1")

  local results = {}
  for round = 1, 30 do
    local function compute(n)
      local s = 0
      for i = 1, n do s = s + i end
      return s
    end
    results[round] = compute(50)
    -- Allocate between compilations to push toward major.
    for j = 1, 200 do local _ = { round, j, ("T"):rep(64) } end
    collectgarbage("step")
  end

  -- Complete any pending major.
  for i = 1, 300 do collectgarbage("step") end
  collectgarbage()

  for round = 1, 30 do
    assert(results[round] == 1275,
           "round "..round.." result wrong: "..tostring(results[round]))
  end

  collectgarbage(oldmode)
  jit.off()
end

-- Test 3: loadstring traces + major (proto lifetime test).
do
  jit.on()
  local oldmode = collectgarbage("generational", 20, 10)
  jit.opt.start("hotloop=1")

  -- Compile traces from loadstring (protos are ephemeral).
  for j = 1, 30 do
    loadstring("for i=1,100 do end")()
  end

  -- Heavy allocation to trigger major.
  for k = 1, 30 do
    local garbage = {}
    for i = 1, 500 do garbage[i] = { k, i } end
    collectgarbage("step")
  end

  -- Complete major.
  for i = 1, 200 do collectgarbage("step") end
  collectgarbage()
  collectgarbage()

  -- Run more traces after major to ensure GC state is clean.
  local sum = 0
  local function post_major(n)
    local s = 0
    for i = 1, n do s = s + i end
    return s
  end
  for i = 1, 10 do sum = sum + post_major(10) end
  assert(sum == 550, "post-major trace result wrong: "..tostring(sum))

  collectgarbage(oldmode)
  jit.off()
end

print("OK")
