-- Regression test: lj_gc_finalize_cdata missing setage(G_NEW) in gen-gc.
-- Bug: makewhite(g, o) without setage(G_NEW) leaves cdata as white+OLD
-- after finalizer removal, which violates the gen-gc invariant that OLD
-- objects must be black/gray after atomic.

local jit = require"jit"
local ffi = require"ffi"

jit.off()

collectgarbage("generational")

local cdata_list = {}
for i = 1, 100 do
  local cd = ffi.new("int[10]")
  ffi.gc(cd, function() end)
  cdata_list[i] = cd
end

-- Age to OLD.
for i = 1, 5 do collectgarbage() end

-- Remove finalizers.
for i = 1, 100 do ffi.gc(cdata_list[i], nil) end

-- Force collections.
collectgarbage()
for i = 1, 10000 do local _ = ffi.new("int[10]") end

-- All cdata must still be alive and valid.
for i = 1, 100 do
  assert(cdata_list[i] ~= nil, "cdata "..i.." lost")
end

print("OK")
