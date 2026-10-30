require("Modifiers")
require("BattleUtils")

--[[
Provoke adds it once Enhanced Provoke is learned: the owner's physical damage x0.9 for 30 s.
It scales the hit, not the Attack mod, because monster damage does not read Attack
(formulas.physicalStatRatio returns 1 for non-players). Needs status row 223034, flags 8213.
--]]

local DAMAGE_MULT = 0.9

function onPreAction(effect, caster, target, skill, action, actionContainer)
	local physical = (skill == nil) or skill:GetActionType() == ActionType.Physical
	if physical and action.amount > 0 then
		action.amount = math.max(1, math.floor(action.amount * DAMAGE_MULT))
	end
end
