require("Global")

local addQuest, removeQuest, setQuestCompletion, setQuestSequence, setQuestFlag, setQuestCounter, getQuestInfo

properties = {
	permissions = 0,
	parameters = "ssss",
	description =
[[
Add/Remove/Complete Quests, modify <sequence> and <flag 0-32>.
!quest <quest> <add/remove> <#> |
!quest <quest> <sequence> <#> |
!quest <quest> <flag> <#> true/false |
]],
}

function onTrigger(player, argc, quest, command, var1, var2)

	local messageID = MESSAGE_TYPE_SYSTEM_ERROR
	local sender = "[quest] "
	local message = "Error"

	if type(tonumber(quest)) == "number" then
		local questId = tonumber(quest)
		if (questId < 110001 or questId > 110001 + 2048) and player then
			player:SendMessage(messageID, sender, "Invalid questId entered")
			player:SendMessage(messageID, sender, argc)
			return
		else
			if command == "add" or command == "give" or command == "+" then
				message = addQuest(player, questId)
			elseif command == "remove" or command == "delete" or command == "-" then
				message = removeQuest(player, questId)
			elseif command == "complete" or command == "completed" or command == "finish" then
				message = setQuestCompletion(player, argc, questId, var1)
			elseif command == "info" then
				message = getQuestInfo(player, questId)
			elseif command == "seq" or command == "sequence" then
				message = setQuestSequence(player, questId, tonumber(var1))
			elseif command == "flag" then
				message = setQuestFlag(player, questId, var1, var2)
			elseif command == "counter" or command == "count" then
				message = setQuestCounter(player, questId, var1, var2)
			else
				message = ("Error: Command "..command.." not recognized")
			end
		end
	elseif quest == "update" then
		player:ForceQuestStateUpdate()
		message = ("Forcing QuestState update...")
	else
		message = ("Error: Quest id must be a valid number.")
	end

	player:SendMessage(messageID, sender, message)
end



function addQuest(player, questId)
	if not (player:HasQuest(questId)) then
		player:AddQuest(questId)
		return string.format("Adding quest "..player:GetQuest(questId).name.." ["..questId.."]")
	else
		return string.format("Already have quest "..player:GetQuest(questId).name.." ["..questId.."]")
	end
end

function removeQuest(player, questId)
	if player:HasQuest(questId) then
		local questName = player:GetQuest(questId).name
		player:RemoveQuest(questId)
		return string.format("Removing quest "..questName.." ["..questId.."]")
	else
		return string.format("Error: Either incorrect ID or quest "..questId.." isn't active on character.")
	end
end

function setQuestCompletion(player, argc, questId, flag)

	if argc == 2 then -- No flag entered -> Return state of the quest's completion.
		return string.format("Quest %d completion is set to: %s", questId, tostring(player:IsQuestCompleted(questId)))
	else
		local boolFlag = false

		if flag == "true" or flag == "1" or flag == "on" or flag == "O" then
			boolFlag = true
		elseif flag == "false" or flag == "0" or flag == "off" or flag == "X" then
			boolFlag = false
		elseif flag == "flip" or flag == "toggle" then
			boolFlag = not player:IsQuestCompleted(questId)
		else -- A catch for bad inputs
			return string.format("Error: Invalid flag entered")
		end

		player:SetQuestComplete(questId, boolFlag)
		return string.format("Quest %d completion set to: %s", questId, tostring(player:IsQuestCompleted(questId)))

	end
end

function setQuestSequence(player, questId, sequence)
	if type(sequence) == "number" then
		if player:HasQuest(questId) then
			local seq = math.floor(tonumber(sequence))
			if seq >= 0 and seq <= 65535 then
				player:GetQuest(questId):StartSequence(seq)
				return string.format("Changing sequence of quest "..player:GetQuest(questId).name.." ["..questId.."] to "..seq)
			else
				return string.format("Error: Sequence value must be within 0-65535.")
			end
		else
			return string.format("Sequence error: either incorrect ID or quest "..questId.." isn't active on character")
		end
	else
		return string.format("Error: Sequence value must be a valid number.")
	end
end

function setQuestFlag(player, questId, flagNum, flagCmd)
	local questvar = questId
	local flagvar = tonumber(flagNum)
	local boolvar = 0

	if player:HasQuest(questvar) then
		if flagvar >= 0 and flagvar <= 31 then

			if flagCmd == "true" or flagCmd == "1" or flagCmd == "on" or flagCmd == "O" then
				boolvar = true
			elseif flagCmd == "false" or flagCmd == "0" or flagCmd == "off" or flagCmd == "X" then
				boolvar = false
			elseif flagCmd == "flip" or flagCmd == "toggle" then
				boolvar = not player:GetQuest(questvar):GetData():GetFlag(flagvar)
			else
				return "Error: Flag: Boolean not recognized."
			end

			currentFlagState =  player:GetQuest(questvar):GetData():GetFlag(flagvar)

			if currentFlagState ~= boolvar then

				if boolvar == true then
					player:GetQuest(questvar):GetData():SetFlag(flagvar)
				else
					player:GetQuest(questvar):GetData():ClearFlag(flagvar)
				end
				player:GetQuest(questvar):UpdateENPCs()
				player:GetQuest(questvar):GetData():Save()
				if boolvar == true then
					return string.format("Changing flag "..tonumber(flagNum).." to true on quest "..questvar)
				else
					return string.format("Changing flag "..tonumber(flagNum).." to false on quest "..questvar)
				end
			else
				return string.format("Error: Flag "..flagvar.." is already set to that state on quest "..questvar)
			end
		else
			return string.format("Error: Flag "..flagNum.." is not within the valid range of 0-31.")
		end
	else
		return string.format("Error: Either incorrect ID or quest "..tostring(questId).." isn't active on character.")
	end

end

function setQuestCounter(player, questId, counterSlot, counterValue)
	local cSlot = tonumber(counterSlot) or nil
	local cVal = tonumber(counterValue) or nil

	if cSlot ~= nil and cSlot >= 0 and cSlot <= 3 then
		if cVal ~= nil and cVal >= 0 and cVal <= 255 then
			player:GetQuest(questId):GetData():SetCounter(cSlot, cVal)
			player:GetQuest(questId):UpdateENPCs()
			player:GetQuest(questId):GetData():Save()

			return string.format("Changing counter "..cSlot.." to "..cVal)
		else
			return string.format("Error: Invalid counter value.  Must be between 0-255.")
		end
	else
		return string.format("Error: Invalid counter index.  Must be between 0-3.")
	end
end


function getQuestInfo(player, questId)
	if player:HasQuest(questId) then
		quest = player:GetQuest(questId)

		local msg = ""
		local flagStr = ""

		for i=0,31,1 do
			if quest:GetData():GetFlag(i) then
				flagStr = flagStr .. "O"
			else
				flagStr = flagStr .. "X"
			end
			if i == 15 then
				flagStr = flagStr .. "\n"
			end
		end

		local data = quest:GetData()

		msg = string.format("Info for quest %s [%d]\n", quest.Name, quest:GetQuestId())
		msg = msg .. string.format("Flags \\\\ Current Sequence: %d\n", quest:GetSequence())
		msg = msg .. string.format("%s\n", flagStr)
		msg = msg .. string.format("Counters: %d,%d,%d,%d", data:GetCounter(0), data:GetCounter(1), data:GetCounter(2), data:GetCounter(3))
		return msg
	else
		return string.format("Quest not active: "..questId)
	end
end


