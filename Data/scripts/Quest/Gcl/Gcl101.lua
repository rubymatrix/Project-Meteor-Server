require("Global")
require("Quest")
require("InstanceRaid")
require("GcCompany")

local askRaid, allCrystals, questFlagSet

--[[

Quest Script

Name: 	It Kills with Fire
Code: 	Gcl101 (client class for 111416 Maelstrom, 111616 Twin Adder, 111816 Immortal Flames)
Id: 	111416 / 111616 / 111816, one per company (gc_company.lua).
Prereq: Com0l7 / Com0g7 / Com0u7 (enlisted). Level 30.

Spec: decomp/docs/gridania_story_quests.md §0.6, §10.
 - Offer: the company officer (Guincum / Fulke / Aubrey), processEvent<Officer>Start (1 = accepted).
 - SEQ_000 Louisoix at Apkallus Falls: processEvent_010(initial town) hands over the receptacle.
 - SEQ_001 kill the six beasts (onKillBNpc, world kills): int2..int6 wind/water/earth/lightning/ice,
   str7 "a" fire. All six -> SEQ_002.
 - SEQ_002 Louisoix processEvent_030: the crystals are merged (str7 "b").
 - SEQ_003 kill Voidtongue Ahzabb Chah (W. Thanalan): the Inferno Flambeau (str7 "c").
 - SEQ_004 Louisoix processEvent_050 + _050_1/_2/_3/_6 (the raid briefing).
 - SEQ_005 Louisoix (InstanceRaidGuide): askEnterInstanceRaid(4) -> InstanceRaid.lua "lesser_ifrit".
   No -> processEvent_060. A refused entry sends its own 520xx text.
   A clear calls onRaidCleared -> SEQ_006 (bonus party noted for the reward tier).
 - SEQ_006 Louisoix processEvent_070(a3, level); SEQ_007 the officer processEvent_080_L/_G/_U(bonus) + rewards.
The 7th journal parameter is a string (spec §10): getJournalInformation returns it as one.
NPC spawns: the officers (seed_world_npcs_02_spawns, seed_msq_gridania_20_com0g), Louisoix (public 206).
Markers 111810 (client/docs/gc_quest_contracts.md §2.1; the beast-to-spot pairing is [inference]).

]]

-- Per company: the officer's offer and turn-in functions (the shared ones take the company, spec §0.2).
local COMPANY_EVENTS = {
	[GC_MAELSTROM]	= { start = "processEventGuincumStart", turnIn = "processEvent_080_L" },
	[GC_TWINADDER]	= { start = "processEventFulkeStart",   turnIn = "processEvent_080_G" },
	[GC_FLAMES]		= { start = "processEventAubreyStart",  turnIn = "processEvent_080_U" },
}

-- Sequence Numbers
local SEQ_000 = 0	-- Find Louisoix at Apkallus Falls.
local SEQ_001 = 1	-- Kill six beasts for their echo crystals.
local SEQ_002 = 2	-- Report to Louisoix.
local SEQ_003 = 3	-- Take the Inferno Flambeau from Voidtongue Ahzabb Chah.
local SEQ_004 = 4	-- Report to Louisoix.
local SEQ_005 = 5	-- Speak to Louisoix to fight Ifrit.
local SEQ_006 = 6	-- Ifrit beaten; report to Louisoix.
local SEQ_007 = 7	-- Report to Fulke.

-- Actor Class Ids (the officer: gc_company.lua)
local LOUISOIX	= 1060022

-- World NMs (server_battlenpc_pools 100017/100149/100321/100333/100120/100083/100376); the order is the
-- journal's int2..int6, then the fire crystal (str7 "a").
local KILLS = {
	2102718,	-- barometz (wind), NW of Camp Bloodshore
	2104212,	-- slippery sykes (water), SE of Camp Bloodshore
	2103005,	-- nest commander (earth), NW of Camp Horizon
	2100114,	-- pyrausta (lightning), W of Camp Horizon
	2105915,	-- queen bolete (ice), SW of Camp Tranquil
	2100510,	-- jackanapes (fire), SE of Camp Tranquil
}
local VOIDTONGUE	= 2162061	-- Voidtongue Ahzabb Chah, cave S of Nophica's Wells

-- Quest data flags: 0-5 = KILLS[i]; 6 the Inferno Flambeau; 7 bonus party at the clear
local FLAG_FLAMBEAU	= 6
local FLAG_BONUS		= 7

local RAID_KEY = "lesser_ifrit"

local function isOurs(quest)
	return gcCompanyOfQuestId(quest:GetQuestId()) ~= nil
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
	local _, co = gcCompany(quest)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(co.officer, QFLAG_TALK)
	elseif sequence == SEQ_007 then
		quest:SetENpc(co.officer, QFLAG_REWARD)
		quest:SetENpc(LOUISOIX)
	elseif sequence ~= SEQ_COMPLETE then
		quest:SetENpc(co.officer)
		local flag = QFLAG_TALK
		if sequence == SEQ_001 or sequence == SEQ_003 then
			flag = QFLAG_OFF
		end
		quest:SetENpc(LOUISOIX, flag)
	end
end

function onTalk(player, quest, npc)
	if not isOurs(quest) then
		player:EndEvent()
		return
	end
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()
	local company, co = gcCompany(quest)
	local events = COMPANY_EVENTS[company]

	if sequence == SEQ_ACCEPT then
		if classId == co.officer then
			local accepted = callClientFunction(player, "delegateEvent", player, quest, events.start) == 1
			player:EndEvent()
			if accepted then
				player:AcceptQuest(quest)
			end
			return
		end
		player:EndEvent()
		return
	end

	if classId == co.officer then
		if sequence == SEQ_007 then
			local bonus = questFlagSet(quest, FLAG_BONUS)
			callClientFunction(player, "delegateEvent", player, quest, events.turnIn, bonus and 1 or 0)
			local tier = bonus and 2 or 1
			local rewarded = showQuestRewards(player, quest, tier)
			player:EndEvent()
			if rewarded then player:CompleteQuest(quest, tier) end
			return
		end
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_000", company)
	elseif classId == LOUISOIX then
		if sequence == SEQ_000 then
			-- lines 39/42 name the player's Scion contact by initial town (int1 = a3)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_010", player:GetInitialTown())
			quest:StartSequence(SEQ_001)
		elseif sequence == SEQ_001 then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_010_1")
		elseif sequence == SEQ_002 then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_030")
			quest:StartSequence(SEQ_003)
		elseif sequence == SEQ_003 then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_030_1")
		elseif sequence == SEQ_004 then
			-- the briefing is split in parts with no talk turn of their own; _050_6 closes the turn
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_050")
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_050_1")
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_050_2")
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_050_3")
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_050_6")
			quest:StartSequence(SEQ_005)
		elseif sequence == SEQ_005 then
			askRaid(player, quest)
			return
		elseif sequence == SEQ_006 then
			-- a3 picks extra lines for companies 1/3 [inference: company]; a4 >= 45 adds 94/95 [inference: level]
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_070", company, player:GetLevel())
			quest:StartSequence(SEQ_007)
		elseif sequence == SEQ_007 then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_070_1")
		end
	end
	player:EndEvent()
end

-- Louisoix is an InstanceRaidGuide: askEnterInstanceRaid(contentID) runs on him.
function askRaid(player, quest)
	local yes = callClientFunction(player, "askEnterInstanceRaid", getInstanceRaid(RAID_KEY).contentId)
	if yes ~= true and yes ~= 1 then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_060")
		player:EndEvent()
		return
	end
	player:EndEvent()
	if enterInstanceRaid(RAID_KEY, player) == nil then
		printf("Gcl101: raid entry refused for %s", tostring(player.DisplayName))
	end
end

-- The raid content on a win: Ifrit is beaten (every participant on this quest).
function onRaidCleared(player, quest, director, bonus)
	if not isOurs(quest) or quest:GetSequence() ~= SEQ_005 then
		return
	end
	local data = quest:GetData()
	if bonus then
		data:SetFlag(FLAG_BONUS)
	else
		data:ClearFlag(FLAG_BONUS)
	end
	data:Save()
	quest:StartSequence(SEQ_006)
end

-- World kills by the player's party (BattleNpc kill hook).
function onKillBNpc(player, quest, classId)
	if not isOurs(quest) then
		return
	end
	local sequence = quest:GetSequence()
	local data = quest:GetData()
	if sequence == SEQ_001 then
		for i, id in ipairs(KILLS) do
			if id == classId and not data:GetFlag(i - 1) then
				data:SetFlag(i - 1)
				data:Save()
				if allCrystals(data) then
					quest:StartSequence(SEQ_002)
				end
				return
			end
		end
	elseif sequence == SEQ_003 and classId == VOIDTONGUE then
		data:SetFlag(FLAG_FLAMBEAU)
		data:Save()
		quest:StartSequence(SEQ_004)
	end
end

function allCrystals(data)
	for i = 1, #KILLS do
		if not data:GetFlag(i - 1) then
			return false
		end
	end
	return true
end

function questFlagSet(quest, flag)
	local data = quest:GetData()
	return data ~= nil and data:GetFlag(flag)
end

-- int2..int6 (crystals held) and str7 ("a" fire crystal, "b" Harmonizing Crystal, "c" + the Flambeau)
function getJournalInformation(player, quest)
	if not isOurs(quest) then
		return
	end
	local sequence = quest:GetSequence()
	local data = quest:GetData()
	local f = {}
	for i = 1, 5 do
		f[i] = ((sequence == SEQ_001 or sequence == SEQ_002) and data:GetFlag(i - 1)) and 1 or 0
	end
	local s7 = ""
	if (sequence == SEQ_001 or sequence == SEQ_002) and data:GetFlag(5) then
		s7 = "a"
	elseif sequence == SEQ_003 then
		s7 = "b"
	elseif sequence == SEQ_004 or sequence == SEQ_005 then
		s7 = "c"
	end
	return f[1], f[2], f[3], f[4], f[5], s7
end

local MRKR_LOUISOIX		= 11181001
local MRKR_BEASTS			= { 11181002, 11181003, 11181004, 11181005, 11181006, 11181007 }
local MRKR_VOIDTONGUE		= 11181009
local MRKR_OFFICER		= { [GC_MAELSTROM] = 11181010, [GC_TWINADDER] = 11181011, [GC_FLAMES] = 11181012 }

function getJournalMapMarkerList(player, quest)
	if not isOurs(quest) then
		return
	end
	local sequence = quest:GetSequence()
	if sequence == SEQ_001 then
		return unpack(MRKR_BEASTS)
	elseif sequence == SEQ_003 then
		return MRKR_VOIDTONGUE
	elseif sequence == SEQ_007 then
		return MRKR_OFFICER[gcCompanyOfQuestId(quest:GetQuestId())]
	end
	return MRKR_LOUISOIX
end
