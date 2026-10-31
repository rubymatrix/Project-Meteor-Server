-- Entry points for the combat damage tests: Battle/Formulas.lua on level-typical characters, with
-- research setups layered on top. nil arguments keep the typical value.

require("Battle/Stats")
require("Battle/Formulas")

local M = Modifier

local weapons = {}
local nextItem = 1

-- A level-typical character, as formulas.lua's, plus the magic stats the server derives for players.
-- weapon: { damage, delay } for a player main hand. mods overrides any modifier.
local function chara(classId, level, isPlayer, mods, weapon)
    local e = stats.expected(isPlayer and classId or 0, level)
    local m = {
        [M.Strength] = e.str, [M.Vitality] = e.vit, [M.Dexterity] = e.dex,
        [M.Intelligence] = e.int, [M.Mind] = e.mnd, [M.Piety] = e.pie,
        [M.Attack] = e.atk - e.str * 2 / 3,
        [M.Accuracy] = stats.interp(stats.ATK_BASE_CURVE, level),
        [M.Evasion] = stats.interp(stats.ATK_BASE_CURVE, level),
        [M.Defense] = isPlayer and e.gearDef or 1,
    }
    if isPlayer then
        m[M.AttackMagicPotency] = e.magic + e.int / 4
        m[M.HealingMagicPotency] = e.magic + e.mnd / 4
        m[M.MagicAccuracy] = e.magic + e.mnd / 4
        m[M.MagicEvasion] = e.magic + e.pie / 4
    end
    for id, v in pairs(mods or {}) do m[id] = v end
    local item = nil
    if isPlayer and weapon ~= nil then
        item = nextItem
        nextItem = nextItem + 1
        weapons[item] = { damagePower = weapon[1], damageInterval = weapon[2], frequency = 1, level = 0 }
    end
    local c = { mods = m }
    function c:GetClass() return classId end
    function c:GetLevel() return level end
    function c:IsPlayer() return isPlayer end
    function c:IsMonster() return not isPlayer end
    function c:GetMod(id) return m[id] or 0 end
    function c:GetEquipment()
        return { GetItemAtSlot = function(_, slot) return (slot == stats.SLOT_MAINHAND and item) and { itemId = item } or nil end }
    end
    return c
end

-- Runs f with the item sheet mocked and no random spread (or math.random fixed to roll).
local function run(f, roll)
    local savedGamedata, savedRandom = GetItemGamedata, math.random
    local v = formulas.VARIANCE
    local saved = { v.physical, v.magic, v.heal }
    GetItemGamedata = function(id) return weapons[id] end
    if roll ~= nil then
        math.random = function() return roll end
    else
        v.physical, v.magic, v.heal = 0, 0, 0
    end
    local ok, a = pcall(f)
    GetItemGamedata, math.random = savedGamedata, savedRandom
    v.physical, v.magic, v.heal = saved[1], saved[2], saved[3]
    if not ok then error(a) end
    return a
end

-- Attacker mods: primary and secondary attribute of the class's weapon pair, total attack.
local function attackerMods(classId, level, primary, secondary, attack)
    local mods = {}
    local pair = formulas.WEAPON_STATS[classId]
    if pair ~= nil then
        if primary ~= nil then mods[pair[1]] = primary end
        if secondary ~= nil then mods[pair[2]] = secondary end
    end
    if attack ~= nil then
        local str = mods[M.Strength] or stats.expected(classId, level).str
        mods[M.Attack] = attack - str * 2 / 3
    end
    return mods
end

-- One physical hit. The attacker is a player when weaponDamage is given. kind is "aa" or "ws".
function physicalDamage(kind, potency, aClass, aLevel, weaponDamage, weaponDelay, dClass, dLevel, dIsPlayer,
                        primary, secondary, attack, dDefense, dVitality)
    local aIsPlayer = weaponDamage ~= nil
    local attacker = chara(aClass, aLevel, aIsPlayer,
        aIsPlayer and attackerMods(aClass, aLevel, primary, secondary, attack) or nil,
        aIsPlayer and { weaponDamage, weaponDelay } or nil)
    local dMods = {}
    if dDefense ~= nil then dMods[M.Defense] = dDefense end
    if dVitality ~= nil then dMods[M.Vitality] = dVitality end
    local defender = chara(dClass, dLevel, dIsPlayer, dMods)
    return run(function() return formulas.physicalDamage(attacker, defender, kind, potency) end)
end

function statCaps(kind, dps)
    local attacker = chara(stats.CLASS.LNC, 50, true)
    return formulas.statCaps(attacker, kind, { dps = dps })
end

function critRate(aClass, aLevel, aIsPlayer, dClass, dLevel, dIsPlayer, rating)
    local attacker = chara(aClass, aLevel, aIsPlayer, { [M.CriticalHitRating] = rating or 0 })
    local defender = chara(dClass, dLevel, dIsPlayer)
    return formulas.critRate(attacker, defender)
end

-- Player attacker against a monster. potency: crit potency points; uncappedPotency: points added
-- past the cap, as the Thundaga combo's.
function critMultiplier(aLevel, dLevel, potency, magic, uncappedPotency)
    local id = magic and M.MagicCriticalHitPotency or M.CriticalHitAttackPower
    local attacker = chara(stats.CLASS.GLA, aLevel, true, { [id] = potency or 0 })
    local defender = chara(0, dLevel, false)
    local uncapped = uncappedPotency and uncappedPotency * formulas.CRIT_POTENCY_PER_POINT or nil
    return formulas.critMultiplier(attacker, defender, 0, magic, uncapped)
end

-- accBonus and dexBonus are added to the attacker's typical Accuracy and DEX.
function hitRate(aClass, aLevel, aIsPlayer, dClass, dLevel, dIsPlayer, accBonus, dexBonus)
    local attacker = chara(aClass, aLevel, aIsPlayer)
    attacker.mods[M.Accuracy] = attacker.mods[M.Accuracy] + (accBonus or 0)
    attacker.mods[M.Dexterity] = attacker.mods[M.Dexterity] + (dexBonus or 0)
    local defender = chara(dClass, dLevel, dIsPlayer)
    return formulas.hitRate(attacker, defender)
end

-- Accuracy Comradery adds to a level-typical player.
function comraderyAccuracy(level)
    require("Battle/Partybonus")
    return partybonus.SIZES.comradery[M.Accuracy] * stats.interp(stats.ATK_BASE_CURVE, level)
end

-- Defender stats: shield on or off, Parry, absolute DEX (nil: typical).
function parryRate(aLevel, aIsPlayer, dClass, dLevel, dIsPlayer, shield, parry, dex)
    local defender = chara(dClass, dLevel, dIsPlayer,
        { [M.CanBlock] = shield and 1 or 0, [M.Parry] = parry or 0, [M.Dexterity] = dex })
    return formulas.parryRate(chara(0, aLevel, aIsPlayer), defender)
end

function blockRate(aLevel, aIsPlayer, dClass, dLevel, dIsPlayer, shield, dexBonus, blockRateMod)
    local defender = chara(dClass, dLevel, dIsPlayer, { [M.CanBlock] = shield and 1 or 0, [M.BlockRate] = blockRateMod or 0 })
    defender.mods[M.Dexterity] = defender.mods[M.Dexterity] + (dexBonus or 0)
    return formulas.blockRate(chara(0, aLevel, aIsPlayer), defender)
end

-- Fraction of a blocked hit removed. A monster attacks a shielded player.
function blockReduction(aLevel, dClass, dLevel, vitBonus, block)
    local defender = chara(dClass, dLevel, true, { [M.CanBlock] = 1, [M.Block] = block or 0 })
    defender.mods[M.Vitality] = defender.mods[M.Vitality] + (vitBonus or 0)
    return formulas.blockReduction(chara(0, aLevel, false), defender)
end

-- meva: the defender's absolute Magic Evasion (nil: typical). fireRes: Fire Resistance.
function resistRate(aClass, aLevel, aIsPlayer, dClass, dLevel, dIsPlayer, meva, fireRes)
    local attacker = chara(aClass, aLevel, aIsPlayer)
    local defender = chara(dClass, dLevel, dIsPlayer, { [M.FireResistance] = fireRes or 0 })
    if meva ~= nil then defender.mods[M.MagicEvasion] = meva end
    return formulas.resistRate(attacker, defender)
end

function effectiveDefense(classId, level, def, vit)
    return formulas.effectiveDefense(chara(classId, level, true, { [M.Defense] = def, [M.Vitality] = vit }))
end

function spellLevelFactor(dlvl) return formulas.spellLevelFactor(dlvl) end

function typicalInt(classId, level) return stats.expected(classId, level).int end

-- One attack spell on a monster with an INT weight, no spread. int is absolute (nil: typical) and
-- adds a quarter of its change to attack magic potency, as on a player; ampBonus adds potency.
function spellDamage(cClass, cLevel, magnitude, intWeight, tLevel, int, ampBonus)
    local caster = chara(cClass, cLevel, true)
    local e = stats.expected(cClass, cLevel)
    int = int or e.int
    caster.mods[M.Intelligence] = int
    caster.mods[M.AttackMagicPotency] = e.magic + int / 4 + (ampBonus or 0)
    local target = chara(0, tLevel, false)
    return run(function() return formulas.spellDamage(caster, target, magnitude, { [M.Intelligence] = intWeight }) end)
end

-- One heal, no crit. roll fixes math.random for the spread; nil means no spread.
function healAmount(cClass, cLevel, magnitude, hmp, mnd, vit, roll)
    local caster = chara(cClass, cLevel, true, { [M.HealingMagicPotency] = hmp, [M.Mind] = mnd, [M.Vitality] = vit })
    return run(function() return formulas.healAmount(caster, caster, magnitude) end, roll)
end

-- Multiplier of a heal that crits, with this much Magic Critical Potency.
function healCritMultiplier(cClass, cLevel, potency)
    local caster = chara(cClass, cLevel, true, { [M.MagicCriticalHitPotency] = potency or 0 })
    return run(function() return formulas.healCrit(caster) end, 0)
end

-- Heal crit rate in percent: the highest roll that still crits.
function healCritRate(cClass, cLevel)
    local caster = chara(cClass, cLevel, true)
    local lo, hi = 0, 1
    for _ = 1, 40 do
        local mid = (lo + hi) / 2
        if run(function() return formulas.healCrit(caster) end, mid) > 1 then lo = mid else hi = mid end
    end
    return lo * 100
end

function commandCostBase(level) return formulas.commandCostBase(level) end

function mpCost(level, permille) return formulas.mpCost(level, permille) end

-- Same-level solo fight, no random spread: auto-attacks and a weaponskill at 1000 TP (casters nuke
-- while MP lasts) against swings and a 1.8x TP move at 1000 TP. TP per swing is the server's: 100 x
-- delay for the player, 300 for the monster. Returns the player's HP share left (negative if the
-- player lost) and the fight's length in seconds.
function soloFight(classId, level, weaponDamage, weaponDelay, gearDef, gearEva, nukeMagnitude, nukeCastS, nukeRecastS, nukePermille, intWeight, mndWeight)
    local mods = attackerMods(classId, level)
    mods[M.Defense] = gearDef
    mods[M.Evasion] = stats.interp(stats.ATK_BASE_CURVE, level) + gearEva
    local pc = chara(classId, level, true, mods, { weaponDamage, weaponDelay })
    local mob = chara(0, level, false)
    local r = run(function()
        local e = stats.expected(classId, level)
        local hpMax = stats.baseHp(classId, level, e.vit)
        local hp, mobHp = hpMax, stats.mobHp(level)
        local mp = stats.baseMp(classId, level, e.pie)
        local mobHit, pcHit = formulas.hitRate(mob, pc) / 100, formulas.hitRate(pc, mob) / 100
        local swing = formulas.physicalDamage(mob, pc, "aa", 1.0) * mobHit
        local hit = formulas.physicalDamage(pc, mob, "aa", 1.0) * pcHit
        local ws = formulas.physicalDamage(pc, mob, "ws", 1.0) * pcHit
        local nuke, cost = 0, 0
        if nukeMagnitude ~= nil and nukeMagnitude > 0 then
            local w = {}
            if intWeight ~= nil and intWeight > 0 then w[M.Intelligence] = intWeight end
            if mndWeight ~= nil and mndWeight > 0 then w[M.Mind] = mndWeight end
            nuke = formulas.spellDamage(pc, mob, nukeMagnitude, w)
            cost = formulas.mpCost(level, nukePermille)
        end
        local t, nextPc, nextMob, nukeReady = 0, 0, weaponDelay, 0
        local tp, mobTp = 0, 0
        while t < 600 do
            if nextPc <= nextMob then
                t = nextPc
                if nuke > 0 and mp >= cost and t >= nukeReady then
                    mobHp = mobHp - nuke
                    mp = mp - cost
                    nukeReady = t + math.max(nukeRecastS, nukeCastS)
                    nextPc = t + nukeCastS
                elseif nuke == 0 and tp >= 1000 then
                    mobHp = mobHp - ws
                    tp = tp - 1000
                else
                    mobHp = mobHp - hit
                    tp = tp + 100 * weaponDelay * pcHit
                    nextPc = t + weaponDelay
                end
                if mobHp <= 0 then return { hp / hpMax, t } end
            else
                t = nextMob
                if mobTp >= 1000 then
                    hp = hp - swing * 1.8
                    mobTp = mobTp - 1000
                else
                    hp = hp - swing
                    mobTp = mobTp + 300 * mobHit
                end
                nextMob = t + 4.2
                if hp <= 0 then return { hp / hpMax, t } end
            end
        end
        return { hp / hpMax, t }
    end)
    return r[1], r[2]
end

-- A monster's mean swing on a geared player, as a share of the player's level-typical max HP.
function swingShare(classId, level, mobLevel, gearDef)
    local mods = attackerMods(classId, level)
    mods[M.Defense] = gearDef
    local pc = chara(classId, level, true, mods)
    local mob = chara(0, mobLevel, false)
    return run(function()
        local e = stats.expected(classId, level)
        return formulas.physicalDamage(mob, pc, "aa", 1.0) / stats.baseHp(classId, level, e.vit)
    end)
end
