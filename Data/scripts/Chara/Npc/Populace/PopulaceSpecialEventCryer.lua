require("Global")

--[[
Foundation Day event representatives, set to the 2012 crystal-for-seals exchange. No crystals are taken.
Client functions: Data/Docs/Scripts/Chara/Npc/Populace/PopulaceSpecialEventCryer.md.
--]]

function init(npc)
	return false, false, 0, 0
end


local gcRep = {
	[1001619] = 1, -- Maelstrom Representative 2011
	[1002105] = 1, -- Maelstrom Representative 2012
	[1001623] = 2, -- Adder Representative 2011
	[1002109] = 2, -- Adder Representative 2012
	[1001627] = 3, -- Flame Representative 2011
	[1002113] = 3, -- Flame Representative 2012
}


function onEventStarted(player, npc, triggerName)
	local choice
	local playerGc = player.gcCurrent
	local npcId = npc:GetActorClassId()
	local npcGc = gcRep[npcId]
	local npcGcSeal = 1000200 + npcGc
	local hasCrystal = 1
	local crystal = 3020537
	local cluster = 3020413
	local eventMode = 2012

	if eventMode == 2011 then
		if playerGc == 0 then
			callClientFunction(player, "eventTalkStep0", 0)
		elseif playerGc == npcGc then
			callClientFunction(player, "eventTalkStep0", 1)
		else
			callClientFunction(player, "eventTalkNotGCmenber", npcGc)
		end

	elseif eventMode == 2012 then
		choice = callClientFunction(player, "eventTalkCrystalExchange", player, npcGc, hasCrystal)

		if choice == 1 then
			player:SendMessage(0x20, "", "You pretend to hand over four over-aspected crystals.")
			callClientFunction(player, "eventTalkCrystalExchange2", player, npcGc)

			local invCheck = player:GetItemPackage(INVENTORY_CURRENCY):AddItem(npcGcSeal, 1000, 1)
			if invCheck == INV_ERROR_SUCCESS then
				player:SendGameMessage(player, GetWorldMaster(), 25071, MESSAGE_TYPE_SYSTEM, crystal, 1, npcGcSeal, 1, 4, 1000)
			end
		elseif choice == 2 then
			player:SendMessage(0x20, "", "You pretend to hand over an over-aspected cluster.")
			callClientFunction(player, "eventTalkCrystalExchange2", player, npcGc)

			local invCheck = player:GetItemPackage(INVENTORY_CURRENCY):AddItem(npcGcSeal, 3000, 1)
			if invCheck == INV_ERROR_SUCCESS then
				player:SendGameMessage(player, GetWorldMaster(), 25071, MESSAGE_TYPE_SYSTEM, cluster, 1, npcGcSeal, 1, 1, 3000)
			end
		end
	end

	player:EndEvent()
end