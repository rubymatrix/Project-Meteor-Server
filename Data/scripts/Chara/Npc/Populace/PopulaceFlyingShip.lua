--[[

PopulaceFlyingShip Script

Functions:

eventIn(player, hasTicket, nil?, travelPrice) - If hasTicket == nil, say no money text.
eventOut(isAborting) - Set isAborting to 30010 if player didn't "use" the airship. Shows no refund warning.
eventNG(player) - Message said when player is talking to the wrong npc.

--]]

require("Global")

local addPlayerToAirship

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, npc, triggerName)

	-- Special case for A Slippery Stone and Cutthroat Prices
	if player:HasQuest(110737) == true then
		require("Quest/Etc/Etc3g3")
		local quest = player:GetQuest("Etc3g3")
		if quest:GetSequence() == SEQ_000 then
			local choice = callClientFunction(player, "delegateEvent", player, quest, "processEvent_005")
			if choice == 1 then
				quest:StartSequence(SEQ_001)
				addPlayerToAirship(player, 2)
			end
			player:EndEvent()
			return
		end
	elseif player:HasQuest(110728) == true then
		require("Quest/Etc/Etc3u3")
		local quest = player:GetQuest("Etc3u3")
		if quest:GetSequence() == SEQ_000 then
			local choice = callClientFunction(player, "delegateEvent", player, quest, "processEvent_005")
			if choice == 1 then
				quest:StartSequence(SEQ_001)
				addPlayerToAirship(player, 3)
			end
			player:EndEvent()
			return
		end
	end

	-- Otherwise normal operation
	callClientFunction(player, "eventIn", player, false, nil, 5)

	player:EndEvent()
end

function addPlayerToAirship(player, city)
	if city == 1 then
		-- Limsa Airship
		GetWorldManager():WarpToPosition(player, -764.519, -3.146, 384.154, 1.575)
		--GetWorldManager():AddPlayerToShipList(player, 2);
	elseif city == 2 then
		-- Gridania Airship
		GetWorldManager():WarpToPosition(player, 54.47, -7, -1198.54, -0.02)
		--GetWorldManager():AddPlayerToShipList(player, 3);
	elseif city == 3 then
		-- Ul'dah Airship
		GetWorldManager():WarpToPosition(player, -126.580, 271.2, 156.435, -1.35)
		--GetWorldManager():AddPlayerToShipList(player, 4);
	end
end