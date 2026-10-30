require("Global")

--[[
Guards outside the story raids (Hodder, Dauremant, Louisoix): default talk, or the quest's talk on the
step that leads into the raid. Raid entry notes: Data/Docs/Scripts/Chara/Npc/Populace/InstanceRaidGuide/InstanceRaidGuide.md.
--]]

function init(npc)

	if (npc == 1002090) or (npc == 1002091)  then
		-- Never taken, given how init() is called; kept from older scripts.
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


	local npcId = npc:GetActorClassId()

	if npcId == 1002090 then -- Serpent Private Hodder (Stewart) : Gcl107

		callClientFunction(player, "delegateEvent", player, GetStaticActor("DftFst"), "defaultTalkWithStewart_001")
	elseif npcId == 1002091 then -- Serpent Private Dauremant (Trisselle) : Sum6w0

		callClientFunction(player, "delegateEvent", player, GetStaticActor("DftFst"), "defaultTalkWithTrisselle_001")
	elseif npcId == 1060022 then -- Louisoix
		callClientFunction(player, "delegateEvent", player, GetStaticActor("DftFst"), "defaultTalkLouisoix_001")
	end




	player:EndEvent()
end