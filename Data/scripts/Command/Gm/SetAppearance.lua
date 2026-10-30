require("Global")

properties = {
	permissions = 0,
	parameters = "s",
	description =
[[
Changes appearance for equipment with given parameters.
!graphic <slot> <wID> <eID> <vID> <vID>
]],
}

function onTrigger(player, argc, actorClassId)
	local messageID = MESSAGE_TYPE_SYSTEM_ERROR
	local sender = "[setappearance] "

	local actorClassId = tonumber(actorClassId) or 0
	player:SendMessage(messageID, sender,  string.format("appearance %u", actorClassId))

	local actor = player.CurrentArea:FindActorInArea(player.currentTarget)

	if actor then
		actor:ChangeNpcAppearance(actorClassId)
		player:SendMessage(messageID, sender,  string.format("appearance %u", actorClassId))
	end
end