-- Regression test: lj_gc_barrieruv() in gen-gc mode during GCSfinalize.
-- Bug: storing a NEW value into an OLD closed upvalue via barrieruv's
-- else branch sets curwhite without marking the value. The value gets
-- swept in a subsequent young collection -> use-after-free / segfault.

local jit = require"jit"
jit.off()

collectgarbage("generational")

local N = 10
local getters = {}
local setters = {}

for i = 1, N do
  local v
  getters[i] = function() return v end
  setters[i] = function(x) v = x end
end

-- Age closures + upvalues to OLD.
for i = 1, N do setters[i]({ id = i, data = ("O"):rep(128) }) end
for i = 1, 5 do collectgarbage() end
for i = 1, N do assert(getters[i]().id == i) end

-- Finalizer overwrites all upvalues during GCSfinalize.
local triggered = false
do
  local u = newproxy(true)
  getmetatable(u).__gc = function()
    if triggered then return end
    triggered = true
    for i = 1, N do
      setters[i]({ id = i, data = ("N"):rep(128) })
    end
  end
end

collectgarbage()

-- Force young collection to sweep the unmarked NEW values.
for i = 1, 5000 do local _ = { ("x"):rep(128) } end
collectgarbage()

-- Fill freed memory with poison data.
for i = 1, 5000 do local _ = { id = -1, data = ("P"):rep(128) } end

-- Read upvalues – must still return the values set by the finalizer.
for i = 1, N do
  local v = getters[i]()
  assert(type(v) == "table" and v.id == i,
         "slot "..i..": expected id="..i..", got "..tostring(v and v.id))
end

print("OK")
