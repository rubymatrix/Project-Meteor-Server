require("Global")
require("Quest")
require("QuestFlow")

--[[
The Big Payback (Thm200, quest 110240). Thaumaturge level 20, offered by Yayake in Ul'dah.

Seq 0:  I'llofii's briefing; the Arrzaneth Ossuary linkpearl comes with it.
Seq 5:  The vengeance duty at the Western Thanalan trigger (QuestDirectorThm20001, content
        SimpleContentThm20001, zone 172). A lost duty keeps 5 and the trigger asks again. The death-marked
        billygoat's fall gives the twisted aldgoat horn.
Seq 20: I'llofii's report and reward.

The horn is this quest's proof and leaves with it. Spawns: Data/sql/seed/seed_quest_thm200_01.sql.
--]]

SEQ_000 = 0
SEQ_005 = 5
SEQ_020 = 20

YAYAKE            = 1000846
ILLOFII           = 1000847
OBJECTIVE_TRIGGER = 1090008

MRKR_ILLOFII   = 11024001
MRKR_OBJECTIVE = 11024002
MRKR_ILLOFII2  = 11024003

ITEM_TWISTED_ALDGOAT_HORN = 11000015
NPCLS_ARRZANETH_OSSUARY   = 15

VENGEANCE_TRIGGER_NAME = "thm200_vengeance_trigger"

-- The duty lands on the trigger's own spot; the way out stands past its push circle.
DUTY_ENTRY    = { -1229.530, 57.000, -310.290, 0.000 }
PUBLIC_RETURN = { -1229.530, 57.000, -298.290, 3.142 }

-- The client reward sheet has no row for this quest.
COMPLETION_REWARDS = { exp = 1760, gil = 20000, items = { { 5020210, 1 } } }


PHASES = {
	[SEQ_000] = { enpcs = { { ILLOFII, QFLAG_TALK } }, markers = { MRKR_ILLOFII } },
	[SEQ_005] = {
		enpcs = { { OBJECTIVE_TRIGGER, QFLAG_PUSH, talk = false, push = true, spawn = true } },
		markers = { MRKR_OBJECTIVE },
	},
	[SEQ_020] = { enpcs = { { ILLOFII, QFLAG_REWARD } }, markers = { MRKR_ILLOFII2 } },
}

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
	takeKeyItem(player, ITEM_TWISTED_ALDGOAT_HORN)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(YAYAKE, QFLAG_TALK)
		return
	end
	applyPhase(player, quest, PHASES, sequence)
end

local talk = {
	[SEQ_ACCEPT] = {
		[YAYAKE] = function(player, quest, npc)
			local accepted = delegateEvent(player, quest, "processEventYayakeStart")
			player:EndEvent()
			if accepted == 1 then
				player:AcceptQuest(quest)
			end
			return true
		end,
	},
	[SEQ_000] = {
		[ILLOFII] = function(player, quest, npc)
			delegateEvent(player, quest, "processEvent020")
			quest:StartSequence(SEQ_005)
			player:AddNpcLs(NPCLS_ARRZANETH_OSSUARY)
		end,
	},
	[SEQ_020] = {
		[ILLOFII] = function(player, quest, npc)
			turnInQuest(player, quest, "processEvent030", COMPLETION_REWARDS)
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

	if sequence == SEQ_005 and classId == OBJECTIVE_TRIGGER and npcName(npc) == VENGEANCE_TRIGGER_NAME then
		if delegateEvent(player, quest, "contentsJoinAskInBasaClass") == 1 then
			local p = DUTY_ENTRY
			startQuestContent(player, {
				zone = 172, content = "SimpleContentThm20001", director = "Quest/QuestDirectorThm20001",
				x = p[1], y = p[2], z = p[3], rot = p[4],
			})
			return
		end
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

-- Called by QuestDirectorThm20001 at the death-marked billygoat's fall, and again at the win
-- in case the first grant was missed.
function grantAldgoatHorn(player)
	giveKeyItem(player, ITEM_TWISTED_ALDGOAT_HORN)
end

-- Called by QuestDirectorThm20001 once the enraged nannygoat is down.
function finishVengeance(player, quest, duty, area)
	grantAldgoatHorn(player)
	quest:StartSequence(SEQ_020)
	leaveVengeance(player, duty, area)
end

function failVengeance(player, quest, duty, area)
	leaveVengeance(player, duty, area)
end

function leaveVengeance(player, duty, area)
	local p = PUBLIC_RETURN
	leaveQuestContent(player, duty, area, { zone = 172, x = p[1], y = p[2], z = p[3], rot = p[4] })
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
