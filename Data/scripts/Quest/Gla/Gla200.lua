require("Global")
require("Quest")
require("QuestFlow")

--[[
All Bark and No Bite (Gla200, quest 110080). Gladiator level 20, offered by Lulutsu
(processEventLulutsuStart, accepted on 1).

Seq 0:   Lulutsu: the join ask, processEvent010, then the Coliseum bout with the Ala Mhigan challenger
         (content SimpleContentGla20001, QuestDirectorGla20001). A lost or abandoned bout keeps 0.
Seq 20:  The bout is won (processEvent020, the Coliseum linkpearl); Lulutsu's reward.

Completion: processEvent030, then COMPLETION_REWARDS.
Spawns and class fills: Data/sql/seed/seed_quest_gla200_01.sql.
--]]

SEQ_000 = 0
SEQ_020 = 20

LULUTSU = 1000863

MRKR_LULUTSU = 11008002

NPCLS_COLISEUM = 11

-- The client reward sheet has no class-quest rows.
COMPLETION_REWARDS = { exp = 1760, gil = 20000, items = { { 4030203, 1 } } }

BOUT_ENTRY   = { -187.225, 190.150, 219.730, 0.0 }
LULUTSU_POST = { 209, -193.460, 195.050, 183.650, 0.610 }

PHASES = {
	[SEQ_000] = { enpcs = { { LULUTSU, QFLAG_TALK } }, markers = { MRKR_LULUTSU } },
	[SEQ_020] = { enpcs = { { LULUTSU, QFLAG_REWARD } }, markers = { MRKR_LULUTSU } },
}

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(LULUTSU, QFLAG_TALK)
		return
	end
	applyPhase(player, quest, PHASES, sequence)
end

local talk = {
	[SEQ_ACCEPT] = {
		[LULUTSU] = function(player, quest, npc)
			local accepted = delegateEvent(player, quest, "processEventLulutsuStart")
			player:EndEvent()
			if accepted == 1 then
				player:AcceptQuest(quest)
			end
			return true
		end,
	},
	[SEQ_000] = {
		[LULUTSU] = function(player, quest, npc)
			if delegateEvent(player, quest, "contentsJoinAskInBasaClass") == 1 then
				delegateEvent(player, quest, "processEvent010")
				startQuestContent(player, {
					zone = 209, content = "SimpleContentGla20001", director = "Quest/QuestDirectorGla20001",
					x = BOUT_ENTRY[1], y = BOUT_ENTRY[2], z = BOUT_ENTRY[3], rot = BOUT_ENTRY[4],
				})
				return true
			end
		end,
	},
	[SEQ_020] = {
		[LULUTSU] = function(player, quest, npc)
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

-- Called by QuestDirectorGla20001 on the win. The guild linkpearl comes with the bout,
-- since accepting the quest is not a step.
function finishGla200Bout(player, quest, duty, area)
	delegateEvent(player, quest, "processEvent020")
	quest:StartSequence(SEQ_020)
	player:AddNpcLs(NPCLS_COLISEUM)
	local p = LULUTSU_POST
	leaveQuestContent(player, duty, area, { zone = p[1], x = p[2], y = p[3], z = p[4], rot = p[5] })
end

function failGla200Bout(player, quest, duty, area)
	local p = LULUTSU_POST
	leaveQuestContent(player, duty, area, { zone = p[1], x = p[2], y = p[3], z = p[4], rot = p[5] })
end

function getJournalMapMarkerList(player, quest)
	return unpack(phaseMarkers(player, quest, PHASES))
end
