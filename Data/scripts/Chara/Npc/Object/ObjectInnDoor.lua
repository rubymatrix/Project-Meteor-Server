require("Global")

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, npc, eventType, eventName)
	defaultFst = GetStaticActor("DftFst")
	choice = callClientFunction(player, "delegateEvent", player, defaultFst, "defaultTalkWithInn_ExitDoor", nil, nil, nil)

	if choice == 1 then
		GetWorldManager():DoZoneChange(player, 1)
	end

	player:EndEvent()
end