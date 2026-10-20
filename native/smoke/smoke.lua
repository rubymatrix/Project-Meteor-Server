-- Run by smoke.c. If any check fails, the test fails.

print(jit.version, jit.arch, jit.os)
print("jit.status:", jit.status())
assert(jit.status(), "JIT is off")

-- LuaJIT must be built in 64-bit memory mode (GC64), which xlua.c expects.
local ffi = require("ffi")
assert(ffi.abi("64bit"), "not a 64-bit build")
assert(ffi.abi("gc64"), "not a GC64 build")

-- Bit operations
assert(bit.band(0xff, 0x0f) == 0x0f)
assert(bit.bor(0xf0, 0x0f) == 0xff)
assert(bit.bxor(0xff, 0x0f) == 0xf0)
assert(bit.lshift(1, 10) == 1024)
assert(bit.tohex(255) == "000000ff")

-- goto, which some scripts use to skip ahead in a loop
local odd = 0
for i = 1, 10 do
  if i % 2 == 0 then goto continue end
  odd = odd + 1
  ::continue::
end
assert(odd == 5, "goto")

-- Pausing and resuming a function, with values passed both ways
local co = coroutine.create(function(a)
  local b = coroutine.yield(a + 1)
  local c = coroutine.yield(b * 2)
  return c .. "!"
end)
local ok, v = coroutine.resume(co, 1);   assert(ok and v == 2)
ok, v = coroutine.resume(co, 5);         assert(ok and v == 10)
ok, v = coroutine.resume(co, "done");    assert(ok and v == "done!")
assert(coroutine.status(co) == "dead")

-- A busy loop gets compiled to machine code (LuaJIT's JIT is working)
local traces = 0
jit.attach(function(what) if what == "stop" then traces = traces + 1 end end, "trace")
local sum = 0
for i = 1, 1000000 do sum = sum + bit.band(i, 7) end
jit.attach(function() end)
assert(sum == 3500000, "loop result")
assert(traces > 0, "no trace compiled")
print("traces compiled:", traces)

-- xLua's own functions and its 64-bit integers
assert(type(xlua) == "table" and type(xlua.genaccessor) == "function", "xlua lib")
assert(tostring(big + big) == "2199023255552", "int64: " .. tostring(big + big))

print("all checks passed")
