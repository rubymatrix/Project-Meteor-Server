require("Global")

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, npc, triggerName)

	local harvestJudge = GetStaticActor("HarvestJudge")

	-- Mining is not wired yet. HarvestJudge calls: Data/Docs/Scripts/Chara/Npc/Object/MiningPoint.md.

	player:EndEvent()
end