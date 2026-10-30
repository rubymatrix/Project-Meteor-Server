require("Global")
require("Quest")
require("QuestFlow")

--[[
Law and the Order (Thm306, quest 110242). Thaumaturge level 36, after Thm300. Offered by Yayake
in Ul'dah.

Seq 0:  I'llofii's briefing.
Seq 5:  The overweening thaumaturge at the Western Thanalan wreck site (172).
Seq 10: The rival's challenge; a yes opens the duel (QuestDirectorThm30601, content SimpleContentThm30601,
        zone 172). A lost duel keeps 10 and the rival asks again.
Seq 20: I'llofii's reward.

Spawns: Data/sql/seed/seed_quest_thm306_01.sql.
--]]

SEQ_000 = 0
SEQ_005 = 5
SEQ_010 = 10
SEQ_020 = 20

YAYAKE                  = 1000846
ILLOFII                 = 1000847
OVERWEENING_THAUMATURGE = 1000607

MRKR_ILLOFII                  = 11024201
MRKR_OVERWEENING_THAUMATURGE  = 11024202
MRKR_OVERWEENING_THAUMATURGE2 = 11024203
MRKR_ILLOFII2                 = 11024205

-- The duel lands at the rival's spot and returns there.
WRECK_SITE = { -1849.756, 24.922, -284.174, 0.000 }

-- The client reward sheet has no row for this quest.
COMPLETION_REWARDS = { exp = 4720, gil = 36000 }


PHASES = {
	[SEQ_000] = { enpcs = { { ILLOFII, QFLAG_TALK } }, markers = { MRKR_ILLOFII } },
	[SEQ_005] = {
		enpcs = { { OVERWEENING_THAUMATURGE, QFLAG_TALK, spawn = true } },
		markers = { MRKR_OVERWEENING_THAUMATURGE },
	},
	-- A lost duel keeps this step, so the rival is talked to again.
	[SEQ_010] = {
		enpcs = { { OVERWEENING_THAUMATURGE, QFLAG_TALK, spawn = true } },
		markers = { MRKR_OVERWEENING_THAUMATURGE2 },
	},
	[SEQ_020] = { enpcs = { { ILLOFII, QFLAG_REWARD } }, markers = { MRKR_ILLOFII2 } },
}

function onStart(player, quest)
	quest:StartSequence(SEQ_000)
end

function onFinish(player, quest)
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
		end,
	},
	[SEQ_005] = {
		[OVERWEENING_THAUMATURGE] = function(player, quest, npc)
			delegateEvent(player, quest, "processEvent030")
			quest:StartSequence(SEQ_010)
		end,
	},
	[SEQ_010] = {
		[OVERWEENING_THAUMATURGE] = function(player, quest, npc)
			if delegateEvent(player, quest, "processEvent035") == 1 then
				-- The trailing false keeps the scene's after-warp fade-in.
				delegateEvent(player, quest, "processEvent040", false)
				local p = WRECK_SITE
				startQuestContent(player, {
					zone = 172, content = "SimpleContentThm30601", director = "Quest/QuestDirectorThm30601",
					x = p[1], y = p[2], z = p[3], rot = p[4],
				})
				return true
			end
		end,
	},
	[SEQ_020] = {
		[ILLOFII] = function(player, quest, npc)
			turnInQuest(player, quest, "processEvent060", COMPLETION_REWARDS)
			return true
		end,
	},
}

function onTalk(player, quest, npc)
	if runQuestHandler(talk, player, quest, npc) then return end

	player:EndEvent()
	quest:UpdateENPCs()
end

-- Called by QuestDirectorThm30601 once the rival yields. The duel's aftermath fades in after the
-- return warp.
function finishWreckDuel(player, quest, duty, area)
	delegateEvent(player, quest, "processEvent050")
	quest:StartSequence(SEQ_020)
	leaveWreckSite(player, duty, area)
end

function failWreckDuel(player, quest, duty, area)
	leaveWreckSite(player, duty, area)
end

function leaveWreckSite(player, duty, area)
	local p = WRECK_SITE
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
