require("Global")

properties = {
	permissions = 0,
	parameters = "dd",
	description =
[[
Sets if a quest is completed.
!completedQuest <questId> true/false
]],
}

function onTrigger(player, argc, questId, flag)

		print("HEY")
	local messageId = MESSAGE_TYPE_SYSTEM_ERROR
	local sender = "[completedQuest] "
	local message = "Error"

	if argc < 1 then
		return
	end

	local questId = tonumber(questId)
	local flag = flag or nil

	-- Fail if not valid questId
	if questId < 110001 or questId > 110001 + 2048 then
		player:SendMessage(messageId, sender, "Invalid questId entered")
		return
	end

	-- Getting
	if arc == 1 then
		player:SendMessage(messageId, sender, string.format("Quest %d completion is set to: %s", questId, tostring(player:IsQuestCompleted(questId))))
		return
	-- Setting
	else
		-- Fail if not valid flag
		if not flag == nil then
			player:SendMessage(messageId, sender, "Invalid flag entered")
		else
			local boolFlag = false

			if flag == "true" or flag == "1" or flag == "on" or flag == "O" then
				boolFlag = true
			elseif flag == "false" or flag == "0" or flag == "off" or flag == "X" then
				boolFlag = false
			elseif flag == "flip" or flag == "toggle" then
				boolFlag = not player:IsQuestCompleted(questId)
			end

			player:SetQuestComplete(questId, boolFlag)
			player:SendMessage(messageId, sender, string.format("Quest %d completion set to: %s", questId, tostring(player:IsQuestCompleted(questId))))
			return
		end
	end
end