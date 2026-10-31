require("Global")
require("Guildleve")

--[[
Journal requests. "activegl <n>": regional leve n's detail; the reply echoes n, then eight numbers
(allowances for Retry, unused, reward item and gil, second item and count, marks, completed). A nil
mark count is a client script error. "glHist": the Levequest History, the last eight completed leves.
--]]

function onEventStarted(player, actor, eventType, eventName, key, index)
	if key == "activegl" then
		local slot = (tonumber(index) or 1) - 1
		local glId = (slot >= 0 and slot < 8) and player.work.guildleveId[slot] or 0
		local gil = glId ~= 0 and player:GetGuildleveRewardGil(glId) or 0
		local marks = glId ~= 0 and getGuildleveEvaluation(player, glId) or 0
		local completed = glId ~= 0 and player:HasCompletedGuildleve(glId) or false
		player:SendDataPacket("requestedData", "activegl", tonumber(index) or 1, player:GetLeveAllowances(), 0, 1000001, gil, 0, 0, marks, completed)
	elseif key == "glHist" then
		player:SendGuildleveHistory(tonumber(index) or 0)
	end
end
