require("Global")

properties = {
	permissions = 0,
	parameters = "s",
	description = "Adds a quest by <id>.",
}

function onTrigger(player, argc, glId)
	if player then
		local glIdAsNumber = tonumber(glId)

		if glIdAsNumber == nil then
			player:AddQuest(glId)
		else
			player:AddQuest(glIdAsNumber)
		end
	else
		print(sender.."unable to add guildleve, ensure player name is valid.")
	end
end