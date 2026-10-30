--[[

ObjectEventDoor Script

Functions:

eventDoorMoveAsk() - Shows confirm to move into event

--]]

require("Global")

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, npc, triggerName)
	local choice = callClientFunction(player, "eventDoorMoveAsk")

	if choice == 1 then
		local activeQuests = arrayToTable(player:GetQuestsForNpc(npc))
		-- Either let the player choose the quest or start it if it's the only one.
		local chosenQuest

		if #activeQuests > 1 then
			local currentPage = 0
			local numPages = math.floor((#activeQuests-1)/4) + 1

			while true do
				local page, index = callClientFunction(player, "switchEvent", activeQuests[currentPage * 4 + 1], activeQuests[currentPage * 4 + 2], activeQuests[currentPage * 4 + 3], activeQuests[currentPage * 4 + 4], currentPage + 1, numPages, 0x3F1)

				if page == 0 then
					chosenQuest = activeQuests[(currentPage * 4) + index]
					break
				elseif page > 0 then
					currentPage = page - 1
				else
					player:EndEvent()
					return
				end
			end
		elseif #activeQuests == 1 then
			chosenQuest = activeQuests[1]
		end

		if chosenQuest ~= nil then
			chosenQuest:OnPush(player, npc, eventName)
			return
		else
			local msg = string.format("ERROR: This ObjectEventDoor has no quest set. \nActor Class Id: %s\nEvent Name: %s", tostring(npc:GetActorClassId()), eventName)
			printf(msg)
			player:SendMessage(0x20, "", msg)
			player:EndEvent()
		end
	end

	player:EndEvent()
end