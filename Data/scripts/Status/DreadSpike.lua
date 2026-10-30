require("Modifiers")
require("BattleUtils")

-- Nullifies a physical action, even its damage message (the "used" message still shows), and absorbs
-- half the damage it would have done, all of it at tier 2. Multi-hit attacks and Stoneskin are untested.
function onDamageTaken(effect, attacker, defender, skill, action, actionContainer)
	if skill:GetActionType() == ActionType.Physical then
		local absorbPercent = 0.5

		if effect:GetTier() == 2 then
			absorbPercent = 1
		end

		local absorbAmount = action.amount * absorbPercent
		action.amount = 0
		action.worldMasterTextId = 0

		defender:AddHP(absorbAmount)
		--30451: You recover [absorbAmount] HP.
		actionContainer:AddHPAction(defender.Id, 30451, absorbAmount)
		--Dread Spike is lost after absorbing hp
		defender.statusEffects:RemoveStatusEffect(effect, actionContainer, 30331, false)
	end
end