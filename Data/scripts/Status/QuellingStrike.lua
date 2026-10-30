require("Modifiers")
require("BattleUtils")

--[[
Quelling Strike (223104, from ability 27221 ARC22): the next weaponskill, spell or physical ability
gets enmity x0.8 and its TP cost lowered by the magnitude (set by Command/Ability/QuellingStrike.lua),
then the status ends. A free attack like Light Shot gains the TP outright. Auto-attacks never
consume it.
--]]

local ENMITY_MULT = 0.8

local function isAttack(skill)
	local t = skill:GetCommandType()
	local a = skill:GetActionType()
	return (t == CommandType.Weaponskill or t == CommandType.Ability or t == CommandType.Spell)
		and (a == ActionType.Physical or a == ActionType.Magic)
end

function onCommandStart(effect, owner, skill, actionContainer)
	if isAttack(skill) then
		skill.enmityModifier = skill.enmityModifier * ENMITY_MULT
		skill.tpCost = skill.tpCost - effect:GetMagnitude()
		owner.statusEffects:RemoveStatusEffect(effect, actionContainer, 30331, false)
	end
end
