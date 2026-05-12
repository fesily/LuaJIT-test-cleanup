-- Regression test: gc_finalize sets correct age for resurrected objects.
-- Bug: makewhite without setage(G_NEW) left finalized objects as white+OLD,
-- causing sweepgen to skip them or atomic to mishandle them.

local jit = require"jit"
jit.off()

collectgarbage("generational")

local resurrected = {}

for round = 1, 20 do
  for i = 1, 10 do
    local u = newproxy(true)
    getmetatable(u).__gc = function(self)
      resurrected[#resurrected + 1] = self
    end
  end

  collectgarbage()
  for j = 1, 500 do local _ = { ("x"):rep(64) } end
end

-- Multiple GC cycles to verify resurrected objects survive.
for i = 1, 10 do collectgarbage() end

assert(#resurrected > 0, "no objects were resurrected")

print("OK")
