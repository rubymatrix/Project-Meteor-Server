--[[
HarvestJudge: the mining, logging and fishing minigame (only a test mining node so far).
Client functions and the Mooglebox aim/strike scales: Data/Docs/Scripts/Command/DummyCommand.md.
--]]

local minerAnim = {0x14001000, 0x14002000, 0x14003000}

local nodeContainer = { -- harvestAttempts, item count, then the nodeItems keys
	[1] = {4, 3, 1, 2, 3}
}

local nodeItems = {
		--itemId, remainder, aim, sweetspot, max yield
   [1] = {10009104, 70, 30, 30, 4}, -- Rock Salt
   [2] = {10006001, 80, 10, 30, 4}, -- Bone Chip
   [3] = {10001006, 80, 20, 30, 3}  -- Copper Ore
}


require("Global")

local sendTutorial

function onEventStarted(player, commandActor, eventType, eventName, arg1, arg2, arg3, arg4, checkedActorId)
	local remainderD, ret3

	local debugMsg = false

	local commandMine = 22002
	local commandLog = 22003
	local commandFish = 22004
	remainderA, remainderB, remainderC, remainderD = 40, 60, 70, 80


	local currentPower = 0
	local nodeGrade = 3
	local showTutorial = 0
	local harvestAttempts = 2
	local nodeRemainder = remainderC
	item = 10001006

	local harvestType = commandMine

	worldMaster = GetWorldMaster()
	local harvestJudge = GetStaticActor("HarvestJudge")
	callClientFunction(player, "delegateCommand", harvestJudge, "loadTextData", commandActor)
	--callClientFunction(player, "delegateCommand", harvestJudge, "targetCancel", commandActor);
	--callClientFunction(player, "delegateCommand", harvestJudge, "turnToTarget", commandActor, harvestType, nodeGrade);

	player:ChangeState(50)



	if harvestType == commandMine then
		player:SendGameMessage(harvestJudge, 26, MESSAGE_TYPE_SYSTEM, 1, nodeGrade)

		callClientFunction(player, "delegateCommand", harvestJudge, "openInputWidget", commandActor, harvestType, nodeGrade)
		callClientFunction(player, "delegateCommand", harvestJudge, "orderInputWidget", commandActor, nodeRemainder, nil, harvestType)
		callClientFunction(player, "delegateCommand", harvestJudge, "textInputWidget", commandActor, harvestType, harvestJudge, nil, 0, 0, 0, 0)



		while harvestAttempts > 0 do

			-- "Aim", 0 = Top of bar, 100 = Bottom.     Mooglebox conversion is +5 = 0, 0 = 50, -5 = 100
			menuResult, sliderPhase, ret3 = callClientFunction(player, "delegateCommand", harvestJudge, "askInputWidget", commandActor, harvestType, 1, showTutorial, false, false, nil, false)

			if debugMsg then player:SendMessage(0x20, "", tostring(menuResult).." unk: "..tostring(sliderPhase).." unk: "..tostring(ret3)) end

			if menuResult == 22701 then     -- Begin.
				player:SendGameMessage(harvestJudge, 36, MESSAGE_TYPE_SYSTEM)
				nodeRemainder = remainderC
				callClientFunction(player, "delegateCommand", harvestJudge, "orderInputWidget", commandActor, nodeRemainder, nil, harvestType)

				while true do

					-- "Strike" 0 = Empty, 100 = Filled.   Mooglebox sweespots are 1=10, 2=30, 3=70, 4=100 for Mining
					chosenCommand, currentPower = callClientFunction(player, "delegateCommand", harvestJudge, "askInputWidget", commandActor, harvestType, 2, showTutorial, false, false, nil, false) -- Strike

					if debugMsg then player:SendMessage(0x20, "", tostring(chosenCommand).." Power: "..tostring(currentPower)) end


					if chosenCommand == 22702 then      -- Cancel.
						harvestAttempts = harvestAttempts - 1

						if harvestAttempts > 0 then
							-- You can make # more gathering attempts.
							player:SendGameMessage(player, worldMaster, 40344, 0x20, harvestAttempts)
						else
							-- There is nothing left to gather at this location.
							player:SendGameMessage(player, worldMaster, 40339, 0x20, harvestAttempts)
						end
						break
					elseif chosenCommand == 22703 then  -- Strike.

						player:PlayAnimation(minerAnim[math.random(1,3)])

						nodeRemainder = nodeRemainder - 20
						if nodeRemainder < 0 then
							nodeRemainder = 0
						end



						callClientFunction(player, "delegateCommand", harvestJudge, "orderInputWidget", commandActor, nodeRemainder, false, harvestType)


						callClientFunction(player, "delegateCommand", harvestJudge, "textInputWidget", commandActor, harvestType, harvestJudge, 25, item, 4, 1, 0)

						if nodeRemainder == 0 then
							harvestAttempts = harvestAttempts - 1

							if harvestAttempts > 0 then
								-- You can make # more gathering attempts.
								player:SendGameMessage(player, worldMaster, 40344, 0x20, harvestAttempts)
							else
								-- There is nothing left to gather at this location.
								player:SendGameMessage(player, worldMaster, 40339, 0x20, harvestAttempts)
							end

							wait(2)
							break
						end

					elseif chosenCommand == 22710 then
						sendTutorial(player, harvestJudge, 2)
					end

				end

			elseif menuResult == 22702 then -- Cancel.
				break
			elseif menuResult == 22710 then
				sendTutorial(player, harvestJudge, 1)
			end
		end

	elseif harvestType == commandLog then

	elseif harvestType == commandFish then

	end

	if harvestAttempts == 0 then
		player:SendGameMessage(harvestJudge, 31, MESSAGE_TYPE_SYSTEM)
	end

	callClientFunction(player, "delegateCommand", harvestJudge, "closeInputWidget", commandActor, harvestType)


	player:ChangeState(0)
	player:EndEvent()

end

function sendTutorial(player, harvestJudge, id)

	if id == 1 then
		player:SendGameMessage(harvestJudge, 1, MESSAGE_TYPE_SYSTEM)
		wait(3)
		player:SendGameMessage(harvestJudge, 4, MESSAGE_TYPE_SYSTEM)
	elseif id == 2 then
		player:SendGameMessage(harvestJudge, 7, MESSAGE_TYPE_SYSTEM)
		wait(3)
		player:SendGameMessage(harvestJudge, 10, MESSAGE_TYPE_SYSTEM)
		wait(3)
		player:SendGameMessage(harvestJudge, 13, MESSAGE_TYPE_SYSTEM)
		wait(3)
		player:SendGameMessage(harvestJudge, 16, MESSAGE_TYPE_SYSTEM)
	end

end