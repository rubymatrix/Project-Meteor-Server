require("Global")
require("Modifiers")
require("BattleUtils")
require("Battle/Stats")
require("Battle/Formulas")
require("Battle/Parts")

--[[
Shared action bodies. Per-action scripts in Command/{WeaponSkill,Magic,Ability,AutoAttack} build a
params table (potency, combo and positional bonuses, status rule, enmity) and call one of these
from onSkillFinish. The rates set here tell C# to skip its own. Every params key is listed in
Data/Docs/battle-sources.md.
--]]

actions = actions or {}
local M = Modifier
local F = formulas

-- C# HitDirection bits on action.param.
local DIR_FRONT, DIR_RIGHT, DIR_REAR, DIR_LEFT = 1, 2, 4, 8

local function hasStatus(chara, id)
	local ok, r = pcall(function() return chara.statusEffects:HasStatusEffect(id) end)
	return ok and r == true
end
actions.hasStatus = hasStatus

local function trySet(obj, field, value)
	pcall(function() obj[field] = value end)
end

-- Enmity multipliers for every action that sets action.enmity here: Antagonize 223251 x1.5 (x1.65
-- at tier 2, AF head), Sentinel 223062 x1.2 on everything but heals, and gear Enmity +0.1% a point.
function actions.enmityScale(caster, heal)
	local m = 1.0
	local ok, eff = pcall(function() return caster.statusEffects:GetStatusEffectById(223251) end)
	if ok and eff ~= nil then m = m * ((eff:GetTier() == 2) and 1.65 or 1.5) end
	if not heal and hasStatus(caster, 223062) then m = m * 1.2 end
	local okGear, gear = pcall(function() return caster:GetMod(M.Enmity) end)
	if okGear and gear ~= nil and gear ~= 0 then m = m * (1 + gear / 1000) end
	return m
end

function actions.hatesCaster(mob, who)
	local ok, r = pcall(function() return mob.hateContainer:HasHateForTarget(who) end)
	return ok and r == true
end

-- Fists of Fire / Wind / Earth turn the owner's swings into that element.
function actions.autoAttackElement(caster, skill)
	if hasStatus(caster, 223209) then return 5 end     -- Fire
	if hasStatus(caster, 223211) then return 7 end     -- Wind
	if hasStatus(caster, 223210) then return 8 end     -- Earth
	return F.elementOf(skill)
end

function actions.isHostile(caster, target)
	local ok, r = pcall(function() return caster:IsPlayer() ~= target:IsPlayer() end)
	return ok and r
end

function actions.positionalMet(skill, action)
	local pb = tostring(skill.positionBonus)
	local dir = action.param or 0
	if pb == "Front" then return dir == DIR_FRONT end
	if pb == "Rear" then return dir == DIR_REAR end
	if pb == "Flank" then return dir == DIR_LEFT or dir == DIR_RIGHT end
	return false
end

-- WeaponSkillState/MagicState set skill.isCombo before onSkillFinish.
function actions.comboed(skill)
	return skill.isCombo and skill.comboStep ~= nil and skill.comboStep >= 2
end

function actions.setPhysicalRates(caster, target, action, opts)
	opts = opts or {}
	local rear = (action.param or 0) == DIR_REAR
	action.hitRate = F.hitRate(caster, target, opts.acc)
	action.critRate = F.critRate(caster, target, opts.crit)
	action.parryRate = rear and 0 or F.parryRate(caster, target)
	action.blockRate = rear and 0 or F.blockRate(caster, target)
	action.resistRate = 0
	trySet(action, "critMultiplier", F.critMultiplier(caster, target, opts.critDamage))
	trySet(action, "blockReduction", F.blockReduction(caster, target))
	trySet(action, "parryReduction", F.PARRY_REDUCTION)
	trySet(action, "ratesFromScript", true)
	trySet(action, "mitigationFromScript", true)
end

function actions.setMagicRates(caster, target, action, opts)
	opts = opts or {}
	action.hitRate = 100
	action.critRate = F.critRate(caster, target, opts.crit)
	action.parryRate = 0
	action.blockRate = 0
	-- opts.acc lowers the resist chance on the weaponskill hit-rate scale (Dark Seal +50 -> -12.5).
	action.resistRate = math.max(0, F.resistRate(caster, target) - (opts.acc or 0))
	trySet(action, "critMultiplier", F.critMultiplier(caster, target, 0, true, opts.critUncapped))
	trySet(action, "ratesFromScript", true)
	trySet(action, "mitigationFromScript", true)
end

local function applyStatus(caster, target, skill, action, container, params, posMet, combo, isAdditional)
	if skill.statusId == nil or skill.statusId == 0 then return end
	local rule = params.status or "always"
	local ok = (rule == "always")
		or (rule == "positional" and posMet)
		or (rule == "combo" and combo)
		or (rule == "notCombo" and not combo)
		or (rule == "targetingCaster" and pcall(function() return target.currentTarget end) and target.currentTarget == caster.Id)
		or (rule == "noEnmity" and not actions.hatesCaster(target, caster))
	if not ok then return end
	-- params.statusChance wins; a script that names a rule but leaves the DB chance at 0
	-- (positional-only statuses are stored that way) lands it; otherwise the DB chance rolls.
	if params.statusChance ~= nil then skill.statusChance = params.statusChance
	elseif params.status ~= nil and (skill.statusChance == nil or skill.statusChance <= 0) then skill.statusChance = 1.0 end
	-- skill is shared by every target of an AoE, so the listed chance is restored afterwards.
	local listed = skill.statusChance
	if actions.isHostile(caster, target) then
		skill.statusChance = F.statusLandChance(caster, target, skill.statusId, listed, params.statusKind or "rider")
	end
	action:TryStatus(caster, target, skill, container, isAdditional ~= false)
	skill.statusChance = listed
end

-- skill.bonusCritRate is in crit rating points; 0.16 % each, the scale C# GetCritRate uses.
function actions.skillCritBonus(skill)
	local ok, r = pcall(function() return skill.bonusCritRate end)
	if not ok or r == nil then return 0 end
	return 0.16 * r
end

function actions.basePotencyScale(skill)
	local bp = skill.basePotency
	if bp == nil or bp <= 0 then return 1.0 end
	return F.clamp(bp / 100, 0.1, 3.0)
end

function actions.autoAttack(caster, target, skill, action, container)
	-- basePotency is 100 on every generic swing; monster swing sets (BattleNpc.AddAutoAttack) carry
	-- their own.
	local dmg = F.physicalDamage(caster, target, "aa", actions.basePotencyScale(skill))
	dmg = math.max(1, math.floor(dmg * F.affinityMult(target, actions.autoAttackElement(caster, skill))
		* F.directionMult(target, action.param)))
	action.amount = dmg
	action.enmity = math.floor(dmg * actions.enmityScale(caster))
	actions.setPhysicalRates(caster, target, action)
	action:DoAction(caster, target, skill, container)
end

-- Light Shot and Throw: a ranged attack keyed to weapon Damage like an auto-attack.
function actions.rangedShot(caster, target, skill, action, container, params)
	params = params or {}
	local dmg = F.physicalDamage(caster, target, "aa", (params.potency or 1.0) * actions.basePotencyScale(skill), params.slot)
	action.amount = dmg
	action.enmity = math.floor(dmg * (params.enmityMult or 1.0) * actions.enmityScale(caster))
	actions.setPhysicalRates(caster, target, action,
		{ acc = (params.acc or 0) + 0.25 * (skill.accuracyModifier or 0), crit = actions.skillCritBonus(skill) })
	action:DoAction(caster, target, skill, container)
end

-- Physical weaponskills (players and monster TP moves)
function actions.physicalWeaponskill(caster, target, skill, action, container, params)
	params = params or {}
	local posMet = actions.positionalMet(skill, action)
	local combo = actions.comboed(skill)

	-- basePotency (100 = neutral) scales on top so onCombo/onPositional hooks that multiply it
	-- still work.
	local potency = (params.potency or 1.0) * actions.basePotencyScale(skill)
	-- accuracyModifier counts a quarter hit-rate point each: Feint's 100 -> +25.
	local acc, crit = (params.acc or 0) + 0.25 * (skill.accuracyModifier or 0), actions.skillCritBonus(skill)
	local enmityMult = params.enmityMult or 1.0
	if posMet then
		potency = potency * (params.positionalPotency or 1.0)
		acc = acc + (params.positionalAcc or 0)
		crit = crit + (params.positionalCrit or 0)
	end
	if combo then
		potency = potency * (params.comboPotency or 1.0)
		crit = crit + (params.comboCrit or 0)
		enmityMult = enmityMult * (params.comboEnmityMult or 1.0)
	end

	if params.scale then potency = potency * params.scale(caster, target, skill, combo, posMet) end
	local dmg = F.physicalDamage(caster, target, params.kind or "ws", potency)
	if params.flatDamage then dmg = dmg + params.flatDamage(caster, target, skill) end
	dmg = math.max(1, math.floor(dmg * F.affinityMult(target, F.elementOf(skill)) * F.directionMult(target, action.param)))
	action.amount = dmg
	local flat = params.enmityFlat and F.fixedEnmity(params.enmityFlat, caster:GetLevel()) or 0
	action.enmity = math.floor((dmg * enmityMult + flat) * actions.enmityScale(caster))
	if params.accScale then acc = acc + params.accScale(caster, target, skill, combo, posMet) end
	actions.setPhysicalRates(caster, target, action, { acc = acc, crit = crit, critDamage = params.critDamage })
	action:DoAction(caster, target, skill, container)
	if parts ~= nil and caster:IsPlayer() then
		pcall(function() if action:ActionLanded() then parts.onWeaponskillHit(caster, target, skill, action.amount) end end)
	end
	applyStatus(caster, target, skill, action, container, params, posMet, combo, true)
	if params.after then params.after(caster, target, skill, action, container, combo, posMet) end
end

-- Spells
function actions.attackSpell(caster, target, skill, action, container, params)
	params = params or {}
	local combo = actions.comboed(skill)
	local magnitude = (params.magnitude or 1000) * actions.basePotencyScale(skill)
	if combo and params.comboPotency then magnitude = magnitude * params.comboPotency end
	if params.scale then magnitude = magnitude * params.scale(caster, target, skill, combo) end
	local dmg = F.spellDamage(caster, target, magnitude, params.stats, params.statsOnly)
	dmg = math.max(1, math.floor(dmg * F.affinityMult(target, F.elementOf(skill))))
	-- Cleric Stance
	if hasStatus(caster, 223227) then dmg = math.floor(dmg * 1.2) end
	-- Lunar Curtain
	if hasStatus(target, 223273) then dmg = 0 end
	action.amount = dmg
	action.enmity = math.floor(dmg * (params.enmityMult or 1.0) * actions.enmityScale(caster))
	local acc = 0.25 * (skill.accuracyModifier or 0) + ((combo and params.comboAcc) or 0)
	actions.setMagicRates(caster, target, action,
		{ crit = actions.skillCritBonus(skill), acc = acc,
		  critUncapped = (combo and params.comboCritUncapped) or nil })
	action:DoAction(caster, target, skill, container)
	applyStatus(caster, target, skill, action, container, params, false, combo, true)
	if params.after then params.after(caster, target, skill, action, container, combo) end
end

-- params.amount overrides the formula (Curaga pool shares). Enmity counts only HP actually
-- restored, so healing a full-HP target draws none. Returns the amount restored.
function actions.healSpell(caster, target, skill, action, container, params)
	params = params or {}
	local amount = params.amount or F.healAmount(caster, target, params.magnitude or 1000)
	if params.amount == nil then
		local crit = F.healCrit(caster)
		amount = math.floor(amount * crit)
		-- HitType.Crit, so C# shows the crit effect on the heal
		if crit > 1 then trySet(action, "hitType", 9) end
		if hasStatus(caster, 223227) then amount = math.floor(amount * 0.8) end
	elseif params.crit then
		trySet(action, "hitType", 9)
	end
	amount = math.max(0, math.floor(amount * (params.mult or 1.0)))
	action.amount = amount
	local missing = target:GetMaxHP() - target:GetHP()
	action.enmity = math.floor(math.min(amount, math.max(missing, 0)) * F.HEAL_ENMITY * actions.enmityScale(caster, true))
	action:DoAction(caster, target, skill, container)
	return math.min(amount, math.max(missing, 0))
end

-- Abilities
function actions.statusAbility(caster, target, skill, action, container, params)
	params = params or {}
	if params.enmity then
		action.enmity = math.floor(F.fixedEnmity(params.enmity, caster:GetLevel()) * actions.enmityScale(caster))
	end
	action:DoAction(caster, target, skill, container)
end

-- Splits fixed enmity from a self-targeted action (Hallowed Ground) across every enemy that hates
-- `who`, like cure enmity. C# drops action.enmity on a non-BattleNpc target, so self-buffs add it
-- here. Returns the number of enemies that got a share.
function actions.spreadEnmity(caster, who, amount)
	local mobs = {}
	local okList, list = pcall(function() return who.CurrentArea:GetActorsAroundActor(who, 50) end)
	if not okList or list == nil then return 0 end
	for a in list do
		-- pcall per actor: non-Character actors (objects, area markers) have no IsMonster
		local ok, hates = pcall(function()
			return a:IsMonster() and a:IsAlive() and a.hateContainer ~= nil
				and a.hateContainer:HasHateForTarget(who)
		end)
		if ok and hates then mobs[#mobs + 1] = a end
	end
	if #mobs == 0 then return 0 end
	local share = math.floor(amount / #mobs)
	for _, mob in ipairs(mobs) do
		mob.hateContainer:UpdateHate(caster, share)
	end
	return #mobs
end

function actions.healAbility(caster, target, skill, action, container, amount)
	action.amount = math.max(1, math.floor(amount))
	action.enmity = math.floor(action.amount * F.HEAL_ENMITY * actions.enmityScale(caster, true))
	action:DoAction(caster, target, skill, container)
end

function actions.hatingEnemies(who)
	local mobs = {}
	local okList, list = pcall(function() return who.CurrentArea:GetActorsAroundActor(who, 50) end)
	if not okList or list == nil then return mobs end
	for a in list do
		local ok, hates = pcall(function()
			return a:IsMonster() and a:IsAlive() and a.hateContainer ~= nil
				and a.hateContainer:HasHateForTarget(who)
		end)
		if ok and hates then mobs[#mobs + 1] = a end
	end
	return mobs
end

function actions.commandTargets(skill)
	local out = {}
	local ok, list = pcall(function() return skill:GetTargets() end)
	if ok and list ~= nil then
		for t in list do out[#out + 1] = t end
	end
	return out
end

-- Enfeebles whose only job is the status (Sleep, Sleepga, Repose). The listed chance is restored
-- for the next target of an AoE.
function actions.enfeebleSpell(caster, target, skill, action, container, params)
	params = params or {}
	local listed = skill.statusChance
	if actions.isHostile(caster, target) then
		skill.statusChance = F.statusLandChance(caster, target, skill.statusId, listed, "enfeeble", params.useMacc)
	end
	if params.enmity then
		action.enmity = math.floor(F.fixedEnmity(params.enmity, caster:GetLevel()) * actions.enmityScale(caster))
	end
	action:DoAction(caster, target, skill, container)
	skill.statusChance = listed
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

return actions
