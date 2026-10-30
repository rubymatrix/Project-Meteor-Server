require("Global")

--[[
Linkshell NPC: creates linkshells through the world server. Modify and disband show their dialogs but
do nothing yet. Client functions and text ids: Data/Docs/Scripts/Chara/Npc/Populace/PopulaceLinkshellManager.md.
--]]

function init(npc)
	return false, false, 0, 0
end

local function createLinkshell(player, name, crest)
	GetWorldManager():RequestWorldLinkshellCreate(player, name, crest)
	return waitForSignal("ls_result")
end

local function modifyLinkshell(player, name, crest)

end

local function disbandLinkshell(player, name, crest)

end

function onEventStarted(player, npc, triggerName)

	local hasNoActiveLs = false

	callClientFunction(player, "eventTalkStep1", hasNoActiveLs)
	local command, lsName, crestId = callClientFunction(player, "eventTalkStep2", hasNoActiveLs)

	if command == 3 then
		local result = createLinkshell(player, lsName, crestId)
		if result == 0 then
			callClientFunction(player, "eventTalkStepMakeupDone")
		elseif result == 1 then
			player:SendGameMessage(player, GetWorldMaster(), 25121, 0x20)
			callClientFunction(player, "eventTalkStepBreakDone")
		elseif result == 2 then
			player:SendGameMessage(player, GetWorldMaster(), 25122, 0x20)
			callClientFunction(player, "eventTalkStepBreakDone")
		elseif result == 3 then
		end
	elseif command == 4 then
		modifyLinkshell(player, lsName, crestId)
		callClientFunction(player, "eventTalkStepModifyDone")
	elseif command == 5 then
		disbandLinkshell(player, lsName, crestId)
		callClientFunction(player, "eventTalkStepBreakDone")
	end

	player:EndEvent()

end