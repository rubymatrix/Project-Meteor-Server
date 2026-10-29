--[[
The opening battles of the three starting cities (directors QuestDirectorMan0g001, Man0l001 and
Man0u001). Two story allies fight beside the player against foes that stand still until hit. When
the player draws on a foe the allies close in, weapons drawn; the player's first hit starts the
fight. The rest of the pack goes for the tank ally, and the foe hit turns to the tank a moment
later. Won when the foes are dead.
--]]

local Opening = Encounter.define("opening")

local JOB_PUGILIST, JOB_THAUMATURGE, JOB_CONJURER = 2, 22, 23
local MOD_DAMAGE, MOD_MINIMUM_HP_LOCK = 58, 114
local ENEMY_MIN_LEVEL, ENEMY_MAX_LEVEL = 1, 13
local ALLY_LEVEL_LEAD = 10
local ALLY_DAMAGE_PERCENT = -50
local TANK_BONUS_HP = 500
local POTENCIAL_LEVEL_HIDDEN = -1.0
local TANK_PULL_SECONDS = 1.5
local TANK_PULL_ENMITY = 5000
local SPELL_THUNDER, SPELL_CURE, SPELL_STONE = 27313, 27346, 27355
local CASTER_RANGE = 10

-- What each class does in the fight; the tank only swings. Single-target spells only, so the
-- casters never hit foes nobody has pulled.
local ROLES = {
    [JOB_PUGILIST] = { rules = {} },
    [JOB_THAUMATURGE] = {
        range = CASTER_RANGE,
        rules = { { use = SPELL_THUNDER, on = "target", cooldown = 8 } },
    },
    [JOB_CONJURER] = {
        range = CASTER_RANGE,
        rules = {
            { tier = 1, use = SPELL_CURE, on = "lowestAllyBelow(40)", cooldown = 8 },
            { tier = 2, use = SPELL_STONE, on = "target", when = "self:mpp() > 30", cooldown = 6 },
        },
    },
}

-- Gridania: Papalymo and Yda against three wolves.
Opening:variant("g", {
    allies = {
        { pool = 3, job = JOB_THAUMATURGE, at = { 365.89, 4.0943, -706.72, -0.718 } },
        { pool = 4, job = JOB_PUGILIST, at = { 365.266, 4.122, -700.73, 1.5659 }, tank = true },
    },
    enemyPool = 2,
    enemies = {
        { 374.427, 4.4, -698.711, -1.942 },
        { 375.377, 4.4, -700.247, -1.992 },
        { 375.125, 4.4, -703.591, -1.54 },
    },
})

-- Limsa Lominsa: Y'shtola and Sthalmann against three aurelias on the deck.
Opening:variant("l", {
    allies = {
        { pool = 8290001, job = JOB_CONJURER, at = { -8, 16.35, 6, 0.5 } },
        { pool = 8290002, job = JOB_PUGILIST, at = { 0, 16.35, 22, 3 }, tank = true },
    },
    enemyPool = 8205403,
    enemies = {
        { -0.02, 16.39, 14.24, -2.81 },
        { -3.02, 16.39, 14.24, -2.81 },
        { -6.02, 16.39, 14.24, -2.81 },
    },
})

-- Ul'dah: Niellefresne and Thancred against a goobbue.
Opening:variant("u", {
    allies = {
        { pool = 8290003, job = JOB_CONJURER, at = { -11.86, 192, 35.06, -0.8 } },
        { pool = 8290004, job = JOB_PUGILIST, at = { -26.41, 192, 39.52, 1.2 }, tank = true },
    },
    enemyPool = 8203301,
    enemies = {
        { -6.193, 192, 47.658, -2.224 },
    },
})

local function allyOverride(player, role)
    local o = { bb = { leader = player }, rules = role.rules }
    if role.range then
        o.behaviors = { Ready = { range = role.range }, Combat = { range = role.range } }
    end
    return o
end

function Opening:setup()
    local c = self.cfg
    local player = self:participants()[1]
    self.player = player
    local level = math.max(1, player and player:level() or 1)
    local enemyLevel = math.max(ENEMY_MIN_LEVEL, math.min(ENEMY_MAX_LEVEL, level))

    for _, a in ipairs(c.allies) do
        local ally = self:spawn("allies", {
            pool = a.pool, kind = "ally", level = enemyLevel + ALLY_LEVEL_LEAD, at = a.at,
            profile = "content/profiles/OpeningAlly",
            override = allyOverride(player, ROLES[a.job]),
        })
        if ally then
            ally.cs.charaWork.parameterSave.state_mainSkill[0] = a.job
            ally.cs:SetMod(MOD_DAMAGE, ALLY_DAMAGE_PERCENT)
            ally.cs:SetMod(MOD_MINIMUM_HP_LOCK, 1)
            if a.tank then
                self.tank = ally
                ally:setMaxHp(ally:maxHp() + TANK_BONUS_HP)
            end
        end
    end

    for _, at in ipairs(c.enemies) do
        local mob = self:spawn("enemies", {
            pool = c.enemyPool, level = enemyLevel, at = at,
            profile = { behaviors = { Roam = false, Detect = false, Link = false, Leash = { radius = 0 } } },
        })
        if mob then mob.cs.charaWork.battleSave.potencial = POTENCIAL_LEVEL_HIDDEN end
    end

    self:partyAllies("allies")
    self:objective("enemies", Objective.kill("enemies"), { wins = true })
    if player then player.cs:SetMod(MOD_MINIMUM_HP_LOCK, 1) end
end

local function alive(a)
    return a ~= nil and a:isAlive()
end

function Opening:onStart()
    self:on("Damaged", { group = "enemies" }, function(_, ev)
        if self.pulled or not (ev.other and ev.other:isPlayer()) then return end
        self.pulled = true
        self:pullPack(ev.actor, ev.other)
    end)
    self:on("Died", { group = "enemies" }, function(_, ev) self:retargetAllies(ev.actor) end)
end

-- The first hit pulls the whole pack onto the tank (or the puller when there is none). Linked foes
-- stay unclaimed (orange) until hit. The mob hit stays on the puller until the tank takes it over.
function Opening:pullPack(first, puller)
    local tank = alive(self.tank) and self.tank or nil
    if tank then first:hate(puller, TANK_PULL_ENMITY) end
    local linkTarget = tank or puller
    for _, mob in ipairs(self:group("enemies"):list()) do
        if mob.cs ~= first.cs and mob:isAlive() then
            mob.cs.hateContainer:AddLinkHate(linkTarget.cs, tank and TANK_PULL_ENMITY or 0)
            if not mob:isEngaged() then mob:engage(linkTarget) end
        end
    end
    if not tank then return end
    self:after(TANK_PULL_SECONDS, function()
        if not alive(tank) or not first:isAlive() then return end
        first:hate(tank, TANK_PULL_ENMITY * 4)
        tank:hate(first, TANK_PULL_ENMITY)
        if not tank:isEngaged() then tank:engage(first) end
    end)
end

-- Allies go straight to the next foe, so they stay in battle stance.
function Opening:retargetAllies(dead)
    local foes = {}
    for _, mob in ipairs(self:group("enemies"):list()) do
        if mob.cs ~= dead.cs and mob:isAlive() then table.insert(foes, mob) end
    end
    if #foes == 0 then return end
    for _, ally in ipairs(self:group("allies"):list()) do
        local t = ally:target()
        if ally:isAlive() and (t == nil or not t:isAlive() or t.cs == dead.cs) then
            local next
            for _, mob in ipairs(foes) do
                local mt = mob:target()
                if mt and mt.cs == ally.cs then next = mob break end
            end
            if not next then
                table.sort(foes, function(a, b) return ally:distance(a) < ally:distance(b) end)
                next = foes[1]
            end
            ally:clearHate(dead)
            ally:engage(next)
        end
    end
end

return Opening
