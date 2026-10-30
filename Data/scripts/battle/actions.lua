require("global")
require("modifiers")
require("battle/stats")
require("battle/formulas")

actions = actions or {}
local M = modifiersGlobal
local F = formulas

local function hasStatus(chara, id)
    local ok, r = pcall(function() return chara.statusEffects:HasStatusEffect(id) end)
    return ok and r == true
end
actions.hasStatus = hasStatus

function actions.enmityScale(caster)
    local m = 1.0
    local ok, eff = pcall(function() return caster.statusEffects:GetStatusEffectById(223251) end)
    if ok and eff ~= nil then m = m * ((eff:GetTier() == 2) and 1.65 or 1.5) end
    if hasStatus(caster, 223062) then m = m * 1.2 end
    return m
end

function actions.setPhysicalRates(caster, target, action, opts)
    opts = opts or {}
    local rear = (action.param or 0) == 4
    action.hitRate = F.hitRate(caster, target, opts.acc)
    action.critRate = F.critRate(caster, target, opts.crit)
    action.parryRate = rear and 0 or F.parryRate(caster, target)
    action.blockRate = rear and 0 or F.blockRate(caster, target)
    action.resistRate = 0
    action.critMultiplier = F.critMultiplier(caster, target, opts.critDamage)
    action.blockReduction = F.blockReduction(caster, target)
    action.parryReduction = F.PARRY_REDUCTION
    action.ratesFromScript = true
    action.mitigationFromScript = true
end

function actions.basePotencyScale(skill)
    local bp = skill.basePotency
    if bp == nil or bp <= 0 then return 1.0 end
    return F.clamp(bp / 100, 0.1, 3.0)
end

function actions.monsterMove(caster, target, skill, action, container)
    if (skill.basePotency or 0) > 0 then
        local dmg = F.physicalDamage(caster, target, "ws", actions.basePotencyScale(skill))
        action.amount = dmg
        action.enmity = math.floor(dmg * actions.enmityScale(caster))
        actions.setPhysicalRates(caster, target, action)
    else
        action.amount = 0
    end
    action:DoAction(caster, target, skill, container)
    action:TryStatus(caster, target, skill, container, true)
end

function actions.autoAttack(caster, target, skill, action, container)
    local dmg = F.physicalDamage(caster, target, "aa", actions.basePotencyScale(skill))
    dmg = math.max(1, math.floor(dmg * (100 + (caster:GetMod(M.Damage) or 0)) / 100))
    action.amount = dmg
    action.enmity = math.floor(dmg * actions.enmityScale(caster))
    actions.setPhysicalRates(caster, target, action)
    action:DoAction(caster, target, skill, container)
end
