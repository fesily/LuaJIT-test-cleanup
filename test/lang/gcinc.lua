local jit = require"jit"

jit.off()

do --- mode_switching
  assert(collectgarbage("isrunning"))
  collectgarbage()
  local oldmode = collectgarbage("incremental")
  assert(collectgarbage("generational") == "incremental")
  assert(collectgarbage("generational") == "generational")
  assert(collectgarbage("incremental") == "generational")
  assert(collectgarbage("incremental") == "incremental")
  collectgarbage(oldmode)
end

do --- step_size
  local function gcinfo()
    return collectgarbage("count") * 1024
  end

  local function dosteps(stepsize)
    collectgarbage()
    local objects = {}
    for i = 1, 100 do
      objects[i] = {{}}
      local scratch = {}
    end
    local before = gcinfo()
    local steps = 0
    repeat
      steps = steps + 1
    until collectgarbage("step", stepsize)
    assert(gcinfo() < before)
    return steps
  end

  local oldmode = collectgarbage("incremental")
  collectgarbage("stop")
  assert(dosteps(10) < dosteps(2))
  collectgarbage("restart")
  assert(collectgarbage("isrunning"))
  collectgarbage(oldmode)
end

do --- gc_stopped_alloc
  local function gcinfo()
    return collectgarbage("count") * 1024
  end

  local oldmode = collectgarbage("incremental")
  collectgarbage()
  collectgarbage("stop")
  collectgarbage("step")
  local before = gcinfo()
  local holder = {}
  repeat
    for i = 1, 1000 do
      holder[#holder + 1] = {}
    end
  until gcinfo() > 2 * before
  collectgarbage("restart")
  collectgarbage(oldmode)
end

do --- weak_table_collection
  local oldmode = collectgarbage("incremental")
  local weak = setmetatable({}, {__mode = "kv"})
  local key, value = {}, {}
  weak[key] = value
  key = nil
  value = nil
  collectgarbage()
  assert(next(weak) == nil)
  collectgarbage(oldmode)
end
