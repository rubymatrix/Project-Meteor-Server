require("Global")

--[[
Functions: onTrigger
Desc:   Moves the targeted npc by <distance> yalms (default 5): forward, up/down, left/right, or
        rotates it.
Params: [distance] [up/down/left/right/rotate]
--]]

properties = {
	permissions = 0,
	parameters = "ss",
	description =
[[
Positions a targeted npc by some <distance>, defaults to 5 yalms.
!nudge |
!nudge <distance> |
!nudge <distance> <up/down> |
!nudge <distance> <left/right> |
!nudge <distance> <rotate> |
]],

}

local vertical = {
["UP"] = 1,
["U"] = 1,
["+"] = 1,
["ASCEND"] = 1,
["DOWN"] = -1,
["D"] = -1,
["-"] = -1,
["DESCEND"] = -1,
}

local horizontal = {
["RIGHT"] = 2,
["R"] = 2,
["+"] = 2,
["LEFT"] = -2,
["L"] = -2,
["0"] = -2
}

rotation = {
["ROTATE"] = 3,
["ORIENTATION"] = 3,
["O"] = 3,
["ROT"] = 3
}

function onTrigger(player, argc, arg1, arg2)
	local messageId = MESSAGE_TYPE_SYSTEM
	local sender = "[nudge] "

	local targetActor = player.CurrentArea:FindActorInArea(player.currentTarget) or nil


	if targetActor == nil then
		player:SendMessage(MESSAGE_TYPE_SYSTEM, sender, "No target was selected.\n")
		return
	end

	local pos = targetActor:GetPos()
	local x = pos[0]
	local y = pos[1]
	local z = pos[2]
	local rot = pos[3]
	local zone = pos[4]
	local angle = rot + (math.pi/2)

	local worldManager = GetWorldManager()
	 local distance = 5
	local direction = 0

	local checkArg1 = tonumber(arg1)
	local checkArg2 = tonumber(arg2)

	if argc == 1 then
		if checkArg1 then
			distance = checkArg1
		else
			player:SendMessage(messageId, sender, "Unknown parameters! Usage: \n"..properties.description)
			return
		end
	elseif argc == 2 then
		if checkArg1 and checkArg2 then           -- If both are numbers, just ignore second argument
			distance = checkArg1
		elseif checkArg1 and not checkArg2 then   -- If first is number and second is string
			distance = checkArg1
			if vertical[string.upper(arg2)] then                -- Check vertical direction on string
				direction = vertical[string.upper(arg2)]
			elseif horizontal[string.upper(arg2)] then          -- Check horizontal direction on string
				direction = horizontal[string.upper(arg2)]
			elseif rotation[string.upper(arg2)] then            -- Check rotation on string, otherwise throw param error
				direction = rotation[string.upper(arg2)]
			else
			   player:SendMessage(messageId, sender, "Unknown parameters! Usage: \n"..properties.description)
			   return
			end
		elseif (not checkArg1) and checkArg2 then -- If first is string and second is number
			distance = checkArg2
			if vertical[string.upper(arg1)] then                -- Check vertical direction on string
				direction = vertical[string.upper(arg1)]
			elseif horizontal[string.upper(arg1)] then          -- Check horizontal direction on string
				direction = horizontal[string.upper(arg1)]
			elseif rotation[string.upper(arg1)] then            -- Check rotation on string, otherwise throw param error
				direction = rotation[string.upper(arg1)]
			else
				player:SendMessage(messageId, sender, "Unknown parameters! Usage: \n"..properties.description)
				return
			end
		else
			player:SendMessage(messageId, sender, "Unknown parameters! Usage: \n"..properties.description)
			return
		end
	end

	if direction == 1 then
		y = y + distance
		targetActor:SetPos(x,y,z,rot,true, player)
		message = string.format("Moved %s @ %f, %f, %f, %f", targetActor:GetUniqueId(), x, y, z, rot)
	elseif direction == -1 then
		y = y - distance
		targetActor:SetPos(x,y,z,rot,true, player)
		message = string.format("Moved %s @ %f, %f, %f, %f", targetActor:GetUniqueId(), x, y, z, rot)
	elseif direction == 2 then
		local px = x - distance * math.cos(angle - math.pi/2)
		local pz = z + distance * math.sin(angle - math.pi/2)
		targetActor:SetPos(px, y, pz, rot, true, player)
		message = string.format("Moved %s @ %f, %f, %f, %f", targetActor:GetUniqueId(), px, y, pz, rot)
	elseif direction == -2 then
		local px = x - distance * math.cos(angle + math.pi/2)
		local pz = z + distance * math.sin(angle + math.pi/2)
		targetActor:SetPos(px, y, pz, rot, true, player)
		message = string.format("Moved %s @ %f, %f, %f, %f", targetActor:GetUniqueId(), px, y, pz, rot)
	elseif direction == 3 then
		targetActor:SetPos(x, y, z, distance, true, player)
		message = string.format("Moved %s @ %f, %f, %f, %f", targetActor:GetUniqueId(), x, y, z, distance)
	else
		local px = x - distance * math.cos(angle)
		local pz = z + distance * math.sin(angle)
		targetActor:SetPos(px, y, pz, rot, true, player)
		message = string.format("Moved %s @ %f, %f, %f, %f", targetActor:GetUniqueId(), px, y, pz, rot)
	end

	player:SendMessage(messageId, sender, message)
end
