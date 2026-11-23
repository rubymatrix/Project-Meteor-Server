-- Rolls for DiceTests.

function unitRolls(n)
    local out = {}
    for i = 1, n do out[i] = math.random() end
    return unpack(out)
end

function rangedRolls(lo, hi, n)
    local out = {}
    for i = 1, n do out[i] = math.random(lo, hi) end
    return unpack(out)
end

function reseed()
    math.randomseed(12345)
    return math.random()
end
