-- The yield protocol global.lua uses for waits, driven by the tests instead of LuaEngine.
function flow(a, b)
    local r1 = coroutine.yield("_WAIT_TIME", 0.25)
    local r2, r3 = coroutine.yield("_WAIT_SIGNAL", "go")
    local r4 = coroutine.yield("_WAIT_EVENT", a)
    return "done", b, r1, r2, r3, r4
end

function boom()
    local x = nil
    return x.y
end

function boomAfterYield()
    coroutine.yield("_WAIT_TIME", 0)
    error("late failure")
end

-- For LuaEngine's timer: waits, then reports back through the probe.
function sleeper(probe, seconds)
    coroutine.yield("_WAIT_TIME", seconds)
    probe:Mark()
end

function waiter(probe, signal)
    local v = coroutine.yield("_WAIT_SIGNAL", signal)
    probe:Mark()
    return v
end
