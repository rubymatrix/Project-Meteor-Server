require("Global")
require("Aetheryte")
require("Utils")
require("Battle/Ko")

--[[

TeleportCommand Script

Functions:

eventRegion(numAnima)
eventAetheryte(region, animaCost1, animaCost2, animaCost3, animaCost4, animaCost5, animaCost6)
eventConfirm(isReturn, isInBattle, HomePointInn, HomePoint, forceAskReturnOnly)

--]]

local teleportMenuToAetheryte = {
	[1] = {
		[1] = 1280001,
		[2] = 1280002,
		[3] = 1280003,
		[4] = 1280004,
		[5] = 1280005,
		[6] = 1280006
	},
	[2] = {
		[1] = 1280092,
		[2] = 1280093,
		[3] = 1280094,
		[4] = 1280095,
		[5] = 1280096
	},
	[3] = {
		[1] = 1280061,
		[2] = 1280062,
		[3] = 1280063,
		[4] = 1280064,
		[5] = 1280065,
		[6] = 1280066
	},
	[4] = {
		[1] = 1280031,
		[2] = 1280032,
		[3] = 1280033,
		[4] = 1280034,
		[5] = 1280035,
		[6] = 1280036
	},
	[5] = {
		[1] = 1280121,
		[2] = 1280122
	}
}

local zoneIdToRegionChoice =
{
	[128] = 1, [129] = 1, [130] = 1, [131] = 1, [132] = 1, [133] = 1, [134] = 1, [135] = 1, [230] = 1,
	[143] = 2, [144] = 2, [145] = 2, [147] = 2, [148] = 2,
	[150] = 3, [151] = 3, [152] = 3, [153] = 3, [154] = 3, [155] = 3, [157] = 3, [158] = 3, [159] = 3, [160] = 3, [206] = 3,
	[170] = 4, [171] = 4, [172] = 4, [173] = 4, [174] = 4, [175] = 4, [176] = 4, [178] = 4, [180] = 4, [181] = 4, [209] = 4,
	[190] = 5
}


-- Revives once the client is in the new zone, so the get-up plays at the home point.
local function reviveAfterReturn(player)
	local waited = 0
	while player:IsInZoneChange() and waited < 60 do
		wait(0.5)
		waited = waited + 0.5
	end
	wait(1.5)

	if player:IsDead() or player:GetHP() == 0 then
		player:Revive(ko.RETURN_HP_PERCENT)
		player:SetMP(player:GetMaxMP())
		player:PlayAnimation(0x01000066)
	end
end

function onEventStarted(player, actor, eventType, eventName, isTeleport)
	local randoPos
	local confirmChoice
	local aetheryteChoice
	local regionChoice
	local returningKo = false

	local worldMaster = GetWorldMaster()
	local playerState = player:GetState()
	local currentAnima = 100
	local baseAnimaCost = 6
	local animaCost = 0
	local favoredLocation = {1280003, 1280005, 1280062}
	local currentRegion = zoneIdToRegionChoice[player:GetPos()[4]] or 0
	local isCity = {[1280001] = true, [1280061] = true, [1280031] = true}
	local isFavoredDesination = false
	local destination = 0


	if isTeleport == 0 then -- Teleport hit
		while true do
			regionChoice = callClientFunction(player, "delegateCommand", actor, "eventRegion", currentAnima)

			if regionChoice == nil then break end

			while true do
				if regionChoice > 0 and regionChoice < 6 then -- If Region selected

					if regionChoice == currentRegion then -- Check if selected region matches player's region, reduce cost if so.
						baseAnimaCost = baseAnimaCost - 2
					else
						baseAnimaCost = 6
					end

					-- Assign anima cost to the six possible slots after factoring in same region or not.
					animaCost = {baseAnimaCost, baseAnimaCost, baseAnimaCost, baseAnimaCost, baseAnimaCost, baseAnimaCost}

					if isCity[teleportMenuToAetheryte[regionChoice][1]] == true then
						-- Halve the cost of applicable city aetheryte
						animaCost[1] = animaCost[1] / 2
					end

				elseif regionChoice == 6 then -- Favored Destinations selected.
					-- Dummy info.  Favored would be half price after factoring in same region cost or not.
					animaCost = {2, 3, 3, favoredLocation[1], favoredLocation[2], favoredLocation[3]}
					isFavoredDesination = true
				end


				aetheryteChoice = callClientFunction(
												player,
												"delegateCommand",
												actor,
												"eventAetheryte",
												regionChoice,
												animaCost[1],
												animaCost[2],
												animaCost[3],
												animaCost[4],
												animaCost[5],
												animaCost[6]
												)


				if aetheryteChoice == nil then break end

				player:PlayAnimation(0x4000FFA)

				if isFavoredDesination == true then
					destination = aetheryteTeleportPositions[favoredLocation[aetheryteChoice]]
					player:SendGameMessage(worldMaster, 34101, 0x20, 2, favoredLocation[aetheryteChoice], animaCost[aetheryteChoice], currentAnima)
				else
					destination = aetheryteTeleportPositions[teleportMenuToAetheryte[regionChoice][aetheryteChoice]]
					player:SendGameMessage(worldMaster, 34101, 0x20, 2, teleportMenuToAetheryte[regionChoice][aetheryteChoice], animaCost[aetheryteChoice], currentAnima)
				end

				confirmChoice = callClientFunction(player, "delegateCommand", actor, "eventConfirm", false, false, 1, 138824, false)

				if confirmChoice == 1 then
					player:PlayAnimation(0x4000FFB)
					player:SendGameMessage(worldMaster, 34105, 0x20)

					if destination ~= 0 then
						randoPos = getRandomPointInBand(destination[2], destination[4], 3, 5)
						rotation = getAngleFacing(randoPos.x, randoPos.y, destination[2], destination[4])
						if playerState == ACTORSTATE_MOUNTED then
							player:SetMountState(0)
							player:ChangeSpeed(0.0, 2.0, 5.0, 5.0)
							player:ChangeState(ACTORSTATE_PASSIVE)
						end

						GetWorldManager():DoZoneChange(player, destination[1], nil, 0, 2, randoPos.x, destination[3], randoPos.y, rotation)
					end
				end

			player:EndEvent()
			return
			end
		end

	else -- Return hit
		player:PlayAnimation(0x4000FFA)
		local choice, isInn = callClientFunction(player, "delegateCommand", actor, "eventConfirm", true, false, player:GetHomePointInn(), player:GetHomePoint(), false)
		if choice == 1 then
			player:PlayAnimation(0x4000FFB)
			player:SendGameMessage(worldMaster, 34104, 0x20)

			-- A KO'd player zones while still dead and gets up at the destination.
			returningKo = player:IsDead() or player:GetHP() == 0
			if returningKo then
				player:SkipNextDeathReplay()
			end

			if isInn then
				--Return to Inn
				if player:GetHomePointInn() == 1 then
					GetWorldManager():DoZoneChange(player, 244, nil, 0, 15, -160.048, 0, -165.737, 0)
				elseif player:GetHomePointInn() == 2 then
					GetWorldManager():DoZoneChange(player, 244, nil, 0, 15, 160.048, 0, 154.263, 0)
				elseif player:GetHomePointInn() == 3 then
					GetWorldManager():DoZoneChange(player, 244, nil, 0, 15, 0.048, 0, -5.737, 0)
				end
			elseif choice == 1 and isInn == nil then
				--Return to Homepoint
				destination = aetheryteTeleportPositions[player:GetHomePoint()]
				if destination ~= nil then
					randoPos = getRandomPointInBand(destination[2], destination[4], 3, 5)
					rotation = getAngleFacing(randoPos.x, randoPos.y, destination[2], destination[4])
					if playerState == ACTORSTATE_MOUNTED then
						player:SetMountState(0)
						player:ChangeSpeed(0.0, 2.0, 5.0, 5.0)
						player:ChangeState(ACTORSTATE_PASSIVE)
					end

					GetWorldManager():DoZoneChange(player, destination[1], nil, 0, 2, randoPos.x, destination[3], randoPos.y, rotation)
				end
			end
		end
	end

	player:EndEvent()

	if returningKo then
		reviveAfterReturn(player)
	end
end
