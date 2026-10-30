require("Modifiers")
require("Utils")

--[[
Aegis Boon: the next attack is fully blocked and heals the defender for 2.5x the blocked
amount, capped at 703. The status ends on that hit.
--]]

function onPreAction(effect, caster, target, skill, action, actionContainer)
	action.blockRate = 100.0
	pcall(function() action.blockReduction = 1.0 end)
end

function onBlock(effect, attacker, defender, skill, action, actionContainer)
	local absorbAmount = math.min(math.floor(action.amountMitigated * 2.5), 703)
	--33008: You recover x HP from Aegis Boon
	defender:AddHP(absorbAmount)
	actionContainer:AddHPAction(defender.Id, 33008, absorbAmount)
	defender.statusEffects:RemoveStatusEffect(effect, actionContainer)
end
