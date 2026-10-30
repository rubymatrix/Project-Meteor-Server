--[[

HarvestJudge 

Operates the harvesting system for mining, logging, and fishing.

Functions:

loadTextData()
    Desc: Loads all gamesheets needed and instantiates a HarvestJudge.
	Params: None
        
targetCancel()
    Desc: Cancels the player's target.
    Params: None
    
turnToTarget()
    Desc: Turns to a direction
    Params: * harvestType           - Harvest command used.  Client script has a _waitForTurning() for Quarry/Harvest/Spearfishing
            * direction             - The pi radian to turn the character towards, server has to calculate the vector between the actors.
    
openInputWidget()
    Desc: Inits the widget system (call first).
    Params: * harvestType           - Determines which text strings to load based on the harvestType
            * nodeGrade             - The grade of the node.  Retail went up to grade 5.

orderInputWidget()
    Desc: Updates the node HP.
    Params: * nodeRemainder         - Range goes from 0-100
            * unk1                  -
            * harvestType           - Doesn't appear to visually do anything? Script checks against harvest command id
    
textInputWidget()
    Desc: Sets the result text after a minigame is performed.
    Params: * harvestType           - The harvest command
            * unk1                  - Actor to grab text from?  Set to the harvestJudge so the rest of params function, otherwise widget prints whatever is set here.
            * textId                - Id from the harvestJudge sheet.
            * textIdParam1          - Used to fill in textId details if the sheet requires it, Eg. textId #25 requires an itemId, HQ quality, and yield filled in.
            * textIdParam2          
            * textIdParam3          
            * commandId             - If textId = nil, client script sets it to 64 and this parameter is assigned to Param1
                                    - Why does this exist?  Setting textId to 64 and using commandId as textIdParam1 does the same job.
            
askInputWidget()
    Desc: Gets user input after opening a ask widget.  Returns two values, one being the id of the chosen command, and the "currentPower" of the minigame.
    Params: * harvestType           - The harvest command
            * phase                 - The current minigame window to show.  Valid ids 1 & 2.
            * showTutorial          - Shows Tutorial menu option in the window if not = 0.
            * showFishWait          -
            * showFishWaitAndJig    -
            * updateFishHP          -
            * showRareCatalystEffect-
 
closeInputWidget()
    Desc: Closes the widget system (call last).
    Params: * harvestType           - The harvest command

rangeInputWidget()
    Desc: Unknown, currently errors the client...
    Params: * harvestType
            * phase 
            * goodMin
            * goodMax
            * bool 

--]]

local minerAnim = {0x14001000, 0x14002000, 0x14003000}

--[[Mooglebox - Aim
+5 = 0
+4 = 10
+3 = 20
+2 = 30
+1 = 40
 0 = 50
-1 = 60
-2 = 70 
-3 = 80
-4 = 90
-5 = 100  

Sweetspots   1=10  2=30  3=70  4=100 for Mining
remainder    A=40  B=60  C=70  D=80
--]]


local nodeContainer = { -- harvestAttempts, #ofItemsBecauseLuaIsShitAtTableLength, Item1, Item2, etc
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



						--player:SendGameMessage(harvestJudge, 25, MESSAGE_TYPE_SYSTEM, item, 4, 1);
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

					elseif chosenCommand == 22710 then -- "Strike" Tutorial.
						sendTutorial(player, harvestJudge, 2)
					end

				end

			elseif menuResult == 22702 then -- Cancel.
				break
			elseif menuResult == 22710 then -- "Aim" Tutorial.
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