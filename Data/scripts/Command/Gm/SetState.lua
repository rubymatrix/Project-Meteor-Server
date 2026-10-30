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

function onTrigger(player, argc, state)
	local messageID = MESSAGE_TYPE_SYSTEM_ERROR
	local sender = "[setstate] "

	local s = tonumber(state)
	local actor = player.CurrentArea:FindActorInArea(player.currentTarget) or nil
	if player and actor then
		actor:ChangeState(s)
		wait(0.8)
		player:SendMessage(0x20, "", "state: "..s)
	else
		player:SendMessage(0x20, "", "Error: No target selected.")
	end
end