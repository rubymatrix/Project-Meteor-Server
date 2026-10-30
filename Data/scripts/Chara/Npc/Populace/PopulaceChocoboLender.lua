require("Global")

--[[
Chocobo stable keeper: rents a chocobo, or issues a Grand Company member their own.
The client crashes in the naming dialog unless actor 1080101 is present.
--]]

local mountChocobo

local rentalPrice = 800
local rentalTime = 10

local gcIssuances = {
	[1500006] = 2001004,
	[1500061] = 2001005,
	[1000840] = 2001006,
	[1500059] = 0
}

local startAppearances = {
	[1500006] = CHOCOBO_LIMSA1,
	[1500061] = CHOCOBO_GRIDANIA1,
	[1000840] = CHOCOBO_ULDAH1
}

local cityExits = {
	[1500006] = {133, -6.032, 46.356, 132.572, 3.034},
	[1500061] = {150, 333.271, 5.889, -943.275, 0.794},
	[1000840] = {170, -26.088, 181.846, -79.438, 2.579},
	[1500059] = {172, -2133.028, 15.476, -421.471, 1.5}
}

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, npc, triggerName)
	local classId = npc:GetActorClassId()
	local curLevel = 20 -- TODO: pull from character
	local hasIssuance = player:GetItemPackage(INVENTORY_KEYITEMS):HasItem(gcIssuances[classId])
	local hasChocobo = player.hasChocobo

	if hasChocobo == false then -- Let GMs auto have the issuance for debugging
		hasIssuance = true
	end

	local hasFunds = (player:GetCurrentGil() >= rentalPrice)



	if (classId == 1000840) and (player:HasQuest(110009)) then -- Cross-script Man0u0 dialog
		local sequence = player:GetQuest(110009):GetSequence()

		if sequence == 0 then
			callClientFunction(player, "delegateEvent", player, GetStaticActor("Man0u0"), "processEvent000_13")
		elseif sequence == 10 then
			callClientFunction(player, "delegateEvent", player, GetStaticActor("Man0u0"), "processEvent020_7")
		else
			player:EndEvent()
		end
	else
		callClientFunction(player, "eventTalkWelcome", player)

		local menuChoice = callClientFunction(player, "eventAskMainMenu", player, curLevel, hasFunds, hasIssuance, hasChocobo, hasChocobo, 0)

		if menuChoice == 1 then -- Issuance option

			callClientFunction(player, "eventTalkMyChocobo", player)
			local nameResponse = callClientFunction(player, "eventSetChocoboName", true)

			if nameResponse == "" then -- Cancel Chocobo naming
				callClientFunction(player, "eventCancelChocoboName", player)
				callClientFunction(player, "eventTalkStepBreak", player)
				player:EndEvent()
				return
			else
				local appearance = startAppearances[classId]
				player:IssueChocobo(appearance, nameResponse)

				callClientFunction(player, "eventAfterChocoboName", player)

				--Add Chocobo License and remove issuance
				if player:GetItemPackage(INVENTORY_KEYITEMS):HasItem(2001007) == false then
					player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(2001007)
				end
				player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(gcIssuances[classId], 1)

				--Warp with the special chocobo warp mode.
				mountChocobo(player)
				GetWorldManager():DoZoneChange(player, cityExits[classId][1], nil, 0, SPAWN_CHOCOBO_GET, cityExits[classId][2], cityExits[classId][3], cityExits[classId][4], cityExits[classId][5])
			end

		elseif menuChoice == 2 then -- Summon Bird
			mountChocobo(player)
			GetWorldManager():DoZoneChange(player, cityExits[classId][1], nil, 0, SPAWN_NO_ANIM, cityExits[classId][2], cityExits[classId][3], cityExits[classId][4], cityExits[classId][5])
		elseif menuChoice == 3 then -- Change Barding
			callClientFunction(player, "eventTalkStepBreak", player)
		elseif menuChoice == 5 then -- Rent Bird
			mountChocobo(player, true, 10)
			GetWorldManager():DoZoneChange(player, cityExits[classId][1], nil, 0, SPAWN_CHOCOBO_RENTAL, cityExits[classId][2], cityExits[classId][3], cityExits[classId][4], cityExits[classId][5])
		else
			callClientFunction(player, "eventTalkStepBreak", player)
		end
	end

	player:EndEvent()
end

function mountChocobo(player, isRental, rentalMinutes)
	if isRental then
		player:ChangeMusic(64)
		player:StartChocoboRental(rentalMinutes)
	else
		player:ChangeMusic(83)
	end

	player:SendMountAppearance()
	player:SetMountState(1)
	player:ChangeSpeed(0.0, 3.6, 9.0, 9.0)
	player:ChangeState(15)
end