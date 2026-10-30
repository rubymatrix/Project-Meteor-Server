require("Global")
require("Quest/Man/Man200")

local snpc

function init()
	return "/Director/Quest/QuestDirectorEventMan20001"
end

function onCreateContentArea(players, director, contentArea, contentGroup)

	snpc = contentArea:SpawnActor(players[1]:GetSNpcSkin() + 107000, "snpc", -203.32, 0, -159.627)
	contentGroup:AddMember(player)
	contentGroup:AddMember(snpc)
	contentGroup:AddMember(director)

end

function onEventStarted(player, director, triggerName)

end

function main()
end