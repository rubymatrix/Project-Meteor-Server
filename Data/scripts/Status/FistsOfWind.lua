require("Modifiers")
require("Battle/Statlayers")
require("BattleUtils")

--[[

Fists of Wind

Weaponskill recast -20%, set in onCommandStart before Character.DoBattleCommand starts the recast.
The AF bonus and the movement speed bonus are not applied. Costs 28 MP per 3 s tick, 25 with the
AF body; out of MP, the stance drops. Needs tickMs 3000 on the status row.

--]]

local UPKEEP, UPKEEP_AF, AF_BODY, SLOT_BODY = 28, 25, 8032702, 10

function onCommandStart(effect, owner, command, actionContainer)
	if command:GetCommandType() == CommandType.Weaponskill then
		command.recastTimeMs = math.floor(command.recastTimeMs * 0.8)
	end
end

function onGain(owner, effect, actionContainer)
end

function onLose(owner, effect, actionContainer)
end

function onTick(owner, effect, actionContainer)
	local cost = UPKEEP
	local ok, af = pcall(function() return owner:HasItemEquippedInSlot(AF_BODY, SLOT_BODY) end)
	if ok and af then cost = UPKEEP_AF end
	if owner:GetMP() < cost then return 1 end   -- non-zero: StatusEffect.Update removes the stance
	owner:DelMP(cost)
	return 0
end
