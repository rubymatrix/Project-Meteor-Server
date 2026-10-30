require("Modifiers")
require("Battle/Buffs")

--[[
Physical defense +20%, +25% traited (tier 2), as a stat layer on base Defense (Battle/Buffs.lua).
Costs 28 MP per 3 s tick, 25 with the AF body; out of MP, the stance drops. Auto-attacks take the
target's affinity for the element. Needs tickMs 3000 on the status row.
--]]

local UPKEEP, UPKEEP_AF, AF_BODY, SLOT_BODY = 28, 25, 8032702, 10

function onGain(owner, effect, actionContainer)
	buffs.applyFistsOfEarth(owner, true, false, effect)
end

function onLose(owner, effect, actionContainer)
	buffs.applyFistsOfEarth(owner, false)
end

function onTick(owner, effect, actionContainer)
	local cost = UPKEEP
	local ok, af = pcall(function() return owner:HasItemEquippedInSlot(AF_BODY, SLOT_BODY) end)
	if ok and af then cost = UPKEEP_AF end
	if owner:GetMP() < cost then return 1 end   -- non-zero: StatusEffect.Update removes the stance
	owner:DelMP(cost)
	return 0
end
