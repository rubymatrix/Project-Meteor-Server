require("Global")

properties = {
	permissions = 1,
	parameters = "ss",
	description =
[[
Shows or changes leve allowances.
!leveallowance            shows remaining allowances and time to the next +4
!leveallowance set <n>    sets them (0-99)
!leveallowance add <n>    adds n (capped at 99)
]],
}

function onTrigger(player, argc, cmd, value)
	local sender = "[leveallowance] "
	if player == nil then
		print(sender .. "no player")
		return
	end

	local n = tonumber(value)
	if cmd == "set" and n ~= nil then
		player:SetLeveAllowances(n)
	elseif cmd == "add" and n ~= nil then
		player:AddLeveAllowances(n)
	end

	local seconds = player:GetLeveAllowanceSecondsToNextGrant()
	player:SendMessage(MESSAGE_TYPE_SYSTEM, sender, string.format("%d leve allowances; next +4 in %dh %02dm.",
		player:GetLeveAllowances(), math.floor(seconds / 3600), math.floor((seconds % 3600) / 60)))
end
