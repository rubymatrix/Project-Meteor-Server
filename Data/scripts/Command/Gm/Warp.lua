require("Global")

local applyPositionOffset

properties = {
	permissions = 0,
	parameters = "sssssss",
	description =
[[
Warp player or <targetname> to a location from a list, or enter a zoneID with coordinates.
!warp <spawn list> |
!warp <zone> <x> <y> <z> |
!warp <zone> <x> <y> <z> <privateArea> <targetname> |
]],
}

function onTrigger(player, argc, p1, p2, p3, p4, privateArea, privateAreaType, name, lastName)

	if name then
		if lastName then
			player = GetWorldManager():GetPCInWorld(name.." "..lastName) or nil
		else
			player = GetWorldManager():GetPCInWorld(name) or nil
		end
	end

	if not player then
		printf("[Command] [warp] error! No target or player specified!")
		return
	end

	local messageId = MESSAGE_TYPE_SYSTEM_ERROR
	local sender = "[warp] "

	-- we're getting a list/array from c# so 0 index
	local pos = player:GetPos()
	local playerX = pos[0]
	local playerY = pos[1]
	local playerZ = pos[2]
	local playerRot = pos[3]
	local playerZone = pos[4]

	local worldManager = GetWorldManager()
	privateAreaType = privateAreaType or 0

	if argc >= 3 then

		if argc == 3 then
			local x = tonumber(applyPositionOffset(p1, playerX)) or playerX
			local y = tonumber(applyPositionOffset(p2, playerY)) or playerY
			local z = tonumber(applyPositionOffset(p3, playerZ)) or playerZ

			player:SendMessage(messageId, sender, string.format("setting coordinates X:%d Y:%d Z:%d within current zone (%d)", x, y, z, playerZone))

			worldManager:DoPlayerMoveInZone(player, x, y, z, playerRot, 0x00)
		else
			local zone = tonumber(applyPositionOffset(p1, playerZone)) or playerZone
			local x = tonumber(applyPositionOffset(p2, playerX)) or playerX
			local y = tonumber(applyPositionOffset(p3, playerY)) or playerY
			local z = tonumber(applyPositionOffset(p4, playerZ)) or playerZ
			if privateArea == nil then privateArea = nil end
			if privateAreaType == nila then privateAreaType = 0 end
			player:SendMessage(messageId, sender, string.format("setting coordinates X:%d Y:%d Z:%d to new zone (%d) private area:%s", x, y, z, zone, privateArea or "unspecified"))
			worldManager:DoZoneChange(player, zone, privateArea, tonumber(privateAreaType), 0x02, x, y, z, 0.00)
		end

	elseif argc == 1 then -- Switch city zone

		local commands = { ["SWITCH"] = 1, ["S"] = 1, ["FLIP"] = 1, ["F"] = 1, ["TOWN"] = 1}

		if commands[string.upper(p1)] then
			local zones = {
						[133] = {133, 230},
						[155] = {155, 206},
						[175] = {175, 209},
						[206] = {206, 155},
						[209] = {209, 175},
						[230] = {230, 133}
						}

			if playerZone == zones[playerZone][1] then
				worldManager:DoZoneChange(player, zones[playerZone][2], "", 0, 0x16, playerX, playerY, playerZ, playerRot)
				player:SendMessage(messageId, sender, string.format("setting coordinates X:%d Y:%d Z:%d to new zone (%d) private area:%s", playerX, playerY, playerZ, zones[playerZone][2], privateArea or "unspecified"))
			end
		else
			player:SendMessage(messageId, sender, "Unknown parameters! Usage: "..properties.description)
		end
	else
		player:SendMessage(messageId, sender, "Unknown parameters! Usage: "..properties.description)
	end
end

function applyPositionOffset(str, offset)
	local s = str
	if s:find("@") then
		s = tonumber(s:sub(s:find("@") + 1, s:len()))
		if s then s = s + offset end
	end
	print(s)
	return s
end