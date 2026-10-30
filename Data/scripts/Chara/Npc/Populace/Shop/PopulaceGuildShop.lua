require("Global")
require("Shop")

--[[
Guild mark exchange at each guild: trades leftover marks for materia, crystals and gil.
--]]

local processGuildShop

function init(npc)
	return false, false, 0, 0
end

local guildShopInfo = { -- [actor id] = { saySheetId, guildmarkCurrency }
[1000157] = {9,  1000103}, -- Marauder, S'raemha
[1000158] = {24, 1000120}, -- Culinarian, Noline
[1000162] = {18, 1000114}, -- Blacksmith, Qhas Chalahko
[1000164] = {16, 1000123}, -- Fishermen, Faucillien
[1000459] = {21, 1000117}, -- Leatherworker, Gallia
[1000460] = {13, 1000111}, -- Conjurer, Hetzkin
[1000461] = {15, 1000122}, -- Botanist, Kipopo
[1000462] = {11, 1000107}, -- Lancer, Clarembald
[1000464] = {10, 1000106}, -- Archer, Cassandra
[1000466] = {17, 1000113}, -- Carpenter, Frances
[1000631] = {8,  1000102}, -- Gladiator, Coynach
[1000632] = {7,  1000101}, -- Pugilist, Moruith
[1000633] = {12, 1000110}, -- Thaumaturge, Nyunoeya
[1000634] = {23, 1000119}, -- Alchemist, Kylene
[1000635] = {20, 1000116}, -- Goldsmith, Hnaufrid
[1000636] = {22, 1000118}, -- Weaver, Lafla Morfla
[1000637] = {14, 1000121}, -- Miner, Shilgen
[1001461] = {19, 1000115}, -- Armorer, Notrelchamps
}

function onEventStarted(player, npc)

	-- Man1g0 Frances cross-script
	local classId = npc:GetActorClassId()
	local privAreaName = npc.CurrentArea:GetPrivateAreaName()
	local privAreaType = npc.CurrentArea:GetPrivateAreaType()
	if classId == 1000466 and player:HasQuest(110007) and privAreaName == "PrivateAreaMasterPast" and privAreaType == 7 then
		local sequence = player:GetQuest(110007):GetSequence()
		if sequence == 5 then
			callClientFunction(player, "delegateEvent", player, GetStaticActor("Man1g0"), "processEvent010_4")
		end
		player:EndEvent()
		return
	end

	local npcId = npc:GetActorClassId()
	local saySheetId = guildShopInfo[npcId][1]
	local shopCurrency = guildShopInfo[npcId][2]
	local gilCurrency = 1000001
	local keepersHymn = 3020410
	local shopPack = 0

	callClientFunction(player, "welcomeTalk", nil, saySheetId, player)

	while true do
		local choice = callClientFunction(player, "selectMode", nil, npcId, true, shopCurrency, 100)

		if choice == 3 then       -- Undo Point Allotment
			-- TODO: Add point reset handling
		elseif choice == 4 then   -- Leave menu selected
			player:EndEvent()
			break
		elseif choice == nil then -- Escape key hit to leave menu
			player:EndEvent()
			break
		elseif choice >= 102 and choice <= 120 then -- Exchange marks for Materia
			shopPack = choice + 18     -- Index offset
			if choice == 119 then
				shopPack = shopPack + 1
			elseif choice == 120 then  -- Exchange marks for Crystals
				shopPack = 144
			end
			processGuildShop(player, shopPack, shopCurrency)
		elseif choice == 121 then -- Exchange marks for Gil.  1 mark = 4 gil
			local markAmount = player:GetItemPackage(INVENTORY_CURRENCY):GetItemQuantity(shopCurrency)
			purchaseItem(player, INVENTORY_CURRENCY, gilCurrency, markAmount*4, 1, markAmount, shopCurrency)

		end
	end

	player:EndEvent()
end



function processGuildShop(player, choice, currency)

		callClientFunction(player, "openShopBuy", player, choice, currency)
		--callClientFunction(player, "maskShopListIndex", 137, true);

		while true do
			buyResult, quantity = callClientFunction(player, "selectShopBuy", player)

			if buyResult == 0 then
				callClientFunction(player, "closeShopBuy", player)
				break
			else
			  player:SendMessage(0x20, "", string.format("Player purchased %s item(s) at index %s in shopPack %s.", quantity, buyResult, choice))
			end
		end
end
