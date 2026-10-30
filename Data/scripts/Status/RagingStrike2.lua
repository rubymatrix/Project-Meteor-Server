require("Modifiers")
require("BattleUtils")

--[[
Raging Strike (223221, from ability 27225 ARC14): a toggle with no timer. Each Light Shot hit adds a
stack (max 3) of +5% Attack, x1.5 with Enhanced Raging Strike (tier 2); a missed physical attack
resets the stacks. Physical enmity is x1.25 while it is up. Extra = stacks, which
Command/Ability/QuellingStrike.lua reads; magnitude = the Attack currently added.
--]]

local LIGHT_SHOT = 27259
local MAX_STACKS = 3
local ATTACK_PER_STACK = 0.05
local TRAIT_MULT = 1.5
local ENMITY_MULT = 1.25

local function applyStacks(owner, effect)
	local applied = effect:GetMagnitude()
	local base = owner:GetMod(Modifier.Attack) - applied
	local pct = ATTACK_PER_STACK * effect:GetExtra()
	if effect:GetTier() == 2 then
		pct = pct * TRAIT_MULT
	end
	local amount = math.floor(base * pct)

	owner:SubtractMod(Modifier.Attack, applied)
	owner:AddMod(Modifier.Attack, amount)
	effect:SetMagnitude(amount)
end

function onGain(owner, effect, actionContainer)
	effect:SetExtra(0)
	effect:SetMagnitude(0)
end

function onLose(owner, effect, actionContainer)
	owner:SubtractMod(Modifier.Attack, effect:GetMagnitude())
end

function onHit(effect, attacker, defender, skill, action, actionContainer)
	if skill.id == LIGHT_SHOT and effect:GetExtra() < MAX_STACKS then
		effect:SetExtra(effect:GetExtra() + 1)
		applyStacks(attacker, effect)
	end
end

function onMiss(effect, attacker, defender, skill, action, actionContainer)
	if skill:GetActionType() == ActionType.Physical and effect:GetExtra() > 0 then
		effect:SetExtra(0)
		applyStacks(attacker, effect)
	end
end

function onPreAction(effect, caster, target, skill, action, actionContainer)
	if skill:GetActionType() == ActionType.Physical and action.enmity > 0 then
		action.enmity = math.floor(action.enmity * ENMITY_MULT)
	end
end
