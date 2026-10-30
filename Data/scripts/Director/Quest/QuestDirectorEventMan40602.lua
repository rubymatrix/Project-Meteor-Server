require("Global")
require("QuestFlow")
require("Quest/Man/Man406")

--[[

QuestDirectorEventMan40602: Futures Perfect (Man406) Seq 25, Camp Revenant's Toll after the vision
(content SimpleContentMan40604). Walking out of it warns at 35 yalms from the wake mark and at 40 leaves
the instance where the player stands. A teleport out (the usual way to the report) just releases it.

--]]

local CAUTION_DISTANCE = 35.0
local EXIT_DISTANCE    = 40.0
local TEXT_LEAVING_INSTANCE = 34109
local TEXT_LEFT_INSTANCE    = 34110

function init()
	return "/Director/Quest/QuestDirectorEventMan40602"
end

function onEventStarted(player, director, triggerName)
	local area = player.CurrentArea
	player:EndEvent()
	player:SendGameMessage(GetWorldMaster(), TEXT_BOUND_BY_DUTY, 0x20)
	local quest = player:GetQuest("Man406")
	if quest ~= nil then
		quest:UpdateENPCs()
	end

	local mark = AFTERMATH_LANDING
	local cautioned = false
	while player.CurrentArea == area do
		wait(1)
		if player.CurrentArea ~= area then
			break
		end
		local d = math.sqrt((player.positionX - mark[2]) ^ 2 + (player.positionZ - mark[4]) ^ 2)
		if d > EXIT_DISTANCE then
			player:SendGameMessage(GetWorldMaster(), TEXT_LEFT_INSTANCE, 0x20)
			player:SendGameMessage(GetWorldMaster(), TEXT_UNBOUND_FROM_DUTY, 0x20)
			pcall(function() area:ContentFinished() end)
			warpToPublic(player)
			return
		elseif d > CAUTION_DISTANCE then
			if not cautioned then
				cautioned = true
				player:SendGameMessage(GetWorldMaster(), TEXT_LEAVING_INSTANCE, 0x20)
			end
		else
			cautioned = false
		end
	end
	pcall(function() area:ContentFinished() end)
end

function main()
end
