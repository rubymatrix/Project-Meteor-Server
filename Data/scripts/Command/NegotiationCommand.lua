--[[

NegotiationCommand Script

Functions:

openListWidget(player, originId, 10 bools to show/hide) - Shows a list of things to Parley for based on a sequential list from xtx_negotiationTable.
openAskWidget(player, title, difficulty, desiredItemId, requiredItemId) - Opens the widget asking if the player will Parley.
openNegotiationWidget(player, title, itemId, maxTurns, time, ability1, ability2, ability3, ability4, ability5) - Inits the widget system (call first).
inputNegotiationWidget(player, ?, abort, resumeTimer) - Begins player input.
closeNegotiationWidget(player) - Closes the Parley widget.
negotiationEmote(player, animId) - Plays an animation

updateNegotiationWidget(player, gridIndex, key, itemIconId, pointValue, ?, ?) - Updates the Parley UI depending on the first argument:

< 12: Places Item
13: Plays SFX + ???
14: Sets the Negotiation Gauge (max, value)
15: Sets the Achievement Gauge (max, value)

16: Additional Item 1 (bool)
17: Additional Item 2(bool)
18: Additional Item 3(bool)

19: Set the last chosen items (index[1-6], iconId)

20:
21:

22: Clear Timer
23: Play player move SFX
24: Play opponent move SFX
25: Play times up SFX and close ability widget
26:
27:
28: Pauses the Timer
29: Resumes the Timer

--]]

require("Global")

-- Parley (command 29497) on a target belongs to the quest that owns it: that quest's onParley plays
-- it and ends the event. The client offers Parley only on npcs whose class allows it.
local PARLEY_RANGE = 15.0
local TEXT_TOO_FAR_AWAY = 25081
local TEXT_UNABLE_TO_PARLEY = 40428

local function resolveTarget(player, targetActorId)
	local actorId = tonumber(targetActorId)
	if actorId == nil or actorId == 0 then
		actorId = player.currentTarget
	end
	if actorId == nil or actorId == 0 then
		return nil
	end
	return player:GetActorInInstance(actorId)
end

function onEventStarted(player, commandactor, eventType, eventName, arg1, arg2, arg3, arg4, targetActorId)
	local target = resolveTarget(player, targetActorId)
	if target == nil then
		player:EndEvent()
		return
	end

	local ok, quests = pcall(function() return toLuaTable(player:GetQuestsForNpc(target)) end)
	if not ok or #quests == 0 then
		player:SendGameMessage(GetWorldMaster(), TEXT_UNABLE_TO_PARLEY, 0x20, 0, 0, target)
		player:EndEvent()
		return
	end

	local dx, dz = player.positionX - target.positionX, player.positionZ - target.positionZ
	if dx * dx + dz * dz > PARLEY_RANGE * PARLEY_RANGE then
		player:SendGameMessage(GetWorldMaster(), TEXT_TOO_FAR_AWAY, 0x20)
		player:EndEvent()
		return
	end

	quests[1]:OnParley(player, target)
end
