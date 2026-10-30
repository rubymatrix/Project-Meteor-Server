require("Global")
require("Quest")
require("QuestDuty")
require("InstanceRaid")
require("GcCompany")

--[[
United We Stand (Gcl106: 111432 / 111632 / 111832, one per company). Prereq: Gcl105; level 45,
company rank 11. Briefing at Mor Dhona, the Castrum Novum raid, then the company's hall and reward
(tier 2 when all three companies were in the party at the clear).
Walkthrough: Data/Docs/Scripts/Quest/Gcl/Gcl106.md.
--]]

local RAID_ID = 13	-- xtx/raidDungeon: Castrum Novum Transmission Tower

local SEQ_000 = 0	-- Get the briefing from Commander Yarborough.
local SEQ_005 = 5	-- Breach Castrum Novum.
local SEQ_020 = 20	-- Report to the leader and Cid.
local SEQ_025 = 25	-- Collect the reward from the marshal.

-- Officers, leaders, marshals and hall guides are in GcCompany.lua.
local RYDER		= 1001815	-- "Jakys"
local YARBOROUGH	= 1001808	-- "Vevina"
local FLUTAINT	= 1001809	-- "Quinquerol"
local RHIKI		= 1001810	-- "Rashaht": a guess, from the classes beside it
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

local function say(player, quest, fn, ...)
	return callClientFunction(player, "delegateEvent", player, quest, fn, ...)
end

-- Officer, guide, leader, marshal and navi classes differ by GC, so they are checked here in order.
-- The navi comes first: Ryder is also the Flames' navi.
local function progressTalk(player, quest, npc, company, co, ev)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()
	if ev.navi ~= nil and classId == ev.navi and sequence >= SEQ_020 then
		say(player, quest, ev.naviFn, company)
	elseif classId == RYDER then
		say(player, quest, "processEvent_CommonFollow_Jakys_01", company)
	elseif classId == YARBOROUGH then
		-- a4 = the raid id for {sheet xtx/raidDungeon[int1]}
		say(player, quest, "processEvent_CommonInfo_Vevina_01", company, RAID_ID)
		if sequence == SEQ_000 then
			quest:StartSequence(SEQ_005)
		end
	elseif classId == FLUTAINT then
		say(player, quest, "processEvent_CommonNavi_Quinquerol_01", company)
	elseif classId == co.hallGuide then
		if say(player, quest, ev.guideFn) == 1 then
			player:EndEvent()
			gcEnterHall(player, co.hall)
			return true
		end
	elseif classId == CID then
		if sequence == SEQ_020 and not questFlag(quest, FLAG_CID) then
			-- a3 1 = "already has another way" (0 on the first talk is a guess)
			say(player, quest, "processEvent_CommonInstance_Cid_01", 0, company)
			setQuestFlag(quest, FLAG_CID)
			quest:UpdateENPCs()
		else
			say(player, quest, "processEvent_CommonInstance_Cid_02", company)
		end
	elseif classId == co.leader then
		if sequence == SEQ_020 then
			say(player, quest, ev.leaderFn1, questFlag(quest, FLAG_CID) and 1 or 0)
			quest:StartSequence(SEQ_025)
		else
			say(player, quest, ev.leaderFn2, 1)
		end
	elseif classId == co.marshal then
		if sequence == SEQ_025 then
			say(player, quest, ev.marshalFn2)
			local tier = questFlag(quest, FLAG_BONUS) and 2 or 1
			local rewarded = showQuestRewards(player, quest, tier)
			player:EndEvent()
			if rewarded then
				player:CompleteQuest(quest, tier)
				-- The exit push belongs to the quest: leave the hall with it.
				local hall = gcHallOfPlayer(player)
				if hall ~= nil then
					gcLeaveHall(player, hall)
				end
			end
			return true
		end
		say(player, quest, ev.marshalFn1)
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		[RYDER] = function(player, quest, npc, company)
			local accepted = say(player, quest, "processEvent_CommonStart_Jakys_01", company) == 1
			player:EndEvent()
			if accepted then
				player:AcceptQuest(quest)
			end
			return true
		end,
		other = function(player, quest, npc, company, co, ev)
			if npc:GetActorClassId() == co.officer then
				say(player, quest, ev.hint)
			end
			player:EndEvent()
			return true
		end,
	},
	other = progressTalk,
}

function onTalk(player, quest, npc)
	if not isOurs(quest) then
		player:EndEvent()
		return
	end
	if runQuestHandler(talk, player, quest, npc, events(quest)) then return end
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
