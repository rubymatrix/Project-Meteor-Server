require("Global")

properties = {
	permissions = 0,
	parameters = "sss",
	description =
[[
Sets player or <targetname>'s maximum tp to <tp> and heals them to full.
!setmaxtp <tp> |
!setmaxtp <tp> <targetname>
]],
}

function onTrigger(player, argc, tp)
	local sender = "[setmaxtp] "

	tp = tonumber(tp) or 0
	player:AddTP(tp)

end