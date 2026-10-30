require("Modifiers")
require("BattleUtils")

--This is the untraited version of decoy.
function onPreAction(effect, caster, target, skill, action, actionContainer)
	--Evade single ranged or magic attack
	--Traited allows for physical attacks
	if target.allegiance ~= caster.allegiance and (skill.isRanged or skill:GetActionType() == ActionType.Magic) then
		--Unsure if decoy forces a miss/resist or if this is the one case where the evade hittype is used
		action.hitRate = 0.0
		action.resistRate = 750
		target.statusEffects:RemoveStatusEffect(effect, actionContainer, 30331, false)
	end

end