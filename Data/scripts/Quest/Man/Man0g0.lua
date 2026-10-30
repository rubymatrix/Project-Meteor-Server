require("Global")
require("Quest")

--[[

Quest Script

Name:   Sundered Skies
Code:   Man0g0
Id:     110005
Prereq: None (Given on chara creation)
Notes:

Using PrivateAreaMasterPast Type 1
]]

local seq000_onTalk, seq010_onTalk, saveFlag, doContentArea

-- Sequence Numbers
local SEQ_000 = 0  -- Intro with Yda & Papalymo
local SEQ_005 = 5  -- Combat tutorial
local SEQ_010 = 10 -- Gridania section

-- Actor Class Ids
local YDA                 = 1000009
local PAPALYMO            = 1000010

local FARRIMOND           = 1000017
local CECILIA             = 1000683
local SWETHYNA            = 1000680
local TKEBBE              = 1000876
local LONSYGG             = 1000951
local PUSH_ADV_GUILD      = 1099046
local BLOCKER1            = 1099047

-- Non-interactive NPCs
local GUILD_ANENE         = 1000427
local GUILD_SYLBERT       = 1000428 -- No source
local GUILD_HONGA_VUNGA   = 1000429
local GUILD_NONCO_MENANCO = 1000430
local GUILD_LTANDHAA      = 1000431
local GUILD_POFUFU        = 1000432
local GUILD_ODILIE        = 1000434 -- No source
local GUILD_BASEWIN       = 1000435 -- No source
local GUILD_SEIKFRAE      = 1000436 -- No source
local GUILD_EDASSHYM      = 1000437
local GUILD_TIERNEY       = 1000456
local GUILD_GONTRANT      = 1000457
local GUILD_VKOROLON      = 1000458
local GUILD_EMONI         = 1001183
local GUILD_GYLES         = 1001184
local GUILD_PENELOPE      = 1700001 -- No source

-- Quest Markers
local MRKR_LONSYGG        = 11000501  -- Obsolete.  Pre-1.19 location for this npc
local MRKR_YDA            = 11000502
local MRKR_PAPALYMO       = 11000503
local MRKR_GUILD          = 11000504

-- Quest Flags
local FLAG_SEQ000_MINITUT0    = 0 -- Talked to Yda.
local FLAG_SEQ000_MINITUT1    = 1 -- Talked to Papalymo.
local FLAG_SEQ000_MINITUT2    = 2 -- Talked to Yda again.
local FLAG_SEQ000_PUSHTUT     = 3 -- Saw the targeting tutorial Yda's push plays.
local FLAG_SEQ010_TKEBBE      = 0 -- Talked to T'kebbe (optional)

--[[
processEvent000_0
processEvent000_1
processEvent000_2
processEvent000_3
processEvent000_4
processEvent010_1
processEvent020_1
processEvent020_2
processEvent020_3
processEvent020_4
processEvent020_5
processEvent020_6
processTtrNomal001withHQ -- Intro CS
processTtrNomal001
processTtrNomal002(arg1)
processTtrNomal003(arg1)
processTtrMini001 -- Unused
processTtrMini002 -- Unused
processTtrMini003
processTtrAfterBtl001
processTtrBtl001(arg1)
processTtrBtlMagic001(arg1)
processTtrBtl002(arg1)
processTtrBtl003
processTtrBlkNml001 - Aims at 1600102 Lonsygg
processTtrBlkNml002
processTtrBtl004
processInformDialogAsQuest
--]]

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	local data = quest:GetData()

	if sequence == SEQ_000 then
		-- Setup states incase we loaded in.
		local ydaFlag = ((not data:GetFlag(FLAG_SEQ000_MINITUT0)) or (data:GetFlag(FLAG_SEQ000_MINITUT1))) and QFLAG_TALK or QFLAG_OFF
		local papalymoFlag = ((not data:GetFlag(FLAG_SEQ000_MINITUT1)) and data:GetFlag(FLAG_SEQ000_MINITUT0) and QFLAG_TALK or QFLAG_OFF)

		quest:SetENpc(YDA, ydaFlag, true, not data:GetFlag(FLAG_SEQ000_MINITUT0))
		quest:SetENpc(PAPALYMO, papalymoFlag)
	elseif sequence == SEQ_010 then
		quest:SetENpc(FARRIMOND)
		quest:SetENpc(CECILIA)
		quest:SetENpc(SWETHYNA)
		quest:SetENpc(TKEBBE, not data:GetFlag(FLAG_SEQ010_TKEBBE) and QFLAG_TALK or QFLAG_OFF)
		quest:SetENpc(LONSYGG)
		quest:SetENpc(BLOCKER1, QFLAG_OFF, false, true)
		quest:SetENpc(PUSH_ADV_GUILD, QFLAG_PUSH, false, true)
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()

	if sequence == SEQ_000 then
		seq000_onTalk(player, quest, npc, classId)
	elseif sequence == SEQ_010 then
		seq010_onTalk(player, quest, npc, classId)
	end
	quest:UpdateENPCs()
end

function onPush(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()
	local data = quest:GetData()

	if sequence == SEQ_000 then
		if classId == YDA and not data:GetFlag(FLAG_SEQ000_PUSHTUT) and not data:GetFlag(FLAG_SEQ000_MINITUT0) then
		   -- A click on Yda during the tutorial reaches the server as the tutorial ends and leaves
		   -- the client locked, so her talk stays off until it is over.
		   quest:SetENpc(YDA, QFLAG_TALK, false, false)
		   callClientFunction(player, "delegateEvent", player, quest, "processTtrNomal002")
		   saveFlag(quest, FLAG_SEQ000_PUSHTUT)
		end
		player:EndEvent()
	elseif sequence == SEQ_010 then
		if classId == BLOCKER1 then
			callClientFunction(player, "delegateEvent", player, quest, "processTtrBlkNml001")
			player:EndEvent()
			GetWorldManager():DoPlayerMoveInZone(player, 109.966, 7.559, -1206.117, -2.7916)
			return
		elseif classId == PUSH_ADV_GUILD then
			player:ReplaceQuest(quest, "Man0g1")
			return
		end
	end
	quest:UpdateENPCs()
end

function onNotice(player, quest, target)
	callClientFunction(player, "delegateEvent", player, quest, "processTtrNomal001withHQ")

	--callClientFunction(player, "delegateEvent", player, quest, "processTtrNomal001"); -- On relog pre-combat
	--callClientFunction(player, "delegateEvent", player, quest, "processTtrAfterBtl001"); -- On relog post-combat
	player:EndEvent()
	quest:UpdateENPCs()
end

function seq000_onTalk(player, quest, npc, classId)
	local data = quest:GetData()
	if classId == YDA then
		if not data:GetFlag(FLAG_SEQ000_MINITUT0) then -- If Talk tutorial
			if data:GetFlag(FLAG_SEQ000_PUSHTUT) then
				callClientFunction(player, "delegateEvent", player, quest, "processTtrNomal003")
				saveFlag(quest, FLAG_SEQ000_MINITUT0) -- Disable Yda's PushEvent and set up Papalymo
			end
		elseif data:GetFlag(FLAG_SEQ000_MINITUT1) then -- If Talked to after Papaylmo
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010_1")
			doContentArea(player, quest, npc) -- Set up Combat Tutorial
			return
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000_3")
		end
	elseif classId == PAPALYMO then
		if data:GetFlag(FLAG_SEQ000_MINITUT0) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000_2")
			saveFlag(quest, FLAG_SEQ000_MINITUT1)
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000_2")
		end
	end

	player:EndEvent()
end

function seq010_onTalk(player, quest, npc, classId)
	local data = quest:GetData()

	if classId == SWETHYNA then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_2")
	elseif classId == CECILIA then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_3")
	elseif classId == FARRIMOND then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_4")
	elseif classId == TKEBBE then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_5")
		saveFlag(quest, FLAG_SEQ010_TKEBBE)
	elseif classId == LONSYGG then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_6")
	elseif classId == PUSH_ADV_GUILD then
		player:ReplaceQuest(quest, "Man0g1")
		return
	end

	player:EndEvent()
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:GetSequence()
	local possibleMarkers = {}
	local data = quest:GetData()

	if sequence == SEQ_000 then

		if (not data:GetFlag(FLAG_SEQ000_MINITUT0)) or (data:GetFlag(FLAG_SEQ000_MINITUT1))  then
			table.insert(possibleMarkers, MRKR_YDA)
		end

		if (data:GetFlag(FLAG_SEQ000_MINITUT0)) and (not data:GetFlag(FLAG_SEQ000_MINITUT1)) then
			table.insert(possibleMarkers, MRKR_PAPALYMO)
		end

	elseif sequence == SEQ_010 then
		table.insert(possibleMarkers, MRKR_GUILD)
	end

	return unpack(possibleMarkers)
end

function saveFlag(quest, flag)
	local data = quest:GetData()
	data:SetFlag(flag)
	data:Save()
end

function doContentArea(player, quest, npc)
	quest:GetData():ClearData()
	quest:StartSequence(SEQ_005)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "man0g01", "SimpleContent30010", "Quest/QuestDirectorMan0g001")

	if contentArea == nil then
		player:EndEvent()
		return
	end

	director = contentArea:GetContentDirector()
	player:AddDirector(director)
	director:StartDirector(false)
	player:SetLoginDirector(director)

	-- The talk event ends before the kick: a notice kicked inside it is corrupted on the client.
	player:EndEvent()
	player:KickEvent(director, "noticeEvent", true)

	GetWorldManager():DoZoneChangeContent(player, contentArea, 362.4087, 4, -703.8168, 1.5419, 16)
	return
end
