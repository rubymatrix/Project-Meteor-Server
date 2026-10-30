require("Modifiers")
require("BattleUtils")

--[[
Parsimony (223233, from ability 27304): 30 s or until the next attack spell. That spell costs half
MP. When its cast completes the caster gets back 21.5% of the damage dealt to all targets as MP
(x1.25 with Enhanced Parsimony, tier 2) and the status ends. An interrupted cast keeps it.
--]]

local RETURN_RATE = 0.215
local ENHANCED_MULT = 1.25

local function isAttackSpell(skill)
	return skill:GetCommandType() == CommandType.Spell and skill:GetActionType() == ActionType.Magic
end

--skill is a per-cast clone of the command.
function onMagicCast(effect, caster, skill)
	if isAttackSpell(skill) then
		skill.mpCost = math.floor(skill.mpCost / 2)
		effect:SetExtra(0)
	end
end

function onHit(effect, attacker, defender, skill, action, actionContainer)
	if isAttackSpell(skill) then
		effect:SetExtra(effect:GetExtra() + action.amount)
	end
end

function onCommandFinish(effect, owner, skill, actionContainer)
	if isAttackSpell(skill) then
		local rate = RETURN_RATE
		if effect:GetTier() == 2 then   --set by Command/Ability/Parsimony.lua with trait 27323
			rate = rate * ENHANCED_MULT
		end

		local mpToReturn = math.ceil(rate * effect:GetExtra())
		if mpToReturn > 0 then
			owner:AddMP(mpToReturn)
			actionContainer:AddMPAbsorbAction(owner.Id, 33007, mpToReturn)
		end
		owner.statusEffects:RemoveStatusEffect(effect, actionContainer, 30331, false)
	end
end
