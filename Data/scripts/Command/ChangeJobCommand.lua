require("Global")

--[[
Called when the player equips or unequips a job stone or uses the /job command.
--]]

local setPlayerClass, setPlayerJob, isJob

local classToJob = { -- [classId] = {jobId, jobAnim, jobKeyItem}
	[2] = {15, 0x4000028, 2000202},  -- PGL -> MNK
	[3] = {16, 0x4000029, 2000201},  -- GLD -> PLD
	[4] = {17, 0x4000027, 2000203},  -- MRD -> WAR
	[7] = {18, 0x400002D, 2000205},  -- ARC -> BRD
	[8] = {19, 0x400002C, 2000204},  -- LNC -> DRG
	[22] = {26, 0x400002B, 2000207}, -- THM -> BLM
	[23] = {27, 0x400002A, 2000206}, -- CNJ -> WHM
}

local jobToClass = { -- [jobId] = classId
	[15] = 2,  -- MNK -> PGL
	[16] = 3,  -- PLD -> GLD
	[17] = 4,  -- WAR -> MRD
	[18] = 7,  -- BRD -> ARC
	[19] = 8,  -- DRG -> LNC
	[26] = 22, -- BLM -> THM
	[27] = 23  -- WHM -> CNJ
}


function onEventStarted(player, command, eventType, eventName, jobState)

	local currentClass = player:GetCurrentClassOrJob()
	local jobCheck = isJob(currentClass)
	local hasKeyItem = false

	if jobCheck == false then
		hasKeyItem = player:GetItemPackage(INVENTORY_KEYITEMS):HasItem(classToJob[currentClass][3])
	end

	if jobCheck ~= nil then -- Valid Class/Job ids only
		if jobState == 0 then -- Toggle current class/job state
			if (jobCheck == false) and (hasKeyItem == true) then
				setPlayerJob(player, classToJob[currentClass][1], classToJob[currentClass][2])
			elseif jobCheck == true then
				setPlayerClass(player, jobToClass[currentClass])
			end

		elseif jobState == 1 and (jobCheck == false) and (hasKeyItem == true) then -- Equipping Job stone
			setPlayerJob(player, classToJob[currentClass][1], classToJob[currentClass][2])
		elseif jobState == 2 and (jobCheck == true) then -- Removing Job stone
			setPlayerClass(player, jobToClass[currentClass])
		end
	end

	player:EndEvent()
end


function setPlayerClass(player, id)
	player:SetCurrentJob(0)
	player:PrepareClassChange(id)
	player:DoClassChange(id)
	player:PlayAnimation(0x4001030)
	player:SendGameMessage(player, GetWorldMaster(), 30103, 0x20, 0, 0, player, id)
end

function setPlayerJob(player, id, anim)
	player:SetCurrentJob(id)
	player:PrepareClassChange(id)
	player:DoClassChange(jobToClass[id])
	player:PlayAnimation(anim)
	player:SendGameMessage(player, GetWorldMaster(), 30103, 0x20, 0, 0, player, id)
end

function isJob(id)
	local validId = {
		[2] = 0, [3] = 0, [4] = 0, [7] = 0, [8] = 0, [22] = 0, [23] = 0,
		[15] = 1, [16] = 1, [17] = 1, [18] = 1, [19] = 1, [26] = 1, [27] = 1
	}

	if validId[id] == 0 then
		return false
	elseif validId[id] == 1 then
		return true
	else
		return nil
	end
end