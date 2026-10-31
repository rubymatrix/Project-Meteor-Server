require("Global")

--[[
Journal actions. The journal sends command(journalId, subindex): 1 abandon quest, 2/3 break a
regional/local leve, 4/5 retry a regional/local leve.
--]]

local JOURNAL_ABANDON_QUEST = 1
local JOURNAL_BREAK_REGIONAL = 2
local JOURNAL_BREAK_LOCAL = 3
local JOURNAL_RETRY_REGIONAL = 4
local JOURNAL_RETRY_LOCAL = 5

local LOCAL_GUILDLEVE_ID_BASE = 120000

local toGuildleveId, breakGuildleve, retryGuildleve

function onEventStarted(player, command, eventType, eventName, journalId, subindex)

	journalId = tonumber(journalId) or 0
	subindex = tonumber(subindex) or JOURNAL_ABANDON_QUEST

	if subindex == JOURNAL_ABANDON_QUEST then
		player:AbandonQuest(journalId)
	elseif subindex == JOURNAL_BREAK_REGIONAL or subindex == JOURNAL_BREAK_LOCAL then
		breakGuildleve(player, toGuildleveId(journalId, subindex == JOURNAL_BREAK_LOCAL))
	elseif subindex == JOURNAL_RETRY_REGIONAL or subindex == JOURNAL_RETRY_LOCAL then
		retryGuildleve(player, toGuildleveId(journalId, subindex == JOURNAL_RETRY_LOCAL))
	else
		printf("JournalCommand: unknown subindex %d for journal id %d", subindex, journalId)
	end

	player:EndEvent()

end

-- Local leves sit in the journal as id - 120000; accept either form.
function toGuildleveId(journalId, isLocal)
	if isLocal and journalId > 0 and journalId < LOCAL_GUILDLEVE_ID_BASE then
		return journalId + LOCAL_GUILDLEVE_ID_BASE
	end
	return journalId
end

-- Break: drop the leve from the journal, failing it first if it is running.
function breakGuildleve(player, glId)
	if not player:HasGuildleve(glId) then
		return
	end

	local director = player:GetGuildleveDirector()
	if director ~= nil and director.guildleveId == glId then
		director:AbandonGuildleve()
	end

	player:RemoveGuildleve(glId)
end

-- Retry: a failed regional leve goes back to retained; a local one restarts with fresh materials.
function retryGuildleve(player, glId)
	if not player:HasGuildleve(glId) or not player:IsGuildleveFailed(glId) then
		return
	end

	if player:GetLeveAllowances() < player:GetLeveRetryAllowanceCost() then
		player:SendGameMessage(GetWorldMaster(), 50142, 0x20) -- out of leve allowances
		return
	end

	if player:RetryGuildleve(glId) then
		player:SendGameMessage(GetWorldMaster(), 50141, 0x20, player:GetLeveAllowances())
	end
end
