-- Entry points for the formula tests: battle/stats.lua called with plain numbers.

require("battle/stats")

local M = modifiersGlobal

-- A naked player with no equipment. points: STR, VIT, DEX, INT, MND, PIE allotted.
local function nakedPlayer(classId, level, tribeId, points)
    local p = { base = {}, playerWork = { tribe = tribeId } }
    function p:GetClass() return classId end
    function p:GetLevel() return level end
    function p:IsPlayer() return true end
    function p:GetEquipment() return nil end
    function p:GetBonusPoint(_, i) return points[i + 1] or 0 end
    function p:SetBaseStat(id, v) self.base[id] = v end
    return p
end

-- What the server sets for a naked player: STR, VIT, DEX, INT, MND, PIE, HP, MP, attack.
function nakedPlayerStats(classId, level, tribeId, str, vit, dex, int, mnd, pie)
    local p = nakedPlayer(classId, level, tribeId, { str, vit, dex, int, mnd, pie })
    stats.applyPlayerBaseStats(p)
    local b = p.base
    return b[M.Strength], b[M.Vitality], b[M.Dexterity], b[M.Intelligence], b[M.Mind], b[M.Piety],
        b[M.Hp], b[M.Mp], b[M.Attack]
end

function bonusPoints(level) return stats.bonusPoints(level), stats.bonusPointCap(level) end

-- The automatic split for a character with no player: points used, most in one attribute.
function bonusAllocation(classId, level)
    local sum, most = 0, 0
    for _, v in pairs(stats.bonusAllocation(classId, level)) do
        sum = sum + v
        most = math.max(most, v)
    end
    return sum, most
end

function tribe(tribeId, column) return stats.TRIBE[tribeId][column] end

function levelAdjust(userLevel, itemLevel) return stats.levelAdjust(userLevel, itemLevel) end

function mobHp(level, genusId) return stats.mobHp(level, stats.mobFamilyHpMult(genusId)) end

require("battle/formulas")

-- A level-typical character for the damage formulas: every attribute, attack, accuracy and DEF at
-- the class baseline, and for a player one main-hand weapon of the given Damage and delay.
local function typicalChara(classId, level, isPlayer, weaponDamage, weaponDelay)
    local e = stats.expected(isPlayer and classId or 0, level)
    local mods = {
        [M.Strength] = e.str, [M.Vitality] = e.vit, [M.Dexterity] = e.dex,
        [M.Intelligence] = e.int, [M.Mind] = e.mnd, [M.Piety] = e.pie,
        [M.Attack] = e.atk - e.str * 2 / 3,
        [M.Accuracy] = stats.interp(stats.ATK_BASE_CURVE, level),
        [M.Evasion] = stats.interp(stats.ATK_BASE_CURVE, level),
        [M.Defense] = isPlayer and e.gearDef or 1,
    }
    local c = {}
    function c:GetClass() return classId end
    function c:GetLevel() return level end
    function c:IsPlayer() return isPlayer end
    function c:IsMonster() return not isPlayer end
    function c:GetMod(id) return mods[id] or 0 end
    function c:GetEquipment()
        return { GetItemAtSlot = function(_, slot) return slot == stats.SLOT_MAINHAND and { itemId = 1 } or nil end }
    end
    return c, { damagePower = weaponDamage, damageInterval = weaponDelay, frequency = 1, level = 0 }
end

-- One auto-attack with no random spread. A monster attacker has no weapon arguments.
function autoAttackDamage(attackerClass, attackerLevel, weaponDamage, weaponDelay, defenderClass, defenderLevel, defenderIsPlayer)
    local attacker, weapon = typicalChara(attackerClass, attackerLevel, weaponDamage ~= nil, weaponDamage, weaponDelay)
    local defender = typicalChara(defenderClass, defenderLevel, defenderIsPlayer)
    local savedGamedata, savedVariance = GetItemGamedata, formulas.VARIANCE.physical
    GetItemGamedata = function() return weapon end
    formulas.VARIANCE.physical = 0
    local ok, dmg = pcall(formulas.physicalDamage, attacker, defender, "aa", 1.0)
    GetItemGamedata, formulas.VARIANCE.physical = savedGamedata, savedVariance
    if not ok then error(dmg) end
    return dmg
end

function levelFactor(dlvl) return formulas.levelFactor(dlvl) end

-- A level-typical character with some modifiers raised: "Dexterity=20;CanBlock=1" adds 20 DEX and
-- sets CanBlock. Weapon is a main hand of the given Damage and delay (players only).
local function chara(classId, level, isPlayer, extra, weaponDamage, weaponDelay)
    local c, weapon = typicalChara(classId, level, isPlayer, weaponDamage or stats.referenceWeaponDamage(level), weaponDelay or 3.0)
    local adds = {}
    for name, v in string.gmatch(extra or "", "(%w+)=(-?[%d%.]+)") do
        local id = M[name]
        if id == nil then error("unknown modifier " .. name) end
        adds[id] = (adds[id] or 0) + tonumber(v)
    end
    local base = c.GetMod
    function c:GetMod(id) return (base(self, id) or 0) + (adds[id] or 0) end
    return c, weapon
end

local function withWeapon(weapon, f, ...)
    local saved = GetItemGamedata
    GetItemGamedata = function() return weapon end
    local r = { pcall(f, ...) }
    GetItemGamedata = saved
    if not r[1] then error(r[2]) end
    return unpack(r, 2)
end

-- Hit, crit, crit multiplier, parry, block (%), block reduction (fraction) of one swing.
function rates(aClass, aLevel, aPlayer, aMods, dClass, dLevel, dPlayer, dMods)
    local a = chara(aClass, aLevel, aPlayer, aMods)
    local d = chara(dClass, dLevel, dPlayer, dMods)
    return formulas.hitRate(a, d), formulas.critRate(a, d), formulas.critMultiplier(a, d),
        formulas.parryRate(a, d), formulas.blockRate(a, d), formulas.blockReduction(a, d)
end

-- Effective DEF and the share of damage it removes.
function defense(classId, level, isPlayer, mods)
    local c = chara(classId, level, isPlayer, mods)
    return formulas.effectiveDefense(c), formulas.defenseReduction(c)
end

-- Flat damage a monster this far above the attacker takes off each hit.
function levelGapDefense(aLevel, mobLevel, mobMods)
    return formulas.levelGapDefense(chara(3, aLevel, true), chara(0, mobLevel, false, mobMods))
end

-- Stat ratio and stat caps of a player with a weapon of the given Damage and delay.
function statRatio(classId, level, kind, weaponDamage, weaponDelay, mods)
    local c, w = chara(classId, level, true, mods, weaponDamage, weaponDelay)
    return withWeapon(w, function()
        local capP, capS = formulas.statCaps(c, kind)
        return formulas.physicalStatRatio(c, kind), capP, capS
    end)
end

-- One hit with no random spread: kind "aa" or "ws", potency 1 = 100%.
function hit(kind, potency, aClass, aLevel, weaponDamage, weaponDelay, aMods, dLevel, dMods)
    local a, w = chara(aClass, aLevel, true, aMods, weaponDamage, weaponDelay)
    local d = chara(0, dLevel, false, dMods)
    local savedVariance = formulas.VARIANCE.physical
    formulas.VARIANCE.physical = 0
    local ok, dmg = pcall(withWeapon, w, formulas.physicalDamage, a, d, kind, potency)
    formulas.VARIANCE.physical = savedVariance
    if not ok then error(dmg) end
    return dmg
end

-- Lowest and highest of n spreads of one kind.
function varianceRange(kind, n)
    local lo, hi = math.huge, -math.huge
    for _ = 1, n do
        local v = formulas.variance(kind)
        lo, hi = math.min(lo, v), math.max(hi, v)
    end
    return lo, hi
end

function curves(classId, level)
    local e = stats.expected(classId, level)
    return stats.baseHp(classId, level, 0), stats.baseMp(classId, level, 0), e.atk, e.def,
        stats.referenceWeaponDamage(level), stats.mobMp(level, false), stats.mobMp(level, true)
end

function compatibility(value)
    local c = { GetClass = function() return 3 end }
    local d = { GetCompatibility = function() return value end }
    return stats.compatibility(c, d)
end

require("battle/actions")

function basePotencyScale(bp) return actions.basePotencyScale({ basePotency = bp }) end

-- Enmity multiplier with Antagonize at the given tier (status 223251, 0 = none) and Sentinel (223062).
function enmityScale(tier, has223062)
    local effects = {
        GetStatusEffectById = function(_, id) if id == 223251 and tier > 0 then return { GetTier = function() return tier end } end end,
        HasStatusEffect = function(_, id) return id == 223062 and has223062 end,
    }
    return actions.enmityScale({ statusEffects = effects })
end

-- Gear factor of a piece, broken or not.
function itemFactor(userLevel, itemLevel, broken)
    local c = { GetLevel = function() return userLevel end, IsEquippedGearBroken = function() return broken end, GetClass = function() return 3 end }
    return stats.itemFactor(c, stats.SLOT_MAINHAND, { level = itemLevel })
end

function mobIsCaster(classId, spellListId)
    return stats.mobIsCaster({ GetClass = function() return classId end, spellListId = spellListId })
end

-- Every function in the formulas, stats and actions tables, as "table.name".
function formulaFunctions()
    local out = {}
    for _, t in ipairs({ { "formulas", formulas }, { "stats", stats }, { "actions", actions } }) do
        for k, v in pairs(t[2]) do
            if type(v) == "function" then out[#out + 1] = t[1] .. "." .. k end
        end
    end
    table.sort(out)
    return unpack(out)
end

function mobExpectedDef(level) return stats.mobExpected(level).def, stats.expected(0, level).def end
