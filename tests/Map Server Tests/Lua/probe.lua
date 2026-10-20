-- Conversion and language probes. Each line is "expression = result"; the test compares the
-- lines between engines. Errors print as ERR so engine-specific messages don't differ.

local function collect(cases)
    local out = {}
    for _, c in ipairs(cases) do
        local ok, v = pcall(c[2])
        out[#out + 1] = c[1] .. " = " .. (ok and tostring(v) or "ERR")
    end
    return table.concat(out, "\n")
end

-- C# interop through the Probe object.
function interop(p)
    return collect({
        { "I(2.5)", function() return p:I(2.5) end },
        { "I(-2.7)", function() return p:I(-2.7) end },
        { "I(3e9)", function() return p:I(3e9) end },
        { "I(-3e9)", function() return p:I(-3e9) end },
        { "U(-1)", function() return p:U(-1) end },
        { "U(4294967296)", function() return p:U(4294967296) end },
        { "U(4294967295)", function() return p:U(4294967295) end },
        { "U(2.5)", function() return p:U(2.5) end },
        { "B(300)", function() return p:B(300) end },
        { "B(-1)", function() return p:B(-1) end },
        { "S(40000)", function() return p:S(40000) end },
        { "US(-1)", function() return p:US(-1) end },
        { "F(0.1)", function() return p:F(0.1) end },
        { "D(0.1)", function() return p:Dbl(0.1) end },
        { "E(3)", function() return p:E(3) end },
        { "O(1)", function() return p:O(1) end },
        { "O(1.5)", function() return p:O(1.5) end },
        { "O('x')", function() return p:O("x") end },
        { "O(true)", function() return p:O(true) end },
        { "O(nil)", function() return p:O(nil) end },
        { "Over(1)", function() return p:Over(1) end },
        { "Over('a')", function() return p:Over("a") end },
        { "Quest(int/uint, 5)", function() return p:Quest(5) end },
        { "type(L())", function() return type(p:L()) end },
        { "L().Count", function() return p:L().Count end },
        { "L()[0]", function() return p:L()[0] end },
        { "L()[2]", function() return p:L()[2] end },
        { "L() sum", function() local l, s = p:L(), 0; for i = 0, l.Count - 1 do s = s + l[i] end; return s end },
        { "type(A())", function() return type(p:A()) end },
        { "A().Length", function() return p:A().Length end },
        { "A()[1]", function() return p:A()[1] end },
        { "type(bytes)", function() return type(p.bytes) end },
        { "bytes.Length", function() return p.bytes.Length end },
        { "bytes[0]", function() return p.bytes[0] end },
        { "bytes[3]", function() return p.bytes[3] end },
        { "type(D())", function() return type(p:Dict()) end },
        { "D().Count", function() return p:Dict().Count end },
        { "Objects().Count", function() return p:Objects().Count end },
        { "Objects()[0]:I(4)", function() return p:Objects()[0]:I(4) end },
        { "N() == nil", function() return p:N() == nil end },
        { "RetU()", function() return p:RetU() end },
        { "RetL()", function() return p:RetL() end },
        { "RetB()", function() return p:RetB() end },
        { "type(RetE())", function() return type(p:RetE()) end },
        { "RetE() == RetE()", function() return p:RetE() == p:RetE() end },
        { "Params(1, 2, 3)", function() return p:Params(1, 2, 3) end },
        { "Params()", function() return p:Params() end },
        { "Opt(1)", function() return p:Opt(1) end },
        { "Opt(1, 9)", function() return p:Opt(1, 9) end },
        { "field", function() return p.field end },
        { "set field 7", function() p.field = 7; return p.field end },
        { "Prop", function() return p.Prop end },
        { "set Prop 2.9", function() p.Prop = 2.9; return p.Prop end },
        { "Self() == p", function() return p:Self() == p end },
        { "string arg", function() return p:Str("héllo") end },
        { "string ret len", function() return #p:RetStr() end },
        { "Global()", function() return GetLuaInstance ~= nil end },
    })
end

-- Pure Lua: arithmetic, strings and libraries. MoonSharp departs from Lua in places; the test
-- lists those lines and expects Lua's answer from LuaJIT.
function language()
    return collect({
        { "7 % -3", function() return 7 % -3 end },
        { "-7 % 3", function() return -7 % 3 end },
        { "-7.5 % 2", function() return -7.5 % 2 end },
        { "math.fmod(-7, 3)", function() return math.fmod(-7, 3) end },
        { "10 / 3", function() return 10 / 3 end },
        { "2^53", function() return 2 ^ 53 end },
        { "1e15", function() return 1e15 end },
        { "1e16", function() return 1e16 end },
        { "123456789012", function() return 123456789012 end },
        { "0.1 + 0.2", function() return 0.1 + 0.2 end },
        { "1/0", function() return 1 / 0 end },
        { "-1/0", function() return -1 / 0 end },
        { "-0.0", function() return -0.0 end },
        { "0/0 ~= 0/0", function() return (0 / 0) ~= (0 / 0) end },
        { "math.floor(-3.5)", function() return math.floor(-3.5) end },
        { "math.ceil(-3.5)", function() return math.ceil(-3.5) end },
        { "math.abs(-2)", function() return math.abs(-2) end },
        { "math.max(1, 5, 3)", function() return math.max(1, 5, 3) end },
        { "math.sqrt(2)", function() return math.sqrt(2) end },
        { "math.pi", function() return math.pi end },
        { "math.atan2(1, -1)", function() return math.atan2(1, -1) end },
        { "math.pow(2, 10)", function() return math.pow(2, 10) end },
        { "math.log(8, 2)", function() return math.log(8, 2) end },
        { "math.log10(1000)", function() return math.log10(1000) end },
        { "tonumber('0x10')", function() return tonumber("0x10") end },
        { "tonumber(' 12 ')", function() return tonumber(" 12 ") end },
        { "tonumber('1e2')", function() return tonumber("1e2") end },
        { "tonumber('z', 36)", function() return tonumber("z", 36) end },
        { "'10' + 5", function() return "10" + 5 end },
        { "10 .. ''", function() return 10 .. "" end },
        { "1.5 .. ''", function() return 1.5 .. "" end },
        { "%d 3.7", function() return string.format("%d", 3.7) end },
        { "%d -3.7", function() return string.format("%d", -3.7) end },
        { "%.2f 2.675", function() return string.format("%.2f", 2.675) end },
        { "%5.1f", function() return string.format("%5.1f", 3.14159) end },
        { "%x 255", function() return string.format("%x", 255) end },
        { "%X 0x80000000", function() return string.format("%X", 0x80000000) end },
        { "%s nil", function() return string.format("%s", nil) end },
        { "%q", function() return string.format("%q", 'a"b\n') end },
        { "%g 0.1", function() return string.format("%g", 0.1) end },
        { "#'abc'", function() return #"abc" end },
        { "#'é'", function() return #"é" end },
        { "upper('é')", function() return string.upper("aé") end },
        { "sub(2, -2)", function() return ("hello"):sub(2, -2) end },
        { "find plain", function() return ("a.b"):find(".", 1, true) end },
        { "gsub count", function() return select(2, ("aaa"):gsub("a", "b")) end },
        { "match %d+", function() return ("ab12cd"):match("%d+") end },
        { "rep", function() return ("ab"):rep(3) end },
        { "byte", function() return ("A"):byte() end },
        { "char", function() return string.char(72, 105) end },
        { "select('#')", function() return select("#", nil, nil) end },
        { "unpack", function() return select("#", unpack({ 1, 2, nil, 4 }, 1, 4)) end },
        { "#{1,2,3}", function() return #{ 1, 2, 3 } end },
        { "concat", function() return table.concat({ 1, 2, 3 }, ",") end },
        { "insert/remove", function() local t = { 1, 2 }; table.insert(t, 1, 0); table.remove(t); return table.concat(t, ",") end },
        { "sort", function() local t = { 3, 1, 2 }; table.sort(t); return table.concat(t, ",") end },
        { "sort desc", function() local t = { 3, 1, 2 }; table.sort(t, function(a, b) return a > b end); return table.concat(t, ",") end },
        { "tostring(true)", function() return tostring(true) end },
        { "tostring(nil)", function() return tostring(nil) end },
        { "type(print)", function() return type(print) end },
        { "type(os.time())", function() return type(os.time()) end },
        { "type(os.clock())", function() return type(os.clock()) end },
        { "bit.band", function() return bit.band(0xF0F0, 0x0FF0) end },
        { "bit.bor", function() return bit.bor(0x0B000000, 0x8000, 0x80) end },
        { "bit.lshift(1, 4)", function() return bit.lshift(1, 4) end },
        { "bit.lshift(1, 31) % 2^32", function() return bit.lshift(1, 31) % 0x100000000 end },
        { "bit.band(0xFFFFFFFF, 0xA0F00000) % 2^32", function() return bit.band(0xFFFFFFFF, 0xA0F00000) % 0x100000000 end },
        { "goto", function() local n = 0; ::top:: n = n + 1; if n < 3 then goto top end; return n end },
        { "varargs", function() local function f(...) return select("#", ...) end; return f(1, nil, 3) end },
        { "closure", function() local c = 0; local function inc() c = c + 1; return c end; inc(); return inc() end },
        { "pcall error value", function() local ok, e = pcall(error, { code = 5 }); return e.code end },
        { "string methods on literal", function() return ("%d"):format(5) end },
    })
end

-- Iteration order of pairs() over a hash table is unspecified in Lua and differs between engines.
function pairsOrder()
    local t = { alpha = 1, beta = 2, gamma = 3, delta = 4, epsilon = 5 }
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    return table.concat(keys, ",")
end
