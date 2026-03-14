local oldmode = collectgarbage("incremental", 70000, 80000)

local oldpause = collectgarbage("setpause", 200)
local oldstepmul = collectgarbage("setstepmul", 200)

assert(oldpause == 70000, string.format("pause mismatch: got %d", oldpause))
assert(oldstepmul == 80000, string.format("stepmul mismatch: got %d", oldstepmul))
assert(oldmode == "incremental" or oldmode == "generational")

print("OK")