require("Global")
require("Quest")
require("QuestFlow")

--[[
Revelry in Rivalry (Thm300, 110241). Prereq: Thm200; Thaumaturge level 30.
A lost Ignis Fatuus duty keeps Seq 10; the wisp's fall records whether the smith lived. The Writ
of Access is the quest's proof and leaves with it. Walkthrough: Data/Docs/Scripts/Quest/Thm/Thm300.md.
--]]

local leaveSmithy

local SEQ_000 = 0
local SEQ_005 = 5
SEQ_010 = 10
local SEQ_020 = 20
local SEQ_021 = 21
local SEQ_022 = 22
local SEQ_023 = 23
local SEQ_030 = 30

local YAYAKE                  = 1000846
local OVERWEENING_THAUMATURGE = 1000607
local BADERON                 = 1000137
local BIZARRE_BLACKSMITH      = 1001008
local BODENOLF                = 1000144

local MRKR_OVERWEENING_THAUMATURGE  = 11024101
local MRKR_BADERON                  = 11024102
local MRKR_OBJECTIVE                = 11024103
local MRKR_BODENOLF                 = 11024104
local MRKR_BODENOLF2                = 11024105
local MRKR_BODENOLF3                = 11024106
local MRKR_YAYAKE                   = 11024107
local MRKR_OVERWEENING_THAUMATURGE2 = 11024108
local MRKR_YAYAKE2                  = 11024109

local FLAG_SMITH_SURVIVED = 0

local ITEM_WRIT_OF_ACCESS = 11000030

-- The duty lands on the smith trigger's own spot; the way out stands past its push circle.
local DUTY_ENTRY    = { -494.716, 45.882, -385.102, 0.000 }
local PUBLIC_RETURN = { -494.716, 45.882, -373.102, 3.142 }

local function smithSurvived(player, quest, data) return data:GetFlag(FLAG_SMITH_SURVIVED) end
local function smithLost(player, quest, data)     return not data:GetFlag(FLAG_SMITH_SURVIVED) end

-- The client reward sheet has no row for this quest.
local COMPLETION_REWARDS = { exp = 3420, gil = 30000 }


local PHASES = {
	[SEQ_000] = {
		enpcs = { { OVERWEENING_THAUMATURGE, QFLAG_TALK, spawn = true } },
		markers = { MRKR_OVERWEENING_THAUMATURGE },
	},
	[SEQ_005] = { enpcs = { { BADERON, QFLAG_TALK } }, markers = { MRKR_BADERON } },
	[SEQ_010] = {
		enpcs = { { BIZARRE_BLACKSMITH, QFLAG_PUSH, talk = false, push = true, spawn = true } },
		markers = { MRKR_OBJECTIVE },
	},
	[SEQ_020] = {
		enpcs = { { BODENOLF, QFLAG_TALK } },
		markers = { { MRKR_BODENOLF, when = smithLost }, { MRKR_BODENOLF2, when = smithSurvived } },
	},
	[SEQ_021] = { enpcs = { { BODENOLF, QFLAG_TALK } }, markers = { MRKR_BODENOLF3 } },
	[SEQ_022] = { enpcs = { { YAYAKE, QFLAG_TALK } }, markers = { MRKR_YAYAKE } },
	[SEQ_023] = {
		enpcs = { { OVERWEENING_THAUMATURGE, QFLAG_TALK, spawn = true } },
		markers = { MRKR_OVERWEENING_THAUMATURGE2 },
	},
	[SEQ_030] = { enpcs = { { YAYAKE, QFLAG_REWARD } }, markers = { MRKR_YAYAKE2 } },
}

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
	takeKeyItem(player, ITEM_WRIT_OF_ACCESS)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(YAYAKE, QFLAG_TALK)
		return
	end
	applyPhase(player, quest, PHASES, sequence)
end

local function scene(eventName, nextSequence)
	return function(player, quest)
		delegateEvent(player, quest, eventName)
		quest:StartSequence(nextSequence)
	end
end

local talk = {
	[SEQ_ACCEPT] = {
		[YAYAKE] = function(player, quest)
			local accepted = delegateEvent(player, quest, "processEventYayakeStart")
			player:EndEvent()
			if accepted == 1 then
				player:AcceptQuest(quest)
			end
			return true
		end,
	},
	[SEQ_000] = { [OVERWEENING_THAUMATURGE] = scene("processEvent020", SEQ_005) },
	[SEQ_005] = { [BADERON] = scene("processEvent025", SEQ_010) },
	[SEQ_020] = {
		[BODENOLF] = function(player, quest)
			delegateEvent(player, quest, getQuestFlag(quest, FLAG_SMITH_SURVIVED) and "processEvent028" or "processEvent027")
			quest:StartSequence(SEQ_021)
		end,
	},
	[SEQ_021] = {
		-- An Echo advances only on a yes.
		[BODENOLF] = function(player, quest)
			if delegateEvent(player, quest, "processEvent030") == 1 then
				quest:StartSequence(SEQ_022)
			end
		end,
	},
	[SEQ_022] = { [YAYAKE] = scene("processEvent035", SEQ_023) },
	[SEQ_023] = { [OVERWEENING_THAUMATURGE] = scene("processEvent040", SEQ_030) },
	[SEQ_030] = {
		[YAYAKE] = function(player, quest)
			turnInQuest(player, quest, "processEvent050", COMPLETION_REWARDS)
			return true
		end,
	},
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc) then return end
	player:EndEvent()
	quest:UpdateENPCs()
end

function onPush(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()

	if sequence == SEQ_010 and classId == BIZARRE_BLACKSMITH and currentZoneId(player) == 128 and not inPrivateArea(player) then
		if delegateEvent(player, quest, "contentsJoinAskInBasaClass") == 1 then
			-- A retry starts from a clean verdict on the smith.
			clearQuestFlag(quest, FLAG_SMITH_SURVIVED)
			local p = DUTY_ENTRY
			startQuestContent(player, {
				zone = 128, content = "SimpleContentThm30001", director = "Quest/QuestDirectorThm30001",
				x = p[1], y = p[2], z = p[3], rot = p[4],
			})
			return
		end
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

-- Called by QuestDirectorThm30001 once the wisp is down: the smith's fate and the writ.
function finishIgnisFatuus(player, quest, duty, area, smithLived)
	if smithLived then
		setQuestFlagOn(quest, FLAG_SMITH_SURVIVED)
	end
	giveKeyItem(player, ITEM_WRIT_OF_ACCESS)
	quest:StartSequence(SEQ_020)
	leaveSmithy(player, duty, area)
end

function failIgnisFatuus(player, quest, duty, area)
	leaveSmithy(player, duty, area)
end

function leaveSmithy(player, duty, area)
	local p = PUBLIC_RETURN
	leaveQuestContent(player, duty, area, { zone = 128, x = p[1], y = p[2], z = p[3], rot = p[4] })
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
