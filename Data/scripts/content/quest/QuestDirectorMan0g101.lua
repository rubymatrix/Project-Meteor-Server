--[[
Man0g1 escort (director QuestDirectorMan0g101): walk Powle and Sansa to the stump in the
Central Shroud while ankle biters ambush the party. Lost if either child falls or time runs out;
won when the player reaches the stump with no foe close by.
--]]

local Escort = Encounter.define("QuestDirectorMan0g101")

local POOL_POWLE, POOL_SANSA, POOL_ANKLE_BITER = 9290009, 9290010, 9205603
local ESCORT_LEVEL = 5
local TIME_LIMIT = 1800
local HOLD_RADIUS = 28
local ARRIVAL_RADIUS, NEAR_GOAL_RADIUS = 20, 40
local MARCH_LINE_SECONDS, HURT_LINE_SECONDS = 20, 5
local STUMP = { -756.77, 0, -1092.33 }
local MOD_MINIMUM_HP_LOCK = 114

local POWLE_DISPLAY_ID, ANKLE_BITER_DISPLAY_ID = 1000029, 3205603
local TEXT_PROTECT_FROM_HARM, TEXT_TIME_MINUTES = 51005, 25018
local TEXT_MOB_ENGAGED, TEXT_MOB_DEFEATED = 30120, 30121
local TEXT_DUTY_START, TEXT_AMBUSH, TEXT_WAVE_CLEAR, TEXT_MARCH_RESUME = 362, 363, 364, 365
local TEXT_TRIP_FUN, TEXT_WAVE_THANKS = 366, 367
local TEXT_KID_HURT_YELP, TEXT_KID_HURT_GRIPE = 370, 371
local TEXT_NEAR_GOAL, TEXT_ARRIVAL_THANKS, TEXT_STUMP_IN_SIGHT = 373, 374, 177

local POWLE_START = { -197.7, 3.54, -1023.3, -1.642 }
local SANSA_START = { -191.7, 3.54, -1023.3, -1.642 }
local ANKLE_BITERS = {
    { -183.06, 3.25, -884.72 }, { -255.57, 4.12, -832.77 }, { -376.15, 4.41, -886.16 },
    { -507.36, 6.92, -902.53 }, { -619.96, 3.60, -954.60 }, { -634.94, 21.94, -1070.57 },
}

local function flat(a, x, z)
    local p = a:pos()
    return math.sqrt((p.x - x) ^ 2 + (p.z - z) ^ 2)
end

function Escort:setup(opts)
    self.quest = opts.quest
    self.player = self:participants()[1]
    self:timeLimit(TIME_LIMIT)
    local powle = self:spawn("escorts", { pool = POOL_POWLE, kind = "ally", level = ESCORT_LEVEL, at = POWLE_START,
        profile = "content/profiles/EscortedChild", override = { bb = { leader = self.player } } })
    self:spawn("escorts", { pool = POOL_SANSA, kind = "ally", level = ESCORT_LEVEL, at = SANSA_START,
        profile = "content/profiles/EscortedChild", override = { bb = { leader = powle or self.player }, behaviors = { Follow = { gap = 6 } } } })
    self.powle = powle
    for _, b in ipairs(ANKLE_BITERS) do
        self:spawn("biters", { pool = POOL_ANKLE_BITER, level = self:int(5, 7), at = b })
    end
    self:objective("escorts", Objective.protect("escorts", 2), { fails = true })
    self:objective("stump", Objective.custom(function() return self:arrived() end), { wins = true })
    if self.player then self.player.cs:SetMod(MOD_MINIMUM_HP_LOCK, 1) end
end

function Escort:say(textId)
    if self.quest then self:tell(self.quest, textId) end
end

function Escort:foesNear()
    local n = 0
    for _, mob in ipairs(self:group("biters"):list()) do
        if mob:isAlive() and (mob:distance(self.player) <= HOLD_RADIUS or (self.powle and mob:distance(self.powle) <= HOLD_RADIUS)) then
            n = n + 1
        end
    end
    return n
end

function Escort:arrived()
    return self.player ~= nil and self:foesNear() == 0 and flat(self.player, STUMP[1], STUMP[3]) <= ARRIVAL_RADIUS
end

function Escort:onStart()
    local p = self.player
    if p then
        p.cs:SendGameMessage(GetWorldMaster(), TEXT_PROTECT_FROM_HARM, 0x20, POWLE_DISPLAY_ID)
        p.cs:SendGameMessage(GetWorldMaster(), TEXT_TIME_MINUTES, 0x20, TIME_LIMIT / 60)
    end
    self:say(TEXT_DUTY_START)

    -- Banter while marching: a line after each ambush is cleared and every so often on the road.
    local lastNear, lastMarch, saidNearGoal, tick = 0, 0, false, 0
    self:every(1, function()
        tick = tick + 1
        local near = self:foesNear()
        if near == 0 and lastNear > 0 then
            self:say(TEXT_WAVE_CLEAR)
            self:say(TEXT_MARCH_RESUME)
            lastMarch = tick
        end
        lastNear = near
        if near == 0 and p then
            local toStump = flat(p, STUMP[1], STUMP[3])
            if toStump <= ARRIVAL_RADIUS then
                return false
            elseif not saidNearGoal and toStump <= NEAR_GOAL_RADIUS then
                saidNearGoal = true
                self:say(TEXT_NEAR_GOAL)
            elseif tick - lastMarch >= MARCH_LINE_SECONDS then
                lastMarch = tick
                self:say(tick % 3 == 0 and TEXT_WAVE_THANKS or TEXT_TRIP_FUN)
            end
        end
    end)

    self:on("Engaged", { group = "biters" }, function(_, ev)
        if self.player then
            self.player.cs:SendGameMessageLocalizedDisplayName(GetWorldMaster(), TEXT_MOB_ENGAGED, 0x20, ANKLE_BITER_DISPLAY_ID)
        end
        self:say(TEXT_AMBUSH)
    end)
    self:on("Died", { group = "biters" }, function()
        if self.player then
            self.player.cs:SendGameMessageLocalizedDisplayName(GetWorldMaster(), TEXT_MOB_DEFEATED, 0x20, ANKLE_BITER_DISPLAY_ID)
        end
    end)
    local lastHurt = -HURT_LINE_SECONDS
    self:on("Damaged", { group = "escorts" }, function()
        local now = self:elapsed()
        if now - lastHurt >= HURT_LINE_SECONDS then
            lastHurt = now
            self:say(math.floor(now) % 2 == 0 and TEXT_KID_HURT_YELP or TEXT_KID_HURT_GRIPE)
        end
    end)
end

function Escort:onEnd(result)
    if result == "win" then
        self:say(TEXT_ARRIVAL_THANKS)
        self:say(TEXT_STUMP_IN_SIGHT)
    end
end

return Escort
