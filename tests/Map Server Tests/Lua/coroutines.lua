-- Functions that pause the way global.lua's wait functions do, for the tests to drive.
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

-- These two pause until the server wakes them, then tell the test through the probe.
function sleeper(probe, seconds)
    coroutine.yield("_WAIT_TIME", seconds)
    probe:Mark()
end

function waiter(probe, signal)
    local v = coroutine.yield("_WAIT_SIGNAL", signal)
    probe:Mark()
    return v
end

-- For the lock test: asks the server for something that takes the world's zone lock.
function touchZones(probe)
    probe:TakeZoneLock()
    return true
end
