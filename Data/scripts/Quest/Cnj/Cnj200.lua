require("Global")
require("Quest")
require("QuestFlow")

--[[
Dendrological Duties (Cnj200, 110260). Prereq: Conjurer level 20.
Telent's briefing and every later talk end in the join prompt, so a declined or lost culling is
retried from him. Walkthrough: Data/Docs/Scripts/Quest/Cnj/Cnj200.md.
--]]

local startCulling

local SEQ_000 = 0
SEQ_010 = 10
local SEQ_020 = 20
local SEQ_030 = 30

local SOILEINE = 1000234
local TELENT   = 1000504

local MRKR_TELENT    = 11026001
local MRKR_CULLING   = 11026002
local MRKR_TELENT2   = 11026003
local MRKR_SOILEINE  = 11026004

local NPCLS_STILLGLADE_FANE = 16

-- Where the culling lands (the Central Shroud destination of marker 11026002).
local CULLING_ENTRY = { 726.000, 31.795, -850.000, 0.0 }
-- Telent's own spawn at Stillglade Fane, where a won culling returns.
local TELENT_POST   = { -354.234, 6.244, -1697.720, 0.760 }

-- Completion pay: the client reward sheet has no row for this quest (questflow.lua turnInQuest).
local COMPLETION_REWARDS = { exp = 1760, gil = 20000, items = { { 5030306, 1 } } } -- Yew Radical


local PHASES = {
	[SEQ_000] = {
		enpcs = { { TELENT, QFLAG_TALK }, SOILEINE },
		markers = { MRKR_TELENT },
	},
	[SEQ_010] = {
		enpcs = { { TELENT, QFLAG_TALK }, SOILEINE },
		markers = { MRKR_CULLING },
	},
	[SEQ_020] = {
		enpcs = { { TELENT, QFLAG_TALK } },
		markers = { MRKR_TELENT2 },
	},
	[SEQ_030] = {
		enpcs = { { SOILEINE, QFLAG_REWARD }, TELENT },
		markers = { MRKR_SOILEINE },
	},
}

local CHATTER = {
	[SEQ_000] = { [SOILEINE] = "processEvent010_2" },
	[SEQ_010] = { [SOILEINE] = "processEvent010_2" },
	[SEQ_030] = { [TELENT] = "processEvent030_2" },
}

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(SOILEINE, QFLAG_TALK)
		return
	end
	applyPhase(player, quest, PHASES, sequence)
end

local function telentBriefing(player, quest)
	local sequence = quest:GetSequence()
	if sequence == SEQ_000 then
		delegateEvent(player, quest, "processEvent015")
	end
	local answer = delegateEvent(player, quest, "contentsJoinAskInBasaClass")
	if sequence == SEQ_000 then
		player:AddNpcLs(NPCLS_STILLGLADE_FANE)
		quest:StartSequence(SEQ_010)
	end
	if answer == 1 then
		startCulling(player, quest)
		return true
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		[SOILEINE] = function(player, quest)
			if not inPrivateArea(player) then
				local accepted = delegateEvent(player, quest, "processEventSoileineStart")
				player:EndEvent()
				if accepted == 1 then
					player:AcceptQuest(quest)
				end
				return true
			end
		end,
		other = function() end,
	},
	[SEQ_000] = { [TELENT] = telentBriefing },
	[SEQ_010] = { [TELENT] = telentBriefing },
	[SEQ_020] = {
		[TELENT] = function(player, quest)
			delegateEvent(player, quest, "processEvent030")
			quest:StartSequence(SEQ_030)
		end,
	},
	[SEQ_030] = {
		[SOILEINE] = function(player, quest)
			turnInQuest(player, quest, "processEvent040", COMPLETION_REWARDS)
			return true
		end,
	},
	other = function(player, quest, npc)
		delegateChatter(player, quest, CHATTER, quest:GetSequence(), npc:GetActorClassId())
	end,
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

function startCulling(player, quest)
	local a = CULLING_ENTRY
	startQuestContent(player, {
		zone = 150, content = "SimpleContentCnj20001", director = "Quest/QuestDirectorCnj20001",
		x = a[1], y = a[2], z = a[3], rot = a[4],
	})
end

-- QuestDirectorCnj20001, the alpha down, with its noticeEvent open: the scene fades in after the warp
-- back to Telent, and the report follows it.
function finishCulling(player, quest, duty, area)
	delegateEvent(player, quest, "processEvent020")
	quest:StartSequence(SEQ_020)
	local p = TELENT_POST
	leaveQuestContent(player, duty, area, { zone = 206, x = p[1], y = p[2], z = p[3], rot = p[4] })
end

-- A lost culling keeps 10: back to the culling ground; Telent asks again.
function failCulling(player, quest, duty, area)
	player:SetHP(player:GetMaxHP())
	local a = CULLING_ENTRY
	leaveQuestContent(player, duty, area, { zone = 150, x = a[1], y = a[2], z = a[3], rot = a[4] })
end

function onPush(player, quest, npc, eventName)
	player:EndEvent()
end

function onNotice(player, quest, target)
	player:EndEvent()
	quest:UpdateENPCs()
end

function getJournalInformation(player, quest)
	return
end

function getJournalMapMarkerList(player, quest)
	return unpack(phaseMarkers(player, quest, PHASES))
end
