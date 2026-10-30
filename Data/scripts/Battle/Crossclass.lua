--[[
Setting actions from other classes. A class gets 1 slot at Lv1-9, 2 at Lv10 and one more every 5
levels up to 10; a job gets 3, 4 at Lv40 and 5 at Lv50, and its base class's actions are free.
Any learned action can be set at any level: damage already scales from the caster's own level.
--]]

crossclass = crossclass or {}

-- Job id -> base class id; job id -> the two other classes it may borrow from.
crossclass.JOB_BASE = { [15] = 2, [16] = 3, [17] = 4, [18] = 7, [19] = 8, [26] = 22, [27] = 23 }
crossclass.JOB_PAIRS = {
	[16] = { [4] = true, [23] = true },   -- PLD: MRD, CNJ
	[15] = { [8] = true, [7] = true },    -- MNK: LNC, ARC
	[17] = { [3] = true, [2] = true },    -- WAR: GLA, PGL
	[19] = { [2] = true, [7] = true },    -- DRG: PGL, ARC
	[18] = { [23] = true, [22] = true },  -- BRD: CNJ, THM
	[27] = { [3] = true, [2] = true },    -- WHM: GLA, PGL
	[26] = { [2] = true, [7] = true },    -- BLM: PGL, ARC
}
crossclass.DOM = { [22] = true, [23] = true, [26] = true, [27] = true }

-- Own class and its job only.
crossclass.EXCLUSIVE = {
	[27102] = true, [27104] = true, [27105] = true, [27112] = true, [27113] = true, [27114] = true,
	[27116] = true, [27119] = true, [27141] = true, [27143] = true, [27153] = true, [27154] = true,
	[27155] = true, [27157] = true, [27158] = true, [27183] = true, [27184] = true, [27185] = true,
	[27195] = true, [27196] = true, [27197] = true, [27198] = true, [27224] = true, [27225] = true,
	[27226] = true, [27230] = true, [27231] = true, [27235] = true, [27236] = true, [27258] = true,
	[27259] = true, [27261] = true, [27262] = true, [27263] = true, [27271] = true, [27276] = true,
	[27279] = true, [27302] = true, [27304] = true, [27306] = true, [27308] = true, [27309] = true,
	[27312] = true, [27314] = true, [27315] = true, [27341] = true, [27342] = true, [27343] = true,
	[27347] = true, [27348] = true, [27352] = true, [27354] = true, [27356] = true,
}
-- "Requires: Discipline of War".
crossclass.DOW_ONLY = {
	[27110] = true, [27111] = true, [27115] = true, [27117] = true, [27150] = true, [27151] = true,
	[27152] = true, [27190] = true, [27191] = true, [27193] = true, [27194] = true, [27199] = true,
	[27228] = true, [27229] = true, [27233] = true, [27234] = true, [27269] = true, [27270] = true,
	[27273] = true, [27274] = true, [27275] = true, [27278] = true,
}

function crossclass.cap(classOrJob, level)
	if crossclass.JOB_BASE[classOrJob] ~= nil then
		if level >= 50 then return 5 elseif level >= 40 then return 4 else return 3 end
	end
	if level < 10 then return 1 end
	return math.min(10, 2 + math.floor((level - 10) / 5))
end

-- Own-class actions use no slot.
function crossclass.isOwn(current, commandClass)
	return commandClass == current or crossclass.JOB_BASE[current] == commandClass
end

-- Returns nil if the ability may be set by a character whose class/job is current, else the
-- worldMaster text id to refuse with.
function crossclass.canSet(current, ability)
	if crossclass.isOwn(current, ability.job) then return nil end
	if crossclass.JOB_BASE[ability.job] ~= nil then return 30746 end      -- another job's action
	if crossclass.EXCLUSIVE[ability.id] then return 30746 end             -- "Actions exclusive to other classes or jobs cannot be set."
	if crossclass.DOW_ONLY[ability.id] and crossclass.DOM[current] then return 30723 end -- "That action cannot be set to an action slot."
	local pairs_ = crossclass.JOB_PAIRS[current]
	if pairs_ ~= nil and not pairs_[ability.job] then return 30750 end    -- "Your current job prevents you from setting that action."
	return nil
end

-- Number of other-class actions on the hotbar (30 slots from commandBorder).
function crossclass.countSet(player, current)
	local wm = GetWorldManager()
	local n = 0
	local border = player.charaWork.commandBorder
	for i = border, border + 29 do
		local id = player.charaWork.command[i]
		if id ~= nil and id ~= 0 then
			local cmd = wm:GetBattleCommand(id)
			if cmd ~= nil and cmd.job ~= 0 and not crossclass.isOwn(current, cmd.job) then n = n + 1 end
		end
	end
	return n
end

return crossclass
