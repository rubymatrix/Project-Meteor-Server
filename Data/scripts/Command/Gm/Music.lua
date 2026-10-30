properties = {
	permissions = 0,
	parameters = "ss",
	description =
[[
Plays music <id> to player, otherwise resets to the zone's music.
!music
!music <id>
!music <id> <transition_type>
]],
}

function onTrigger(player, argc, music, transition)
	music = tonumber(music) or player.CurrentArea.bgmDay or 0
	transition = tonumber(transition) or nil
	player:ChangeMusic(music, transition)
end