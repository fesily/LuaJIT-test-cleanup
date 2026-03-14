local jit = require"jit"
local jutil = require"jit.util"

jit.opt.start("hotloop=1", "hotexit=1")

collectgarbage()
collectgarbage("generational")

local function trace_ids(limit)
  local ids = {}
  for tr = 1, limit do
    if jutil.traceinfo(tr) then
      ids[#ids+1] = tr
    end
  end
  return ids
end

local function assert_traces_alive(ids)
  for i = 1, #ids do
    assert(jutil.traceinfo(ids[i]), ids[i])
  end
end

local function make_root_chain(n)
  local sum = 0
  for i = 1, n do
    sum = sum + i
  end
  for i = 1, n do
    sum = sum - i
  end
  return sum
end

local function make_side_trace(n, side)
  local sum = 0
  for i = 1, n do
    if side and i > 2 then
      sum = sum + i
    else
      sum = sum + 1
    end
  end
  return sum
end

local function octal(s)
  return tonumber(s, 8)
end

for _ = 1, 4 do
  assert(make_root_chain(6) == 0)
end

local ids_after_roots = trace_ids(16)
assert(#ids_after_roots >= 2, #ids_after_roots)

for _ = 1, 4 do
  make_side_trace(6, false)
end
for _ = 1, 4 do
  make_side_trace(6, true)
end

local ids_after_side = trace_ids(24)
assert(#ids_after_side >= #ids_after_roots + 1, #ids_after_side)

for _ = 1, 6 do
  octal("1")
  octal("1")
  octal("1")
end

local ids = trace_ids(32)
assert(#ids >= #ids_after_side + 1, #ids)

local saw_stitch = false
for i = 1, #ids do
  local info = jutil.traceinfo(ids[i])
  if info.linktype == "stitch" then
    saw_stitch = true
    break
  end
end
assert(saw_stitch, "missing stitched trace")

for _ = 1, 80 do
  local tmp = {}
  for i = 1, 32 do
    tmp[i] = {i}
  end
  collectgarbage("step")
end

assert_traces_alive(ids)

for _ = 1, 3 do
  assert(make_root_chain(6) == 0)
  make_side_trace(6, false)
  make_side_trace(6, true)
  assert(octal("10") == 8)
end

assert_traces_alive(ids)
print("OK")