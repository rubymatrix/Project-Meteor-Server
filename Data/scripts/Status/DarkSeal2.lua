require("Modifiers")
require("BattleUtils")

--[[
Dark Seal. The next spell gets +50 skill.accuracyModifier, which Battle/Actions.lua attackSpell turns
into -12.5 resist-rate points (0.25 per point, as physical hit rate).
--]]
function onCommandStart(effect, owner, skill, actionContainer)
	if skill:GetActionType() == ActionType.Magic then
		-- 50 is a guess.
		skill.accuracyModifier = skill.accuracyModifier + 50
		owner.statusEffects:RemoveStatusEffect(effect, actionContainer, 30331, false)
	end
end