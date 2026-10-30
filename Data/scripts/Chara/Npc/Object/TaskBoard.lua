require("Global")

--[[

TaskBoard

Operates the Task Board actor located in each of the Adventurers' Guilds.
Calls from the Noc000 static actor, which also applies to specific guild NPCs involved in that as well.

Functions:  (only including those from Noc000 which apply to the Task Board)

pETaskBoardAskLimsa()
    Desc: Show guild menu with valid options for Limsa Lominsa.
    Params: None
    Returns: Value dictating which item on the list was selected.

pETaskBoardAskUldah()
    Desc: Show guild menu with valid options for Ul'dah.
    Params: None
    Returns: Value dictating which item on the list was selected.

pETaskBoardAskGridania()
    Desc: Show guild menu with valid options for Gridania.
    Params: None
    Returns: Value dictating which item on the list was selected.

pETaskBoardGuild(guildId)
    Desc: Plays back a message "The following tasks are available:".
    Params: * guildId 			- Class Id from xtx_text_jobName.  EN doesn't make use of it, but JP/DE/FR do.  Thanks Koji.
    
pETaskBoardOrder(recommendedLvl itemId, hq, amount)
    Desc: Takes the params and tells the player what the guild still needs turned in.
    Params: * recommendedLvl 	- Recommended level the player be at
            * itemId  			- Id of the item from xtx_itemName
            * hq     			- Quality of item (1 = NQ, 2 = +1, 3 = +2 4 = +3)
            * amount 			- Amount needed (The amount the player needs to turn-in, not the amount guild needs overall)

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
