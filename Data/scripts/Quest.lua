--[[

Special constants used by quest scripts, the lookup their event tables share, and the reward window.

]]

-- QUEST FLAGS
QFLAG_OFF		= 0
QFLAG_OFF_HIDE	= 1
QFLAG_TALK		= 2
QFLAG_PUSH		= 3
QFLAG_REWARD	= 4
QFLAG_MAPONLY	= 5

-- SPECIAL SEQUENCE CONSTANTS
SEQ_ACCEPT		= 65535
SEQ_COMPLETE	= 65534

-- NPC LS
NPCLS_GONE		= 0
NPCLS_INACTIVE	= 1
NPCLS_ACTIVE	= 2
NPCLS_ALERT		= 3

-- Handlers are keyed by sequence, then by NPC class id. handlers.always answers an NPC the same
-- in every sequence, and an "other" entry, per sequence or for the whole table, takes the rest.
-- A handler returns true when it has already ended the event itself.
function runQuestHandler(handlers, player, quest, npc, ...)
	local classId = npc:GetActorClassId()
	local byNpc = handlers[quest:GetSequence()] or {}
	local handler = byNpc[classId] or (handlers.always and handlers.always[classId]) or byNpc.other or handlers.other
	return handler ~= nil and handler(player, quest, npc, ...)
end

-- Shows the client's reward window for the quest's completion rewards, which CompleteQuest pays.
-- Returns false after "Your inventory is full." when they don't fit; the script then leaves the
-- quest open so the player can make room and turn it in again.
function showQuestRewards(player, quest, tier)
	tier = tier or 1
	local questId = quest:GetQuestId()
	if not player:HasRoomForQuestRewards(questId, tier) then
		player:SendGameMessage(GetWorldMaster(), 60022, MESSAGE_TYPE_SYSTEM_ERROR)
		return false
	end

	local list = player:GetQuestRewardSlots(questId)
	local slots = {}
	for i = 0, list.Length - 1 do
		slots[#slots + 1] = list[i]
	end
	if #slots > 0 then
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", player:GetQuestRewardExp(questId, tier), tier, unpack(slots))
	end
	return true
end
