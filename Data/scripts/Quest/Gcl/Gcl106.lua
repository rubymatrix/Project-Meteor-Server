require("Global")
require("Quest")
require("QuestDuty")
require("InstanceRaid")
require("GcCompany")

--[[

Quest Script

Name: 	United We Stand
Code: 	Gcl106 (client class for 111432 / 111632 / 111832)
Id: 	111432 / 111632 / 111832, one per company (gc_company.lua).
Prereq: Gcl105 (111431 / 111631 / 111831). Level 45, company rank 11.

Spec: decomp/docs/gridania_story_quests.md §0.6, §15.
 - Offer: Flame Commander Ryder in Mor Dhona (by Jagged Crest Cave, DESIGN):
   processEvent_CommonStart_Jakys_01(2) (1 = accepted). Repeat processEvent_CommonFollow_Jakys_01(2).
   The officer's hint while the quest is on offer: processEvent_LimsaHint_Guincum_01 /
   GridaniaHint_Fulke_01 / UldahHint_Aubray_01.
 - SEQ_000 Serpent Commander Yarborough: processEvent_CommonInfo_Vevina_01(2, 13) -> SEQ_005.
 - SEQ_005 the Castrum Novum entry (AetheryteBeastChildGuide spawn by Jagged Crest Cave, DESIGN: the
   client names no entry object) -> InstanceRaid.lua "beacon_battle". A clear -> onRaidCleared -> SEQ_020.
 - SEQ_020 the company's commander at the camp sends the player home: Flutaint
   processEvent_CommonNavi_Quinquerol_01(a3) (Twin Adder), Ryder CommonNavi_Jakys_01(a3) (Immortal
   Flames), "Rashaht" CommonNavi_Rashaht_01 (Maelstrom: Storm Commander Rhiki, by the client's
   naming of the neighbouring commander classes [inference]). The
   hall guide warps the player in: Kinnison GridaniaWarp_Kinnison_01 (the Lotus Stand), Zanthael
   LimsaWarp_Zanthael_01 (the stateroom), Mumutano UldahWarp_Mumutano_01 (the Fragrant Chamber); 1 = in.
   There Cid processEvent_CommonInstance_Cid_01(0, a3) and the leader <City>Instance_<Leader>_01(a3)
   (Shinkan / Merlwyb / Raubahn) with a3 = 1 once Cid was spoken to [inference] -> SEQ_025.
 - SEQ_025 the leader's _02(1); the marshal's _02 (Swethryk / Eynzahr / Eline) + rewards (tier 2 for all
   three companies in the party at the clear), then back out of the hall.
Positions: seed_msq_gridania_30_gc.sql, seed_gc_story_shared.sql (DESIGN).

]]

local RAID_ID = 13	-- xtx/raidDungeon: Castrum Novum Transmission Tower

-- Sequence Numbers
local SEQ_000 = 0	-- Get the briefing from Commander Yarborough.
local SEQ_005 = 5	-- Breach Castrum Novum.
local SEQ_020 = 20	-- Report to the leader and Cid.
local SEQ_025 = 25	-- Collect the reward from the marshal.

-- Actor Class Ids (officers, leaders, marshals, hall guides: gc_company.lua)
local RYDER		= 1001815	-- "Jakys"
local YARBOROUGH	= 1001808	-- "Vevina"
local FLUTAINT	= 1001809	-- "Quinquerol"
local RHIKI		= 1001810	-- "Rashaht" [inference: Quinquerol/Vevina are the classes beside it]
local CID			= 1001572

-- Per company: the officer's hint, the camp commander's directions, the hall and its guide, the leader
-- and the marshal there, with their client functions.
local COMPANY_EVENTS = {
	[GC_MAELSTROM] = {
		hint = "processEvent_LimsaHint_Guincum_01",
		navi = RHIKI, naviFn = "processEvent_CommonNavi_Rashaht_01",
		guideFn = "processEvent_LimsaWarp_Zanthael_01",
		leaderFn1 = "processEvent_LimsaInstance_Merlwyb_01", leaderFn2 = "processEvent_LimsaInstance_Merlwyb_02",
		marshalFn1 = "processEvent_LimsaInstance_Eynzahr_01", marshalFn2 = "processEvent_LimsaInstance_Eynzahr_02",
	},
	[GC_TWINADDER] = {
		hint = "processEvent_GridaniaHint_Fulke_01",
		navi = FLUTAINT, naviFn = "processEvent_CommonNavi_Quinquerol_01",
		guideFn = "processEvent_GridaniaWarp_Kinnison_01",
		leaderFn1 = "processEvent_GridaniaInstance_Shinkan_01", leaderFn2 = "processEvent_GridaniaInstance_Shinkan_02",
		marshalFn1 = "processEvent_GridaniaInstance_Swethryk_01", marshalFn2 = "processEvent_GridaniaInstance_Swethryk_02",
	},
	[GC_FLAMES] = {
		hint = "processEvent_UldahHint_Aubray_01",
		navi = RYDER, naviFn = "processEvent_CommonNavi_Jakys_01",
		guideFn = "processEvent_UldahWarp_Mumutano_01",
		leaderFn1 = "processEvent_UldahInstance_Raubahn_01", leaderFn2 = "processEvent_UldahInstance_Raubahn_02",
		marshalFn1 = "processEvent_UldahInstance_Eline_01", marshalFn2 = "processEvent_UldahInstance_Eline_02",
	},
}

-- Quest data flags
local FLAG_BONUS	= 0
local FLAG_CID	= 1

local function isOurs(quest)
	return gcCompanyOfQuestId(quest:GetQuestId()) ~= nil
end

local function events(quest)
	local company, co = gcCompany(quest)
	return company, co, COMPANY_EVENTS[company]
end

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if not isOurs(quest) then
		return
	end
	local company, co, ev = events(quest)
	if sequence == SEQ_ACCEPT then
		-- isSpawned: the public gc1_ story actors exist only for players on this quest (server_eventnpc_quest_gated).
		quest:SetENpc(RYDER, QFLAG_TALK, true, false, false, true)
		quest:SetENpc(co.officer)
		return
	end
	if sequence == SEQ_COMPLETE then
		return
	end
	local function on(cond) return cond and QFLAG_TALK or QFLAG_OFF end
	quest:SetENpc(RYDER, on(sequence == SEQ_020 and ev.navi == RYDER), true, false, false, true)
	quest:SetENpc(YARBOROUGH, on(sequence == SEQ_000), true, false, false, true)
	quest:SetENpc(FLUTAINT, QFLAG_OFF, true, false, false, true)
	if ev.navi == RHIKI then
		quest:SetENpc(RHIKI, on(sequence == SEQ_020), true, false, false, true)
	end
	if sequence >= SEQ_020 then
		quest:SetENpc(co.hallGuide, on(sequence == SEQ_020))
		quest:SetENpc(CID, on(sequence == SEQ_020 and not questFlag(quest, FLAG_CID)))
		quest:SetENpc(co.leader, on(sequence == SEQ_020))
		quest:SetENpc(co.marshal, sequence == SEQ_025 and QFLAG_REWARD or QFLAG_OFF)
		quest:SetENpc(GC_HALLS[co.hall].exitPush, QFLAG_OFF, false, true)
	end
end

function onTalk(player, quest, npc)
	if not isOurs(quest) then
		player:EndEvent()
		return
	end
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()
	local company, co, ev = events(quest)

	local function talk(fn, ...)
		return callClientFunction(player, "delegateEvent", player, quest, fn, ...)
	end

	if sequence == SEQ_ACCEPT then
		if classId == RYDER then
			local accepted = talk("processEvent_CommonStart_Jakys_01", company) == 1
			player:EndEvent()
			if accepted then
				player:AcceptQuest(quest)
			end
			return
		elseif classId == co.officer then
			talk(ev.hint)
		end
		player:EndEvent()
		return
	end

	if ev.navi ~= nil and classId == ev.navi and sequence >= SEQ_020 then
		talk(ev.naviFn, company)
	elseif classId == RYDER then
		talk("processEvent_CommonFollow_Jakys_01", company)
	elseif classId == YARBOROUGH then
		-- a4 = the raid id for {sheet xtx/raidDungeon[int1]}
		talk("processEvent_CommonInfo_Vevina_01", company, RAID_ID)
		if sequence == SEQ_000 then
			quest:StartSequence(SEQ_005)
		end
	elseif classId == FLUTAINT then
		talk("processEvent_CommonNavi_Quinquerol_01", company)
	elseif classId == co.hallGuide then
		if talk(ev.guideFn) == 1 then
			player:EndEvent()
			gcEnterHall(player, co.hall)
			return
		end
	elseif classId == CID then
		if sequence == SEQ_020 and not questFlag(quest, FLAG_CID) then
			-- a3 1 = "already has another way" [inference: 0 on the first talk]
			talk("processEvent_CommonInstance_Cid_01", 0, company)
			setQuestFlag(quest, FLAG_CID)
			quest:UpdateENPCs()
		else
			talk("processEvent_CommonInstance_Cid_02", company)
		end
	elseif classId == co.leader then
		if sequence == SEQ_020 then
			talk(ev.leaderFn1, questFlag(quest, FLAG_CID) and 1 or 0)
			quest:StartSequence(SEQ_025)
		else
			talk(ev.leaderFn2, 1)
		end
	elseif classId == co.marshal then
		if sequence == SEQ_025 then
			talk(ev.marshalFn2)
			local tier = questFlag(quest, FLAG_BONUS) and 2 or 1
			local rewarded = showQuestRewards(player, quest, tier)
			player:EndEvent()
			if rewarded then
				player:CompleteQuest(quest, tier)
				-- the exit push belongs to the quest: leave the hall with it
				local hall = gcHallOfPlayer(player)
				if hall ~= nil then
					gcLeaveHall(player, hall)
				end
			end
			return
		end
		talk(ev.marshalFn1)
	end
	player:EndEvent()
end

function onPush(player, quest, npc)
	local hall = gcHallOfExit(npc:GetActorClassId())
	if isOurs(quest) and hall ~= nil then
		player:EndEvent()
		gcLeaveHall(player, hall)
		return
	end
	player:EndEvent()
end

-- The raid content on a win: the transmitter is down.
function onRaidCleared(player, quest, director, bonus)
	if not isOurs(quest) or quest:GetSequence() ~= SEQ_005 then
		return
	end
	local data = quest:GetData()
	if bonus then data:SetFlag(FLAG_BONUS) else data:ClearFlag(FLAG_BONUS) end
	data:Save()
	quest:StartSequence(SEQ_020)
end

function getJournalInformation(player, quest)
end

function getJournalMapMarkerList(player, quest)
end
