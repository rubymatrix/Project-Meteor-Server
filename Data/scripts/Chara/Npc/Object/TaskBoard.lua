require("Global")

--[[
Task Board in each Adventurers' Guild: lists what each crafting and gathering guild wants turned in.
Its event calls go through the Noc000 static actor. Client event functions:
Data/Docs/Scripts/Chara/Npc/Object/TaskBoard.md.
--]]

local guildItem = {
	-- [guildId] = { (recommendedLvl itemId, hq, amount, 2nd-recommendedLvl 2nd-itemId, 2nd-hq, 2nd-amount) }
	[29] = {1, 4100604, 1, 1, 10, 4030706, 1, 1}, -- Carpenters'
	[30] = {1, 4040004, 1, 1, 10, 4030004, 1, 1}, -- Blacksmiths'
	[31] = {1, 6080009, 1, 1, 10, 8070606, 1, 1}, -- Armorers'
	[32] = {1, 5020007, 1, 1, 10,10004103, 1, 1}, -- Goldsmiths'
	[33] = {1, 4020107, 1, 1, 10, 8031514, 1, 1}, -- Leatherworkers'
	[34] = {1, 8030819, 1, 1, 10, 8030821, 1, 1}, -- Weavers'
	[35] = {1, 3011530, 1,12, 10, 3020527, 1, 4}, -- Alchemists'
	[36] = {1, 3010103, 1, 6, 10, 3011503, 1, 6}, -- Culinarians'
	[39] = {1,10009101, 1,10, 10,10001116, 1,10}, -- Miners'
	[40] = {1,10005403, 1,10, 10,10008106, 1,10}, -- Botanists'
	[41] = {1, 3011106, 1,10, 10, 3011113, 1,10}  -- Fishermans'
}

local menuToGuild = {          -- Get a guild id from a given task board's Return result
	[1] = {0, 30, 31, 36, 41}, -- Limsa
	[2] = {0, 29, 33, 40,  0}, -- Gridania
	[3] = {0, 32, 34, 35, 39}  -- Ul'dah
}

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, npc, triggerName)

	local questNoc = GetStaticActor("Noc000")
	local npcId = npc:GetActorClassId()

	while true do
		local guildId = 0

		if npcId == 1200193 then -- Limsa
			local choice = callClientFunction(player, "delegateEvent", player, questNoc, "pETaskBoardAskLimsa")

			if choice == 1 or choice == nil then
				break -- Exited menu
			else
				guildId = menuToGuild[1][choice]
			end
		elseif npcId == 1200194 then -- Ul'dah
			local choice = callClientFunction(player, "delegateEvent", player, questNoc, "pETaskBoardAskUldah")

			if choice == 1 or choice == nil then
				break -- Exited menu
			else
				guildId = menuToGuild[3][choice]
			end
		else -- Gridania
			local choice = callClientFunction(player, "delegateEvent", player, questNoc, "pETaskBoardAskGridania")

			if choice == 1 or choice == nil then
				break -- Exited menu
			else
				guildId = menuToGuild[2][choice]
			end
		end

		if guildId > 0 then
			callClientFunction(player, "delegateEvent", player, questNoc, "pETaskBoardGuild", guildId)
			local gItem = guildItem[guildId]
			callClientFunction(player, "delegateEvent", player, questNoc, "pETaskBoardOrder", unpack(gItem, 1, 4))
			callClientFunction(player, "delegateEvent", player, questNoc, "pETaskBoardOrder", unpack(gItem, 5, 8))
		end
	end

	player:EndEvent()
end
