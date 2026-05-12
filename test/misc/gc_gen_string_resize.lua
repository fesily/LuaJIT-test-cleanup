-- Regression test: string table resize during gen-gc finalization.
-- A finalizer that triggers collectgarbage() may cause lj_str_resize
-- via the incremental sweep path inside entergen. New strings created
-- during finalization must survive.

local jit = require"jit"
jit.off()

collectgarbage("generational")

local strings = {}
for i = 1, 10000 do
  strings[i] = string.format("unique_%05d_%s", i, ("x"):rep(20))
end
for i = 1, 5 do collectgarbage() end

local new_strings = {}
local created = false
do
  local u = newproxy(true)
  getmetatable(u).__gc = function()
    if created then return end
    created = true
    for i = 1, 100 do
      new_strings[i] = string.format("fin_%05d_%s", i, ("F"):rep(30))
    end
    collectgarbage()
    for i = 101, 200 do
      new_strings[i] = string.format("post_%05d_%s", i, ("P"):rep(30))
    end
  end
end

-- Drop half the strings to encourage shrink.
for i = 1, 5000 do strings[i] = nil end

collectgarbage()

for round = 1, 10 do collectgarbage() end

-- Verify.
local alive = 0
for i = 1, 200 do
  if new_strings[i] and type(new_strings[i]) == "string" then
    alive = alive + 1
  end
end
assert(alive >= 100, "strings lost: only "..alive.."/200 alive")

for i = 5001, 10000 do
  assert(strings[i] and type(strings[i]) == "string", "old string "..i.." lost")
end

print("OK")
