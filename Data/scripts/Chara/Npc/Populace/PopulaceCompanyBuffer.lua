require("Global")

--[[
Grand Company representative who grants Sanction. The buff itself is not applied yet.
--]]

function init(npc)
	return false, false, 0, 0
end

local gcRep = {
	[1500388] = 1, -- Maelstrom Representative
	[1500389] = 2, -- Adder Representative
	[1500390] = 3, -- Flame Representative
}

function onEventStarted(player, npc, triggerName)
	local playerGc = player.gcCurrent
	local playerGcRanks = {player.gcRankLimsa, player.gcRankGridania, player.gcRankUldah}

	local choice = callClientFunction(player, "eventTalkWelcome", player, true)

	if choice == 1 and playerGcRanks[playerGc] > 10 and playerGcRanks[playerGc] < 112 then
		callClientFunction(player, "eventTalkBufEffect")
		callClientFunction(player, "eventTalkBufEffectAfter", player)
		-- TODO: Add Sanction buff
	else
		player:SendMessage(0x20, "", "Quit hex editing your memory.")
	end

	callClientFunction(player, "eventTalkStepBreak")
	player:EndEvent()
end

