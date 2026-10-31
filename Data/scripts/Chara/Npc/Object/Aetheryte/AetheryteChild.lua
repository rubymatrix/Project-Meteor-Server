require("Global")
require("Aetheryte")
require("Utils")
require("Guildleve")

--[[
Aetheryte gate: teleport and home point menu, and the guildleve menus. Client event functions:
Data/Docs/Scripts/Chara/Npc/Object/Aetheryte/AetheryteChild.md.
--]]

local doGuildleveMenu, doNormalMenu, doLevequestInit

function init(npc)
	return false, false, 0, 0
end

function onEventStarted(player, aetheryte, triggerName)

	-- Unclaimed battle leve rewards are paid at any aetheryte.
	if player:GetGuildleveDirector() == nil then
		player:ClaimPendingGuildleveRewards()
	end

	if player:GetGuildleveDirector() ~= nil then
		doGuildleveMenu(player, aetheryte)
	else
		doNormalMenu(player, aetheryte)
	end

	player:EndEvent()
end

function doGuildleveMenu(player, aetheryte)

	local currentGlDirector = player:GetGuildleveDirector()
	local choice = callClientFunction(player, "eventGLPlay", currentGlDirector.guildleveId, true, 1, 500, 400, guardian, 8, currentGlDirector.selectedDifficulty, 2)

	-- Change level: only lowering, which re-levels the leve's idle monsters
	if choice == 4 then
		local difficulty = callClientFunction(player, "eventGLDifficulty", currentGlDirector.guildleveId)
		if difficulty ~= nil then
			currentGlDirector:SetDifficulty(difficulty)
		end
	--Abandon
	elseif choice == 6 then
		currentGlDirector:AbandonGuildleve()
	end

end

function doNormalMenu(player, aetheryte)
	local randoPos
	local destination

	local aetheryteId = aetheryte:GetActorClassId()
	local parentNode = aetheryteChildLinks[aetheryteId]
	local menuChoice = callClientFunction(player, "eventAetheryteChildSelect", true, parentNode, 100, 1)

	--Teleport
	if menuChoice == 2 then
		printf("%ud", parentNode)
		destination = aetheryteTeleportPositions[parentNode]

		if destination ~= nil then
			randoPos = getRandomPointInBand(destination[2], destination[4], 3, 5)
			rotation = getAngleFacing(randoPos.x, randoPos.y, destination[2], destination[4])
			GetWorldManager():DoZoneChange(player, destination[1], nil, 0, 2, randoPos.x, destination[3], randoPos.y, rotation)
		end
	--Init Levequest
	elseif menuChoice == -1 then
		doLevequestInit(player, aetheryte)
	--Set Homepoint
	elseif menuChoice == -2 then
		player:SetHomePoint(aetheryteId)
		callClientFunction(player, "eventAetheryteChildDesion", aetheryteId)
	--View Faction Standing
	elseif menuChoice == -3 then
		player:SendGameMessage(player, aetheryte, 27, 0x20)
		player:SendGameMessage(player, aetheryte, 28, 0x20, 1, 15)
		player:SendGameMessage(player, aetheryte, 29, 0x20, 2, 10)
		player:SendGameMessage(player, aetheryte, 30, 0x20, 3, 5)
	end
end

function doLevequestInit(player, aetheryte)
	local unknown, glId, begin
	local guildleveData, difficulty, confirmResult, director
	local worldMaster = GetWorldMaster()
	::SELECT_LOOP::
	-- The client lists only leves it thinks this aetheryte can start; the server checks again.
	unknown, glId = callClientFunction(player, "eventGLSelect", 0x0)
	if glId ~= nil and glId ~= 0 then
		local ok, reason = canStartGuildleveHere(player, aetheryte, glId)
		if not ok then
			player:SendMessage(MESSAGE_TYPE_SYSTEM_ERROR, "", reason)
			return
		end
		guildleveData = GetGuildleveGamedata(glId)

		::SELECT_DETAIL::
		unknown, begin = showGuildleveStartDetail(player, glId)
		if begin then
			::SELECT_DIFFICULTY::
			player:SendGameMessage(worldMaster, 50014, 0x20) --"Please select a difficulty level. This may be lowered later."
			difficulty = callClientFunction(player, "eventGLDifficulty", glId)
			if difficulty == nil then goto SELECT_DETAIL end
			confirmResult = callClientFunction(player, "eventGLStart", glId, difficulty, 1, 10, 20, 0, 0, 0, 0)
			if confirmResult == nil then goto SELECT_DIFFICULTY else

				player:SendGameMessage(worldMaster, 50036, 0x20, glId, player)
				player:SendGameMessage(worldMaster, 50011, 0x20) -- "You are now bound by duty."
				player:PlayAnimation(getGlStartAnimationFromSheet(guildleveData.plateId, guildleveData.borderId, false))
				director = player.CurrentArea:CreateGuildleveDirector(glId, difficulty, player)
				player:AddDirector(director)
				director:StartDirector(true, glId)

			end
		else
			goto SELECT_LOOP
		end
	end
end
