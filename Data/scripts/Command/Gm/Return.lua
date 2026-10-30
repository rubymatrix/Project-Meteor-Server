require("Global")
require("Aetheryte")
require("Utils")

properties = {
	permissions = 0,
	parameters = "sss",
	description =
[[
Revives a stuck or KO'd character at full HP and returns them to their home point.
!return |
!return here |  (revive in place, no teleport)
!return <firstname> <lastname> |
]],
}

function onTrigger(player, argc, mode, name, lastName)
	local sender = "[return] "
	if mode ~= nil and mode ~= "here" then
		local target = GetWorldManager():GetPCInWorld(name ~= nil and (mode .. " " .. name) or mode)
		if target == nil then
			player:SendMessage(MESSAGE_TYPE_SYSTEM_ERROR, sender, "No player named " .. mode .. (name and (" " .. name) or "") .. ".")
			return
		end
		player = target
		mode = nil
	end

	if player:IsDead() or player:GetHP() == 0 then
		player:Revive(100)
		player:PlayAnimation(0x01000066)
	end

	if mode == "here" then
		player:SendMessage(MESSAGE_TYPE_SYSTEM, sender, "Revived in place.")
		return
	end

	local destination = aetheryteTeleportPositions[player:GetHomePoint()]
	if destination == nil then
		player:SendMessage(MESSAGE_TYPE_SYSTEM_ERROR, sender, "No home point set; revived in place.")
		return
	end
	local randoPos = getRandomPointInBand(destination[2], destination[4], 3, 5)
	local rotation = getAngleFacing(randoPos.x, randoPos.y, destination[2], destination[4])
	GetWorldManager():DoZoneChange(player, destination[1], nil, 0, 2, randoPos.x, destination[3], randoPos.y, rotation)
end
