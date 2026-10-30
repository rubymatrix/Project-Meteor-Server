require("Global")

properties = {
	permissions = 0,
	parameters = "ssss",
	description =
[[
<actorName> <workName> <uiFunc> <value>
]],
}

function onTrigger(player, argc, target, workName, uiFunc, value)
	local targetActor

	local messageId = MESSAGE_TYPE_SYSTEM_ERROR
	local sender = "[workvalue] "

	if argc ~= 4 then
		player:SendMessage(messageId, sender, "Invalid args")
		return
	end

	if target == "@t" then
		targetActor = GetWorldManager():GetActorInWorld(player.currentTarget) or nil
	else
		targetActor = GetWorldManager():GetActorInWorld(target) or nil
	end

	if not targetActor then
		player:SendMessage(messageId, sender, "Error finding target...")
		return
	end

	if tonumber(value) ~= nil then
		result = targetActor:SetWorkValue(player, workName, uiFunc, tonumber(value))
	elseif value == "true" then
		result = targetActor:SetWorkValue(player, workName, uiFunc, true)
	elseif value == "false" then
		result = targetActor:SetWorkValue(player, workName, uiFunc, false)
	else
		result = targetActor:SetWorkValue(player, workName, uiFunc, value)
	end

	if result then
		player:SendMessage(messageId, sender, workName .. " changed to " .. value)
	else
		player:SendMessage(messageId, sender, "Could not changed workvalue. Is the name and datatype correct?")
	end

end