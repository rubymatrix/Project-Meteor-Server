--[[

Special constants used by quest scripts, and the lookup their event tables share.

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

-- Handlers are keyed by sequence, then by NPC class id. A handler returns true when it has
-- already ended the event itself.
function runQuestHandler(handlers, player, quest, npc, ...)
	local byNpc = handlers[quest:GetSequence()]
	local handler = byNpc and byNpc[npc:GetActorClassId()]
	return handler ~= nil and handler(player, quest, npc, ...)
end
