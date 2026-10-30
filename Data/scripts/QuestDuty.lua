require("Global")
require("QuestFlow")

--[[
Quest-side helpers for the story, company and Grand Company quests that start their own content.

The quest makes the content copy and zones the player in (startQuestDuty). The kicked director runs
the fight (runQuestBattle: Content/Quest/QuestBattle.lua or the director's own content) and hands the
outcome to the quest's onDutyComplete(player, quest, director, fight, success, reason), where reason
is "cleared", "script", "ko", "time" or "left". The quest's closing scene ends with endQuestDuty.

startQuestDuty def: zone (parent zone id), area (content area name), director (script under
Director/), anchor = { x, y, z, rot } (where the player arrives).
--]]

function snpcBlock(player)
	return player:GetSNpcNickname(), player:GetSNpcSkin(), player:GetSNpcPersonality(), player:GetSNpcCoordinate(), player:GetInitialTown()
end

-- The companion's actor class: the client's getSnpcActorClassID.
function snpcClassId(player)
	return 1070000 + player:GetSNpcSkin()
end

function startQuestDuty(player, quest, def)
	player:EndEvent()
	local zone = GetWorldManager():GetZone(def.zone)
	if zone == nil then
		printf("startQuestDuty: zone %s not loaded", tostring(def.zone))
		return nil
	end
	local area = zone:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", def.area, def.area, def.director)
	if area == nil then
		return nil
	end

	local director = area:GetContentDirector()
	player:AddDirector(director)
	director:StartDirector(false)
	player:KickEvent(director, "noticeEvent", true)
	player:SetLoginDirector(director)

	local a = def.anchor
	-- Spawn type 15: on 16 the warp leaves Now Loading up for a cutscene this noticeEvent never plays.
	GetWorldManager():DoZoneChangeContent(player, area, a[1], a[2], a[3], a[4] or 0, 15)
	return director, area
end

--[[
The director's half: waits for the zone-in, starts battle.encounter (variant battle.variant) and
calls the quest's onDutyComplete when it ends. battle.options(player, quest) may add StartContent
opts. The quest script must be required by the director.
--]]
function runQuestBattle(player, director, battle)
	player:EndEvent()
	local area = director.CurrentArea
	for i = 1, 20 do
		if player.CurrentArea == area then
			break
		end
		wait(0.5)
	end
	local quest = player:GetQuest(battle.quest)
	if player.CurrentArea ~= area or quest == nil then
		return
	end

	local opts = { director = director }
	if battle.options ~= nil then
		for k, v in pairs(battle.options(player, quest)) do
			opts[k] = v
		end
	end
	local fight = StartContent(battle.encounter, battle.variant or "", area, player, opts)
	if fight == nil then
		return
	end
	while fight.IsRunning and player.CurrentArea == area do
		wait(1)
	end

	quest = player:GetQuest(battle.quest)
	if quest == nil then
		fight:Close()
		return
	end
	local reason = player.CurrentArea ~= area and "left" or fight.Reason
	onDutyComplete(player, quest, director, fight, fight.Result == "win", reason)
end

-- After the closing scene: the fight's actors go, the content area is let go, the player zones out.
function endQuestDuty(player, fight, zoneId, pos)
	local area = player.CurrentArea
	if fight ~= nil then
		area = fight.Area or area
		fight:Close()
	end
	pcall(function() area:ContentFinished() end)
	if zoneId ~= nil and pos ~= nil then
		GetWorldManager():DoZoneChange(player, zoneId, nil, 0, 15, pos[1], pos[2], pos[3], pos[4] or 0)
	end
end

-- A point d ahead of (x, z) facing rot, s to the side.
function aheadOf(x, z, rot, d, s)
	local fx, fz = math.sin(rot), math.cos(rot)
	return x + fx * d + fz * (s or 0), z + fz * d - fx * (s or 0)
end

function questFlag(quest, flag)
	return quest:GetData():GetFlag(flag)
end

function setQuestFlag(quest, flag)
	local data = quest:GetData()
	data:SetFlag(flag)
	data:Save()
end
