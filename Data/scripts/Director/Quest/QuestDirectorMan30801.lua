require("Global")
require("QuestFlow")
require("Quest/Man/Man308")

--[[
Lord Errant (Man308), the Gold Court offer (content SimpleContentMan30801, Ul'dah 209). The client
class is an empty QuestDirectorBaseClass subclass. No fight: the Path companion waits on the plaza
and its talk is the offer (Man308.lua offerAtGoldCourt).
--]]

local watchContentArea

function init()
	return "/Director/Quest/QuestDirectorMan30801"
end

function onEventStarted(player, director, triggerName)
	local area = player.CurrentArea
	local quest = player:GetQuest(110017) or player.questStateManager:GetActiveQuest(110017)
	if not SNPC_TALK_ROUTED and quest ~= nil and (quest:GetSequence() == SEQ_ACCEPT or quest:GetSequence() == SEQ_HELD) then
		-- Without routed companion talk, the offer plays on landing.
		offerAtGoldCourt(player, quest)
		return
	end
	player:EndEvent()
	watchContentArea(player, area)
end

-- No hook runs when a teleport or a Return carries the player out, so the area is released here.
function watchContentArea(player, area)
	while player.CurrentArea == area do
		wait(2)
	end
	pcall(function() area:ContentFinished() end)
end

function main()
end
