require("Global")

properties = {
	permissions = 0,
	parameters = "sss",
	description =
[[
Adds experience <qty> to the current class of player or <targetname>.
!giveexp <qty> |
!giveexp <qty> <targetname> |
]],
}

function onTrigger(player, argc, qty, name, lastName)
	local sender = "[giveexp] "

	if name then
		if lastName then
			player = GetWorldManager():GetPCInWorld(name.." "..lastName) or nil
		else
			player = GetWorldManager():GetPCInWorld(name) or nil
		end
	end

	if player then
		qty = tonumber(qty) or 1
		local actionList = player:AddExp(qty, player.charaWork.parameterSave.state_mainSkill[0], 0)
		player:DoBattleAction(0, 0, actionList)
	else
		print(sender.."unable to add experience, ensure player name is valid.")
	end
end
