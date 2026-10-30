require("Global")
require("Quest")
require("QuestFlow")

--[[
Filling the Quiver (Arc200, 110160). Archer class quest, level 20; no client prereq.
Every push on the fence ends in the join prompt, so a declined or lost battle is entered again from
there. Spawns, pools and class fills: Data/sql/seed/seed_quest_arc200_01.sql.
--]]

local startInvaderFight

local SEQ_000 = 0
local SEQ_010 = 10
SEQ_020 = 20
local SEQ_030 = 30

local NONOLATO      = 1000463
local KEELTY        = 1000587
local FENCE_TRIGGER = 1090008 -- spawn arc200_fence_trigger (North Shroud)

local MRKR_KEELTY     = 11016001
local MRKR_FENCE      = 11016002
local MRKR_FALLGOURD  = 11016003
local MRKR_NONOLATO   = 11016004

local NPCLS_QUIVERS_HOLD = 13

-- Where the battle lands and returns (the Fallgourd destination of marker 11016003).
local FALLGOURD_ENTRY = { -1356.240, 31.527, -2104.540, 0.0 }

-- Completion pay: the client reward sheet has no row for this quest (questflow.lua turnInQuest).
local COMPLETION_REWARDS = { exp = 1760, gil = 20000, items = { { 4070011, 1 } } } -- Elm Velocity Bow


local FENCE = { FENCE_TRIGGER, QFLAG_PUSH, talk = false, push = true, spawn = true }

local PHASES = {
	[SEQ_000] = {
		enpcs = { { KEELTY, QFLAG_TALK } },
		markers = { MRKR_KEELTY },
	},
	[SEQ_010] = {
		enpcs = { FENCE, KEELTY },
		markers = { MRKR_FENCE },
	},
	-- The battle is entered again from the fence, so its marker stays up.
	[SEQ_020] = {
		enpcs = { FENCE },
		markers = { MRKR_FALLGOURD, MRKR_FENCE },
	},
	[SEQ_030] = {
		enpcs = { { NONOLATO, QFLAG_REWARD } },
		markers = { MRKR_NONOLATO },
	},
}

local CHATTER = {
	[SEQ_010] = { [KEELTY] = "processEvent010_2" },
}

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(NONOLATO, QFLAG_TALK)
		return
	end
	applyPhase(player, quest, PHASES, sequence)
end

local talk = {
	[SEQ_ACCEPT] = {
		[NONOLATO] = function(player, quest)
			local accepted = delegateEvent(player, quest, "processEventNonolatoStart")
			player:EndEvent()
			if accepted == 1 then
				player:AcceptQuest(quest)
			end
			return true
		end,
		other = function() end,
	},
	[SEQ_000] = {
		[KEELTY] = function(player, quest)
			delegateEvent(player, quest, "processEvent010")
			player:AddNpcLs(NPCLS_QUIVERS_HOLD)
			quest:StartSequence(SEQ_010)
		end,
	},
	[SEQ_030] = {
		-- Both answers to the closing question pay, so the result is not read.
		[NONOLATO] = function(player, quest)
			turnInQuest(player, quest, "processEvent050", COMPLETION_REWARDS)
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

-- The rendezvous plays once; every push then ends in the join prompt, and the after-warp lead-in
-- plays only on a yes.
local function fencePush(player, quest)
	local sequence = quest:GetSequence()
	if sequence == SEQ_010 then
		delegateEvent(player, quest, "processEvent020")
	end
	local answer = delegateEvent(player, quest, "contentsJoinAskInBasaClass")
	if answer == 1 then
		-- false keeps the after-warp fade-in.
		delegateEvent(player, quest, "processEvent030", false)
	end
	if sequence == SEQ_010 then
		quest:StartSequence(SEQ_020)
	end
	if answer == 1 then
		startInvaderFight(player, quest)
		return true
	end
end

local push = {
	[SEQ_010] = { other = fencePush },
	[SEQ_020] = { other = fencePush },
}

function onPush(player, quest, npc, eventName)
	if npcName(npc) == "arc200_fence_trigger" and runQuestHandler(push, player, quest, npc) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

function startInvaderFight(player, quest)
	local a = FALLGOURD_ENTRY
	startQuestContent(player, {
		zone = 152, content = "SimpleContentArc20001", director = "Quest/QuestDirectorArc20001",
		x = a[1], y = a[2], z = a[3], rot = a[4],
	})
end

-- QuestDirectorArc20001, the last invader down, with its noticeEvent open: the aftermath fades in after
-- the return warp.
function finishInvaderFight(player, quest, duty, area)
	delegateEvent(player, quest, "processEvent040")
	quest:StartSequence(SEQ_030)
	local a = FALLGOURD_ENTRY
	leaveQuestContent(player, duty, area, { zone = 152, x = a[1], y = a[2], z = a[3], rot = a[4] })
end

-- A lost battle keeps 20: back to Fallgourd, where the fence asks again.
function failInvaderFight(player, quest, duty, area)
	player:SetHP(player:GetMaxHP())
	local a = FALLGOURD_ENTRY
	leaveQuestContent(player, duty, area, { zone = 152, x = a[1], y = a[2], z = a[3], rot = a[4] })
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
