-- Work for EngineBenchmarks to time. Each function returns a result so the test can check both
-- engines got the same answer.
function pureLua(n)
    local acc = 0
    for i = 1, n do
        local x = (i * 1.37) % 97
        acc = acc + math.floor(x * x) % 13
    end
    return acc
end

function interop(p, n)
    local acc = 0
    for i = 1, n do
        acc = acc + p:Opt(i, 1)
    end
    return acc
end

function tables(n)
    local t = {}
    for i = 1, n do t[#t + 1] = { id = i, name = "x" .. (i % 10) } end
    local c = 0
    for _, v in ipairs(t) do if v.name == "x3" then c = c + v.id end end
    return c
end

function yielder()
    coroutine.yield("_WAIT_TIME", 0)
    return 1
end

function jitStatus()
    if jit then return tostring(jit.version) .. " " .. tostring((jit.status())) .. " " .. jit.arch end
    return "no jit"
end
