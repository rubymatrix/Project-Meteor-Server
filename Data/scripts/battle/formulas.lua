require("modifiers")
require("battle/stats")

formulas = formulas or {}
local M = modifiersGlobal

formulas.VARIANCE = { physical = 0.08, magic = 0.05, heal = 0.03 }
formulas.PLAYER_HIT_BASE = 95
formulas.MOB_HIT_BASE = 87
formulas.HIT_GAP_KNEE = 4
formulas.HIT_GAP_STEEP = 4.5
formulas.CRIT_POTENCY_PER_POINT = 0.002
formulas.PARRY_REDUCTION = 0.5
formulas.GAP_DEF_FREE_LEVELS = 4
formulas.GAP_DEF_PER_LEVEL = 0.14
formulas.GAP_DEF_MIN_SHARE = 0.2
formulas.WEAPON_STATS = {
    [2]  = { M.Strength, M.Intelligence },
    [3]  = { M.Strength, M.Mind },
    [4]  = { M.Strength, M.Vitality },
    [7]  = { M.Piety, M.Dexterity },
    [8]  = { M.Strength, M.Piety },
    [22] = { M.Mind, M.Piety },
    [23] = { M.Mind, M.Piety },
}
local ATTR_KEY = { [M.Strength] = "str", [M.Vitality] = "vit", [M.Dexterity] = "dex",
                   [M.Intelligence] = "int", [M.Mind] = "mnd", [M.Piety] = "pie" }
formulas.AA_STAT_CAP = 280
formulas.AA_PER_DAMAGE = 1.6
formulas.WS_PER_DPS = 12.0
formulas.AA_DELAY_EXP = 0.55
formulas.WS_DELAY_EXP = 0.72

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end
formulas.clamp = clamp

local function mod(chara, id)
    return chara:GetMod(id) or 0
end

function formulas.variance(kind)
    local v = formulas.VARIANCE[kind] or 0.05
    return 1 - v + math.random() * 2 * v
end

function formulas.levelFactor(dlvl)
    if dlvl > 0 then return math.max(0.3, 1 - 0.07 * dlvl) end
    return math.min(1.5, 1 - 0.05 * dlvl)
end

function formulas.hitRate(attacker, defender, skillAcc)
    local dlvl = defender:GetLevel() - attacker:GetLevel()
    local base = attacker:IsPlayer() and formulas.PLAYER_HIT_BASE or formulas.MOB_HIT_BASE
    local rate = base - 1.5 * dlvl
    if dlvl > formulas.HIT_GAP_KNEE then
        rate = rate - (formulas.HIT_GAP_STEEP - 1.5) * (dlvl - formulas.HIT_GAP_KNEE)
    end
    if dlvl < 0 then rate = base - 1.0 * dlvl end
    if attacker:IsPlayer() then
        local expA = stats.expected(stats.classOf(attacker), attacker:GetLevel())
        local accGear = mod(attacker, M.Accuracy) - stats.interp(stats.ATK_BASE_CURVE, attacker:GetLevel())
        rate = rate + 0.25 * accGear + 0.14 * (mod(attacker, M.Dexterity) - expA.dex)
    end
    if defender:IsPlayer() then
        local evaGear = mod(defender, M.Evasion) - stats.interp(stats.ATK_BASE_CURVE, defender:GetLevel())
        rate = rate - 0.25 * evaGear
    end
    rate = rate + (skillAcc or 0) + mod(attacker, M.RawHitRate) - mod(defender, M.RawEvadeRate)
    return clamp(rate, 5, 99.9)
end

function formulas.critRate(attacker, defender, bonus)
    local dlvl = defender:GetLevel() - attacker:GetLevel()
    local rate
    if dlvl >= 0 then rate = 7.5 - 0.3 * dlvl else rate = 7.5 - 0.74 * dlvl end
    rate = rate + 0.16 * mod(attacker, M.CriticalHitRating) + (bonus or 0) + mod(attacker, M.RawCritRate)
    rate = rate - 0.16 * mod(defender, M.CriticalHitEvasion)
    return clamp(rate, 1, 30)
end

function formulas.critMultiplier(attacker, defender, potencyBonus, magic, uncapped)
    local dlvl = defender:GetLevel() - attacker:GetLevel()
    local m
    if dlvl >= 0 then m = 1.21 - 0.015 * dlvl else m = 1.21 - 0.03 * dlvl end
    local pot, res
    if magic then
        pot, res = mod(attacker, M.MagicCriticalHitPotency), mod(defender, M.MagicCriticalHitResilience)
    else
        pot, res = mod(attacker, M.CriticalHitAttackPower), mod(defender, M.CriticalHitResilience)
    end
    m = m + (potencyBonus or 0) + formulas.CRIT_POTENCY_PER_POINT * (pot - res)
    return clamp(m, 1.15, 1.75) + (uncapped or 0)
end

function formulas.parryRate(attacker, defender)
    if not defender:IsPlayer() then return 0 end
    if mod(defender, M.CanBlock) ~= 0 then return 0 end
    local dAtk = attacker:GetLevel() - defender:GetLevel()
    local exp = stats.expected(stats.classOf(defender), defender:GetLevel())
    local rate = 13 - 0.3 * dAtk + 0.1 * mod(defender, M.Parry)
    rate = rate + 0.07 * (mod(defender, M.Dexterity) - exp.dex)
    return clamp(rate + mod(defender, M.RawParryRate), 0, 30)
end

function formulas.blockRate(attacker, defender)
    if not defender:IsPlayer() then return 0 end
    if mod(defender, M.CanBlock) == 0 then return 0 end
    local dAtk = attacker:GetLevel() - defender:GetLevel()
    local exp = stats.expected(stats.classOf(defender), defender:GetLevel())
    local rate = 20 - 1.0 * dAtk + 0.1 * (mod(defender, M.Dexterity) - exp.dex) + 0.2 * mod(defender, M.BlockRate)
    return clamp(rate + mod(defender, M.RawBlockRate), 0, 75)
end

function formulas.blockReduction(attacker, defender)
    local dAtk = attacker:GetLevel() - defender:GetLevel()
    local exp = stats.expected(stats.classOf(defender), defender:GetLevel())
    local r = 45 - 2 * dAtk + 0.1 * (mod(defender, M.Vitality) - exp.vit) + 0.2 * mod(defender, M.Block)
    return clamp(r, 20, 75) / 100
end

function formulas.effectiveDefense(chara)
    if chara:IsPlayer() then
        return math.max(0, mod(chara, M.Defense)) + 0.67 * mod(chara, M.Vitality)
    end
    local e = stats.expected(0, chara:GetLevel())
    return math.max(0, e.def + mod(chara, M.Defense) - 1)
end

function formulas.defenseReduction(defender)
    local def = formulas.effectiveDefense(defender)
    local exp = stats.expected(stats.classOf(defender), defender:GetLevel()).def
    return def / (def + 3 * math.max(exp, 1))
end

function formulas.levelGapDefense(attacker, defender)
    if defender:IsPlayer() then return 0 end
    local lv = defender:GetLevel()
    local over = (lv - attacker:GetLevel()) - formulas.GAP_DEF_FREE_LEVELS
    if over <= 0 then return 0 end
    local typical = stats.expected(0, lv).def
    local scale = typical > 0 and formulas.effectiveDefense(defender) / typical or 1
    return formulas.GAP_DEF_PER_LEVEL * over * stats.referenceWeaponDamage(lv) * scale
end

function formulas.statCaps(attacker, kind, w)
    w = w or stats.weapon(attacker)
    local dps = w.dps or 0
    local capP = 318 + 6 * (dps - 34.62)
    local capS = 280 + 5 * (dps - 34.62)
    if kind ~= "ws" then
        capP = math.min(formulas.AA_STAT_CAP, capP)
        capS = math.min(formulas.AA_STAT_CAP, capS)
    end
    return math.max(capP, 1), math.max(capS, 1)
end

function formulas.physicalStatRatio(attacker, kind, w)
    if not attacker:IsPlayer() then return 1 end
    local classId = stats.classOf(attacker)
    local pair = formulas.WEAPON_STATS[classId] or { M.Strength, M.Vitality }
    local exp = stats.expected(classId, attacker:GetLevel())
    local pExp, sExp = exp[ATTR_KEY[pair[1]]], exp[ATTR_KEY[pair[2]]]
    local capP, capS = formulas.statCaps(attacker, kind or "ws", w)
    local p = math.min(mod(attacker, pair[1]), capP)
    local s = math.min(mod(attacker, pair[2]), capS)
    pExp, sExp = math.min(pExp, capP), math.min(sExp, capS)
    local atk = mod(attacker, M.Attack) + mod(attacker, M.Strength) * 2 / 3
    local num = 0.8 * p + 0.68 * s + 0.38 * atk
    local den = 0.8 * pExp + 0.68 * sExp + 0.38 * exp.atk
    if den <= 0 then return 1 end
    return clamp(num / den, 0.25, 2.5)
end

function formulas.physicalDamage(attacker, defender, kind, potency, slot)
    local w = stats.weapon(attacker, slot)
    local base
    local delayRatio = math.max(w.delay, 0.5) / 3.0
    if kind == "ws" then
        base = formulas.WS_PER_DPS * w.dps * delayRatio ^ formulas.WS_DELAY_EXP
    else
        base = formulas.AA_PER_DAMAGE * w.damage * delayRatio ^ formulas.AA_DELAY_EXP
    end
    local ratio = formulas.physicalStatRatio(attacker, kind, w)
    local lf = formulas.levelFactor(defender:GetLevel() - attacker:GetLevel())
    local defCut = formulas.defenseReduction(defender)
    local var = formulas.variance("physical")
    local gapDef = formulas.levelGapDefense(attacker, defender)
    trace("base", base)
    trace("potency", potency or 1)
    trace("statRatio", ratio)
    trace("levelFactor", lf)
    trace("defenseCut", defCut)
    trace("variance", var)
    trace("gapDefense", gapDef)
    local dmg = base * (potency or 1) * ratio * lf * (1 - defCut) * var
    dmg = math.max(dmg - gapDef, dmg * formulas.GAP_DEF_MIN_SHARE)
    dmg = dmg * (1 - clamp(mod(defender, M.PhysicalResistance), 0, 100) / 100)
    dmg = dmg * (1 - mod(defender, M.DamageTakenDown) / 100)
    return math.max(1, math.floor(dmg))
end
