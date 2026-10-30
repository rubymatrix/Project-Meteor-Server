require("Global")

--[[
Functions: onTrigger
Desc:   Plays an animation on the current target, built from category, effect and motion.
Params: <category> <effect> <motion>. Id layout: Data/Docs/Scripts/Command/Gm/Anim.md
--]]

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

function onTrigger(player, argc, aType, a1, a2)
	local animId

	local actor = player.CurrentArea:FindActorInArea(player.currentTarget) or nil

	if player and actor then
		a1 = bit.band(a1, 0xFFF)
		a2 = bit.band(a2, 0xFFF)
		aType = bit.band(aType, 0xFF)

		animId = bit.bor(bit.lshift(a2, 12), a1)
		animId = bit.bor(bit.lshift(aType, 24), animId) % 2^32
		actor:PlayAnimation(animId)
		local output = string.format("%x", animId)
		player:SendMessage(0x20, "[anim] ", "0x"..tostring(output).. " Target:"..tostring(actor))
	end
end
