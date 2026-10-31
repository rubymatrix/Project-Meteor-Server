require("Global")
require("Guildleve")

--[[
Journal information requests. "activegl <n>" asks for regional leve n's detail (1-based slot). The
reply echoes n, then the journal's eight detail values: allowances (Retry needs > 0), an unused value,
reward item and gil, a second reward item and count, evaluation marks, and whether it is completed.
Every value must be a number: a nil mark count is a script error in the client.
--]]

function onEventStarted(player, actor, eventType, eventName, key, index)
	if key == "activegl" then
		local slot = (tonumber(index) or 1) - 1
		local glId = (slot >= 0 and slot < 8) and player.work.guildleveId[slot] or 0
		local gil = glId ~= 0 and player:GetGuildleveRewardGil(glId) or 0
		local marks = glId ~= 0 and getGuildleveEvaluation(player, glId) or 0
		local completed = glId ~= 0 and player:HasCompletedGuildleve(glId) or false
		player:SendDataPacket("requestedData", "activegl", tonumber(index) or 1, player:GetLeveAllowances(), 0, 1000001, gil, 0, 0, marks, completed)
	end
end
