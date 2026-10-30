--[[
Party-size bonus statuses: Comradery for a light party (4 to 7), Strength in Numbers for a full
party (8). Player.UpdatePartyBonus grants and removes them and counts only members within +5/-10
levels. Each bonus is a stat layer, so re-applying can't stack it.
--]]
require("Modifiers")
require("Battle/Statlayers")

partybonus = partybonus or {}

local M = Modifier

partybonus.COMRADERY = 223193
partybonus.STRENGTH_IN_NUMBERS = 223194
-- Strength in Numbers accuracy is 0.12, not 0.20: at 0.20 a full Lv50 party hit a Lv58 boss
-- almost every time.
partybonus.SIZES = {
	comradery           = { [M.Hp] = 0.05, [M.Mp] = 0.05, [M.Accuracy] = 0.10, [M.MagicAccuracy] = 0.05 },
	strength_in_numbers = { [M.Hp] = 0.10, [M.Mp] = 0.10, [M.Accuracy] = 0.12, [M.MagicAccuracy] = 0.10 },
}

-- Inside onCalculateBaseStats (fromStats) C# copies hpMax/mpMax itself, so no sync.
function partybonus.apply(owner, which, on, fromStats)
	local layer = "status:" .. which
	for mod, pct in pairs(partybonus.SIZES[which]) do
		statlayers.set(owner, layer, mod, on and pct or 0)
	end
	if not fromStats then statlayers.syncPools(owner) end
end

statlayers.register(partybonus.COMRADERY, function(owner, on, fromStats)
	partybonus.apply(owner, "comradery", on, fromStats)
end)
statlayers.register(partybonus.STRENGTH_IN_NUMBERS, function(owner, on, fromStats)
	partybonus.apply(owner, "strength_in_numbers", on, fromStats)
end)
