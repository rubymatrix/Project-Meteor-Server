--[[

BonusPointCommand Script

Functions:

operateUI(pointsTotal, pointsLimit, str, vit, dex, int, mnd, pie)
	Desc: Opens the attribute point widget. Returns ok (false on Cancel) and the new value of each attribute.
	Params:	* pointsTotal	- All points for this level. The widget subtracts the ones already allotted.
			* pointsLimit	- The most points one attribute can take.
			* str-pie		- Points already allotted to each attribute.

--]]

require("Global")
require("Battle/Stats")

function onEventStarted(player, actor, eventType, eventName)
	local classId = stats.classOf(player)
	local level = player:GetLevel()
	local total = stats.bonusPoints(level)
	local cap = stats.bonusPointCap(level)

	local cur = { player:GetBonusPoint(classId, 0), player:GetBonusPoint(classId, 1), player:GetBonusPoint(classId, 2),
				  player:GetBonusPoint(classId, 3), player:GetBonusPoint(classId, 4), player:GetBonusPoint(classId, 5) }

	local ok, str, vit, dex, int, mnd, pie = callClientFunction(player, "delegateCommand", actor, "operateUI", total, cap,
		cur[1], cur[2], cur[3], cur[4], cur[5], cur[6])

	if ok == true then
		local saved = player:SetBonusAllotment(classId, level, tonumber(str) or cur[1], tonumber(vit) or cur[2],
			tonumber(dex) or cur[3], tonumber(int) or cur[4], tonumber(mnd) or cur[5], tonumber(pie) or cur[6])
		if not saved then
			printf("[BonusPointCommand] refused allotment class=%s level=%s: %s %s %s %s %s %s", tostring(classId), tostring(level),
				tostring(str), tostring(vit), tostring(dex), tostring(int), tostring(mnd), tostring(pie))
		end
	end

	player:EndEvent()
end
