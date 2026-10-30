require("Global")

--[[
Functions: onTrigger
Desc:   Sets the level of the current class or a named one through the level-up path.
Params: <level> [class]
--]]

properties = {
	permissions = 0,
	parameters = "ss",
	description =
[[
Sets the level of the current class, or of [class] (id or pug/gla/mrd/arc/lnc/thm/cnj/crp/bsm/arm/gsm/ltw/wvr/alc/cul/min/btn/fsh).
Raising a level goes through the level-up path (actions learned, stats recalculated); EXP into the level resets to 0.
!setlevel <level> |
!setlevel <level> <class> |
]],
}

local classNames = {
	pug = 2, gla = 3, mrd = 4, arc = 7, lnc = 8, thm = 22, cnj = 23,
	crp = 29, bsm = 30, arm = 31, gsm = 32, ltw = 33, wvr = 34, alc = 35, cul = 36,
	min = 39, btn = 40, fsh = 41,
}

function onTrigger(player, argc, level, class)
	local sender = "[setlevel] "
	local messageId = MESSAGE_TYPE_SYSTEM_ERROR

	level = tonumber(level)
	if level == nil then
		player:SendMessage(messageId, sender, "Usage: !setlevel <level> [class]")
		return
	end

	local classId = player:GetClass()
	if class ~= nil then
		classId = tonumber(class) or classNames[string.lower(class)]
	end
	local valid = false
	for _, id in pairs(classNames) do
		if id == classId then valid = true end
	end
	if not valid then
		player:SendMessage(messageId, sender, "Unknown class: "..tostring(class))
		return
	end

	local actionList = player:SetClassLevel(classId, level)
	if actionList.Count > 0 then
		player:DoBattleAction(0, 0, actionList)
	end
	player:SendMessage(MESSAGE_TYPE_SYSTEM, sender, string.format("Class %d is now level %d.", classId, player.charaWork.battleSave.skillLevel[classId - 1]))
end
