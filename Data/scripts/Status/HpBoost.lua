require("Battle/Buffs")

--[[
Battle Voice grants it to party members in range. Max HP +25%, as a stat layer on base max HP
(Battle/Buffs.lua) so it stays right when max HP changes while it is on.
--]]

function onGain(owner, effect, actionContainer)
	buffs.applyHpBoost(owner, true)
end

function onLose(owner, effect, actionContainer)
	buffs.applyHpBoost(owner, false)
end
