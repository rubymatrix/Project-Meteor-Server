require("Global")

properties = {
	permissions = 0,
	parameters = "ss",
	description =
[[
Navigation gates (doors, lifts, walls) of the area you are in.
!navgate              lists them and their state
!navgate <id> open    opens one (close / closed to close it)
]],
}

function onTrigger(player, argc, gateId, state)
	local area = player.CurrentArea
	if gateId == nil then
		player:SendMessage(MESSAGE_TYPE_SYSTEM_ERROR, "[navgate] ", area:DescribeGates())
		return
	end

	local open = (state == nil or state == "open" or state == "1" or state == "true")
	if area:SetGate(gateId, open) then
		player:SendMessage(MESSAGE_TYPE_SYSTEM_ERROR, "[navgate] ", gateId .. (open and " opened" or " closed"))
	else
		player:SendMessage(MESSAGE_TYPE_SYSTEM_ERROR, "[navgate] ", "no gate " .. gateId .. " here (needs a .nav world)")
	end
end
