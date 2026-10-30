require("Modifiers")
require("BattleUtils")

--[[
The next weaponskill drains HP equal to 75% of its damage, rounded, then the status ends.
The drain does not scale with VIT.
--]]
function onHit(effect, attacker, defender, skill, action, actionContainer)
	if skill:GetCommandType() == CommandType.Weaponskill then
		local absorbAmount = math.floor(action.amount * 0.75 + 0.5)
		attacker:AddHP(absorbAmount)
		--30332: You absorb hp from target
		actionContainer:AddHPAbsorbAction(defender.Id, 30332, absorbAmount)
		--The status is on the attacker, not the target.
		attacker.statusEffects:RemoveStatusEffect(effect, actionContainer, 30331, false)
	end
end
