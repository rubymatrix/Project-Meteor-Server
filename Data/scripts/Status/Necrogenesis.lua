require("Modifiers")
require("BattleUtils")

--[[
Necrogenesis (223232, from ability 27303): 30 s or until the next attack spell. The first hit of
that spell heals the caster 28% of its damage, once, and the status ends.
--]]

local HEAL_RATE = 0.28

function onHit(effect, attacker, defender, skill, action, actionContainer)
	if skill:GetCommandType() == CommandType.Spell and effect:GetExtra() == 0 then
		effect:SetExtra(1)
		local hpToReturn = math.floor(HEAL_RATE * action.amount)
		if hpToReturn > 0 then
			attacker:AddHP(hpToReturn)
			actionContainer:AddHPAbsorbAction(defender.Id, 33012, hpToReturn)
		end
		attacker.statusEffects:RemoveStatusEffect(effect, actionContainer, 30331, false)
	end
end
