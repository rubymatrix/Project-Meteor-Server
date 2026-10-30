require("Global")

properties = {
	permissions = 0,
	parameters = "",
	description = "shows the navmesh under you: ground height, how far above it you are, and which connected island",
}

function onTrigger(player)
	local pos = player:GetPos()
	local message = player.CurrentArea:DescribeNavMesh(pos[0], pos[1], pos[2])

	player:SendMessage(MESSAGE_TYPE_SYSTEM_ERROR, "[navinfo] ", message)
end
