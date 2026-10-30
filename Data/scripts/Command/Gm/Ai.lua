require("Global")

--[[
Functions: onTrigger
Desc:   Shows or changes the targeted battle npc's AI (behaviors, channels, blackboard).
Params: show | add <kind> (stock or Lua behavior, default params) | remove <id> | reset (reapply profile)
--]]

properties = {
	permissions = 0,
	parameters = "sss",
	description = "Shows or changes the target's AI: !ai show | add <kind> | remove <id> | reset",
}

function onTrigger(player, argc, cmd, arg)
	local target = player.CurrentArea:FindActorInArea(player.currentTarget)
	if target == nil or target.Brain == nil then
		player:SendMessage(0x20, "", "Target a battle npc first.")
		return
	end
	cmd = cmd or "show"
	if cmd == "add" and arg ~= nil then
		target.Brain:AddBehavior(arg, arg, nil)
	elseif cmd == "remove" and arg ~= nil then
		target.Brain:Remove(arg, "gm")
	elseif cmd == "reset" then
		target.Brain:Attach(nil, nil)
	end
	for line in string.gmatch(DescribeAi(target), "[^\n]+") do
		player:SendMessage(0x20, "", line)
	end
end
