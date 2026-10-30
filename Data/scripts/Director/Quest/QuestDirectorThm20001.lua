require("Global")
require("QuestFlow")
require("Quest/Thm/Thm200")

--[[
The Big Payback (Thm200 SEQ_005): vengeance on the herd in Western Thanalan. Five nannygoats; the
death-marked billygoat joins when one is left, and its fall gives the twisted aldgoat horn. The
enraged nannygoat comes once the herd and the billygoat are gone; its fall wins.
The fight is Content/Quest/QuestBattle.lua, variant Thm20001.
--]]

local function hornIfEarned(player, fight)
	if fight:Counter("billygoat") > 0 then
		grantAldgoatHorn(player)
	end
end

function init()
	return "/Director/Quest/QuestDirectorThm20001"
end

function onEventStarted(player, director, triggerName)
	runQuestFight(player, director, {
		quest = "Thm200",
		content = "SimpleContentThm20001",
		encounter = "QuestDirectorThm20001",
		sequence = SEQ_005,
		win = function(player, quest, fight, area)
			hornIfEarned(player, fight)
			finishVengeance(player, quest, fight, area)
		end,
		fail = function(player, quest, fight, area)
			hornIfEarned(player, fight)
			failVengeance(player, quest, fight, area)
		end,
		reviveOnFail = true,
	})
end

function main()
end
