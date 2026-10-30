--[[

InstanceRaidGuide Script

Functions;
askEnterInstanceRaid(arg1)   -- Opens a widget asking to enter the given Raid id.

--]]

require("Global")

function init(npc)

	if (npc == 1002090) or (npc == 1002091)  then
		-- This won't work due to how init() works, but old scripts had it, keeping it here for now
		return false, false, 0, 0, 491, 2
	else
		return false, false, 0, 0
	end
end

function onEventStarted(player, npc, eventType, eventName)
	-- Guides that open a story raid (Hodder, Louisoix) hand the talk to the quest on that step.
	local quest = arrayToTable(player:GetQuestsForNpcEvent(npc, eventType))[1]
	if quest ~= nil and eventType == ETYPE_TALK then
		quest:OnTalk(player, npc)
		return
	end


	npcId = npc:GetActorClassId()

	if npcId == 1002090 then -- Serpent Private Hodder (Stewart) : Gcl107

		callClientFunction(player, "delegateEvent", player, GetStaticActor("DftFst"), "defaultTalkWithStewart_001") -- "defaultTalkWithStewart_002" -- Post-Raid dialog?

		--[[
        choice = callClientFunction(player, "delegateEvent", player, GetStaticActor("Gcl107"), "processEventStewart", 15);
        
        if (choice == 1) then
            callClientFunction(player, "askEnterInstanceRaid", 15); -- Rivenroad
        end
        --]]
	elseif npcId == 1002091 then -- Serpent Private Dauremant (Trisselle) : Sum6w0

		callClientFunction(player, "delegateEvent", player, GetStaticActor("DftFst"), "defaultTalkWithTrisselle_001") -- "defaultTalkWithTrisselle_002" -- No idea for context.

		--[[
        choice = callClientFunction(player, "delegateEvent", player, GetStaticActor("Sum6w0"), "processEventTrisselle", 16)
        
        if (choice == 1) then
            callClientFunction(player, "askEnterInstanceRaid", 16);  -- Rivenroad (Hard)
        end
        --]]
	elseif npcId == 1060022 then -- Louisoix
		callClientFunction(player, "delegateEvent", player, GetStaticActor("DftFst"), "defaultTalkLouisoix_001")
	end




	player:EndEvent()
end