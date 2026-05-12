-- Regression test: lj_gc_barrierf during GCSfinalize in gen-gc mode.
-- Bug: the else branch of barrierf did makewhite(g, o) which creates
-- white+OLD objects that sweepgen frees while still referenced.

local jit = require"jit"
jit.off()

collectgarbage("generational")

-- Create a proto with upvalues stored via barrierf (non-table parent).
local results = {}
for i = 1, 20 do
  local fn = loadstring("return function() return "..i.." end")()
  results[i] = fn
end

-- Age to OLD.
for i = 1, 5 do collectgarbage() end

-- Verify.
for i = 1, 20 do assert(results[i]() == i) end

-- Finalizer creates new protos/functions referencing OLD objects.
local new_funcs = {}
do
  local u = newproxy(true)
  getmetatable(u).__gc = function()
    for i = 1, 20 do
      new_funcs[i] = loadstring("return function() return "..tostring(100+i).." end")()
    end
  end
end

collectgarbage()

for round = 1, 20 do
  for j = 1, 500 do local _ = { ("x"):rep(64) } end
  collectgarbage()
end

-- Verify original and new functions.
for i = 1, 20 do
  assert(results[i]() == i, "original func "..i.." broken")
end
for i = 1, 20 do
  if new_funcs[i] then
    assert(new_funcs[i]() == 100 + i, "new func "..i.." broken")
  end
end

print("OK")
