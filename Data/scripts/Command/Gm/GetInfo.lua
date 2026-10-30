require("Global")

properties = {
	permissions = 0,
	parameters = "ssss",
	description =
[[
Gets the info about the current target
]],
}

function onTrigger(player)

	local messageID = MESSAGE_TYPE_SYSTEM_ERROR
	local sender = "[Info] "

	local targetActor = player.CurrentArea:FindActorInArea(player.currentTarget) or nil

	if not targetActor then
		player:SendMessage(messageID, sender, "No target selected")
		return
	end


	player:SendMessage(messageID, sender, string.format("Position (XYZ-O): %.3f, %.3f, %.3f - %.3f", targetActor.positionX, targetActor.positionY, targetActor.positionZ, targetActor.rotation))
	player:SendMessage(messageID, sender, string.format("Actor ID: 0x%X", targetActor.Id))
	player:SendMessage(messageID, sender, string.format("Class Name: %s", targetActor.className))
	player:SendMessage(messageID, sender, string.format("Class ID: %d", targetActor:GetActorClassId()))
end