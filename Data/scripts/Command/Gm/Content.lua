require("Global")

--[[

Functions: onTrigger
Desc:   Dev control of content (encounters, instances, world events).
Params: list                      running Content
        start <name> [variant]    starts content with you as its participant
        win | fail                ends your current Content
        phase <name>              jumps your current content to a phase

--]]

properties = {
	permissions = 0,
	parameters = "sss",
	description = "Runs content: !content list | start <name> [variant] | win | fail | phase <name>",
}

function onTrigger(player, argc, cmd, arg, variant)
	cmd = cmd or "list"
	local current = GetContentFor(player)
	if cmd == "start" and arg ~= nil then
		local enc = StartContent(arg, variant or "", nil, player, nil)
		if enc == nil then
			player:SendMessage(0x20, "", "Could not start " .. arg .. " (see the map log).")
			return
		end
	elseif cmd == "win" and current ~= nil then
		current:Win("gm")
	elseif cmd == "fail" and current ~= nil then
		current:Fail("gm")
	elseif cmd == "phase" and current ~= nil and arg ~= nil then
		current:GotoPhase(arg)
	end
	for line in string.gmatch(DescribeContent(), "[^\n]+") do
		player:SendMessage(0x20, "", line)
	end
end
