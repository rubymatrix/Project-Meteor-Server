require("BattleUtils")

--[[
Life Surge I (223215), stack 1 of 3 from ability 27262 (LNC22), 180 s. Auto-attacks absorb
10/20/30% of their damage as HP at stack I/II/III. Enhanced Life Surge (trait 27282, status
tier 2) raises the absorb by 20%.
--]]

local ABSORB = 0.10
local TRAIT_MULT = 1.2

function onHit(effect, attacker, defender, skill, action, actionContainer)
	if skill:GetCommandType() == CommandType.AutoAttack and action.amount > 0 then
		local healPercent = ABSORB

		if effect:GetTier() == 2 then
			healPercent = healPercent * TRAIT_MULT
		end

		local amount = math.floor(healPercent * action.amount)
		if amount > 0 then
			attacker:AddHP(amount)
			actionContainer:AddHPAbsorbAction(defender.Id, 30332, amount)
		end
	end
end
