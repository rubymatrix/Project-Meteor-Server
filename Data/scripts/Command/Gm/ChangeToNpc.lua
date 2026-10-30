require("Global")

properties = {
	permissions = 0,
	parameters = "",
	description =
[[
Changes appearance for equipment with given parameters.
!graphic <slot> <wID> <eID> <vID> <vID>
]],
}

function onTrigger(player, argc)
	local messageId = MESSAGE_TYPE_SYSTEM_ERROR
	local sender = "[changetonpc] "

	local npc = player.CurrentArea:FindActorInArea(player.currentTarget)

	if npc then
		player:ChangeIntoNpc(npc)
	end

end