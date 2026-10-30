require("Global")

properties = {
	permissions = 0,
	parameters = "dddd",
	description =
[[
Sets anim id for current target
!anim <animID> |
!anim <category> <effect> <motion>
]],

}

function onTrigger(player, argc, hex)

	local actor = player.CurrentArea:FindActorInArea(player.currentTarget) or nil

	if player and actor then
		anim = tonumber(hex,16)
		if anim then
			actor:PlayAnimation(anim)
			player:SendMessage(0x20, "[anim] ", "0x"..tostring(hex).. " Target:"..tostring(actor))
		else
			player:SendMessage(0x20, "[anim] ", "Error "..hex)
		end

	end
end