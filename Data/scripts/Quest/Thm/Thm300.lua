require("Global")
require("Quest")
require("QuestFlow")

--[[
Revelry in Rivalry (Thm300, quest 110241). Thaumaturge level 30, after Thm200. Offered by Yayake
in Ul'dah.

Seq 0:  The overweening thaumaturge (the Ossuary rival) in Ul'dah (209).
Seq 5:  Baderon in Limsa Lominsa (133).
Seq 10: The Ignis Fatuus at the bizarre blacksmith's in Lower La Noscea (QuestDirectorThm30001, content
        SimpleContentThm30001, zone 128), entered by the smith trigger. A lost duty keeps 10. The wisp's fall
        gives the Writ of Access and records whether the smith lived (flag 0).
Seq 20: Bodenolf's report (230), by the smith's fate (processEvent027 lost, 028 survived).
Seq 21: Bodenolf's Echo (advances on a yes).
Seq 22: Yayake's talk.
Seq 23: The rival's farewell.
Seq 30: Yayake's reward.

The writ is this quest's proof and leaves with it. Spawns: Data/sql/seed/seed_quest_thm300_01.sql.
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

-- Plain talk steps: [sequence] = { classId, event, next sequence }.
local SCENES = {
	[SEQ_000] = { OVERWEENING_THAUMATURGE, "processEvent020", SEQ_005 },
	[SEQ_005] = { BADERON, "processEvent025", SEQ_010 },
	[SEQ_022] = { YAYAKE, "processEvent035", SEQ_023 },
	[SEQ_023] = { OVERWEENING_THAUMATURGE, "processEvent040", SEQ_030 },
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

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()
	local scene = SCENES[sequence]

	if sequence == SEQ_ACCEPT then
		if classId == YAYAKE then
			local accepted = delegateEvent(player, quest, "processEventYayakeStart")
			player:EndEvent()
			if accepted == 1 then
				player:AcceptQuest(quest)
			end
			return
		end
	elseif scene ~= nil and classId == scene[1] then
		delegateEvent(player, quest, scene[2])
		quest:StartSequence(scene[3])
	elseif sequence == SEQ_020 and classId == BODENOLF then
		delegateEvent(player, quest, getQuestFlag(quest, FLAG_SMITH_SURVIVED) and "processEvent028" or "processEvent027")
		quest:StartSequence(SEQ_021)
	elseif sequence == SEQ_021 and classId == BODENOLF then
		-- An Echo advances only on a yes.
		if delegateEvent(player, quest, "processEvent030") == 1 then
			quest:StartSequence(SEQ_022)
		end
	elseif sequence == SEQ_030 and classId == YAYAKE then
		turnInQuest(player, quest, "processEvent050", COMPLETION_REWARDS)
		return
	end

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
