-- Run by smoke.c. Any failed assert fails the test.

print(jit.version, jit.arch, jit.os)
print("jit.status:", jit.status())
assert(jit.status(), "JIT is off")

-- 64-bit object references; xlua.c reads LuaJIT internals laid out for GC64.
local ffi = require("ffi")
assert(ffi.abi("64bit"), "not a 64-bit build")
assert(ffi.abi("gc64"), "not a GC64 build")

-- bit library
assert(bit.band(0xff, 0x0f) == 0x0f)
assert(bit.bor(0xf0, 0x0f) == 0xff)
assert(bit.bxor(0xff, 0x0f) == 0xf0)
assert(bit.lshift(1, 10) == 1024)
assert(bit.tohex(255) == "000000ff")

-- goto (Lua 5.2 syntax LuaJIT accepts; the old scripts use it as `continue`)
local odd = 0
for i = 1, 10 do
  if i % 2 == 0 then goto continue end
  odd = odd + 1
  ::continue::
end
assert(odd == 5, "goto")

-- coroutines yield and resume, values in both directions
local co = coroutine.create(function(a)
  local b = coroutine.yield(a + 1)
  local c = coroutine.yield(b * 2)
  return c .. "!"
end)
local ok, v = coroutine.resume(co, 1);   assert(ok and v == 2)
ok, v = coroutine.resume(co, 5);         assert(ok and v == 10)
ok, v = coroutine.resume(co, "done");    assert(ok and v == "done!")
assert(coroutine.status(co) == "dead")

-- a hot loop gets compiled to a trace
local traces = 0
jit.attach(function(what) if what == "stop" then traces = traces + 1 end end, "trace")
local sum = 0
for i = 1, 1000000 do sum = sum + bit.band(i, 7) end
jit.attach(function() end)
assert(sum == 3500000, "loop result")
assert(traces > 0, "no trace compiled")
print("traces compiled:", traces)

-- xLua's own library and 64-bit integers (luaopen_xlua, luaopen_i64lib)
assert(type(xlua) == "table" and type(xlua.genaccessor) == "function", "xlua lib")
assert(tostring(big + big) == "2199023255552", "int64: " .. tostring(big + big))

print("all checks passed")
