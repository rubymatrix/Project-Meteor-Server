require("Global")

local ITEM_TREANT_VINE = 11000088
local TEXT_KEY_ITEM_OBTAINED = 25117

function onZoneIn(player, zone)
	local quest = player:GetQuest("Man0g0")
	if quest == nil or quest:GetSequence() ~= 10 or not player.CurrentArea:IsPrivate() then
		return
	end
	local waited = 0
	while player.isZoneChanging and waited < 30 do
		wait(0.5)
		waited = waited + 0.5
	end
	wait(1)
	local keyItems = player:GetItemPackage(INVENTORY_KEYITEMS)
	if not keyItems:HasItem(ITEM_TREANT_VINE) then
		keyItems:AddItem(ITEM_TREANT_VINE, 1, 1)
		player:SendGameMessage(GetWorldMaster(), TEXT_KEY_ITEM_OBTAINED, 0x20, ITEM_TREANT_VINE)
	end
end
