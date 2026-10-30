require("Global")
require("Quest")
require("QuestFlow")

--[[
Bloody Baptism (Exc200, 110100). Marauder level 20, offered by Waekbyrt in Limsa Lominsa.
Seq 0 Nunuba's briefing; Seq 5 the Swiftperch Tower duty (QuestDirectorExc20001), which a loss
keeps at 5; Seq 20 her report; Seq 30 her reward.
Spawns, class fills and pools: Data/sql/seed/seed_quest_exc200_01.sql.
--]]

local startSwiftperchDuty, leaveSwiftperch

local SEQ_000 = 0
SEQ_005 = 5
local SEQ_020 = 20
local SEQ_030 = 30

local WAEKBYRT = 1000003
local NUNUBA   = 1000004

local MRKR_NUNUBA    = 11010001
local MRKR_OBJECTIVE = 11010002
local MRKR_NUNUBA2   = 11010003

local NPCLS_ASTALICIA = 12

local DUTY_ENTRY  = { -797.860, 45.000, -673.740, 0.000 }
local NUNUBA_POST = { -753.440, 8.190, 398.010, 0.120 }

local PHASES = {
	[SEQ_000] = { enpcs = { { NUNUBA, QFLAG_TALK } }, markers = { MRKR_NUNUBA } },
	-- A lost duty is reopened by the same talk, so Nunuba stays reachable without a bubble.
	[SEQ_005] = { enpcs = { NUNUBA }, markers = { MRKR_OBJECTIVE } },
	[SEQ_020] = { enpcs = { { NUNUBA, QFLAG_TALK } }, markers = { MRKR_NUNUBA2 } },
	[SEQ_030] = { enpcs = { { NUNUBA, QFLAG_REWARD } }, markers = { MRKR_NUNUBA2 } },
}

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(WAEKBYRT, QFLAG_TALK)
		return
	end
	applyPhase(player, quest, PHASES, sequence)
end

local function nunubaBriefing(player, quest)
	if delegateEvent(player, quest, "processEvent015") == 1 then
		-- The trailing false keeps the scene's after-warp fade-in.
		delegateEvent(player, quest, "processEvent020", false)
		startSwiftperchDuty(player, quest)
		return true
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		[WAEKBYRT] = function(player, quest)
			local accepted = delegateEvent(player, quest, "processEventWaekbyrtStart")
			player:EndEvent()
			if accepted == 1 then
				player:AcceptQuest(quest)
			end
			return true
		end,
	},
	[SEQ_000] = { [NUNUBA] = nunubaBriefing },
	[SEQ_005] = { [NUNUBA] = nunubaBriefing },
	[SEQ_020] = {
		[NUNUBA] = function(player, quest)
			delegateEvent(player, quest, "processEvent030")
			delegateEvent(player, quest, "processEvent040")
			quest:StartSequence(SEQ_030)
		end,
	},
	[SEQ_030] = {
		[NUNUBA] = function(player, quest)
			turnInQuest(player, quest, "processEvent050")
			return true
		end,
	},
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

-- The guild linkpearl comes with the briefing; acceptance itself moves nothing.
function startSwiftperchDuty(player, quest)
	if quest:GetSequence() == SEQ_000 then
		quest:StartSequence(SEQ_005)
		player:AddNpcLs(NPCLS_ASTALICIA)
	end
	local p = DUTY_ENTRY
	startQuestContent(player, {
		zone = 129, content = "SimpleContentExc20001", director = "Quest/QuestDirectorExc20001",
		x = p[1], y = p[2], z = p[3], rot = p[4],
	})
end

-- Called by QuestDirectorExc20001 once the Lord of Swiftperch is down.
function finishSwiftperchDuty(player, quest, duty, area)
	quest:StartSequence(SEQ_020)
	leaveSwiftperch(player, duty, area)
end

function failSwiftperchDuty(player, quest, duty, area)
	leaveSwiftperch(player, duty, area)
end

function leaveSwiftperch(player, duty, area)
	local p = NUNUBA_POST
	leaveQuestContent(player, duty, area, { zone = 230, x = p[1], y = p[2], z = p[3], rot = p[4] })
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
