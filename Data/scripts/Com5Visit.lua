require("Global")
require("Quest")
require("QuestDuty")

--[[
Shared flow for the Com5 dungeon visit quests (Toto-Rak, Dzemael Darkhold): a quest sets VISIT and
requires this file. The copy is per player, so only the party's upper bound is checked.
VISIT fields: Data/Docs/Scripts/Com5Visit.md.
--]]

local function partySize(player)
	local n = 1
	local party = player.currentParty
	if party ~= nil and party.members ~= nil then
		n = 0
		for id in party.members do n = n + 1 end
	end
	return n
end

local function call(player, quest, c)
	if c == nil then return nil end
	return callClientFunction(player, "delegateEvent", player, quest, unpack(c))
end

local function activeNpc(seq)
	local V = VISIT
	local t = V.talks[seq]
	if t ~= nil then return t.npc, QFLAG_TALK end
	if seq == V.enter.seq then return V.enter.npc, QFLAG_TALK end
	if seq == V.reward.seq then return V.reward.npc, QFLAG_REWARD end
	return nil, QFLAG_OFF
end

local function goIn(player, quest)
	local V = VISIT
	local d = V.duty
	startQuestDuty(player, quest, {
		zone = d.zone, area = d.area, director = d.director,
		anchor = d.anchor,
	})
end

-- The go-in ask at the entrance; true when the player went in (the event is over).
local function askEnter(player, quest)
	local V = VISIT
	if partySize(player) > V.party.max then
		call(player, quest, V.partyCall)
		return false
	end
	if call(player, quest, V.enter.ask) == 1 then
		goIn(player, quest)
		return true
	end
	return false
end

function onStart(player, quest)
	quest:StartSequence(0)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	local V = VISIT
	if sequence == SEQ_ACCEPT then
		quest:SetENpc(V.giver, QFLAG_TALK)
		return
	end

	local npc, flag = activeNpc(sequence)
	quest:SetENpc(V.giver, npc == V.giver and flag or QFLAG_OFF)
	for _, id in ipairs(V.npcs) do
		local gated = V.public == nil or not V.public[id]
		quest:SetENpc(id, npc == id and flag or QFLAG_OFF, true, false, false, gated)
	end
	-- The trigger lives in the content copy only.
	if sequence == V.enter.seq then
		quest:SetENpc(V.inside.trigger, QFLAG_PUSH, false, true, false, true)
	end
end

function onTalk(player, quest, npc)
	local V = VISIT
	local sequence = quest:GetSequence()
	local classId = npc:GetActorClassId()

	if sequence == SEQ_ACCEPT then
		if classId == V.giver and call(player, quest, V.offer) == 1 then
			player:AcceptQuest(quest)
		end
		player:EndEvent()
		return
	end

	local t = V.talks[sequence]
	if t ~= nil and classId == t.npc then
		call(player, quest, t.call)
		quest:StartSequence(t.next)
		if t.enter and askEnter(player, quest) then
			return
		end
	elseif sequence == V.enter.seq and classId == V.enter.npc then
		if askEnter(player, quest) then
			return
		end
	elseif sequence == V.reward.seq and classId == V.reward.npc then
		call(player, quest, V.reward.call)
		local rewarded = showQuestRewards(player, quest)
		player:EndEvent()
		if rewarded then player:CompleteQuest(quest) end
		return
	elseif classId == V.giver then
		call(player, quest, V.giverRepeat)
	elseif V.repeats[classId] ~= nil then
		call(player, quest, V.repeats[classId])
	end

	player:EndEvent()
	quest:UpdateENPCs()
end

function questBattleOptions(player, quest)
	local I = VISIT.inside
	local opts = { timeLimit = VISIT.minutes * 60 }
	if I.enemies ~= nil then
		local p = I.pos
		opts.reserve = {}
		for _, m in ipairs(I.enemies) do
			table.insert(opts.reserve, { m[1], p[1] + m[2], p[2], p[3] + m[3], 0, level = I.level })
		end
	end
	return opts
end

function onPush(player, quest, npc)
	local V = VISIT
	local I = V.inside
	if quest:GetSequence() ~= V.enter.seq or npc:GetActorClassId() ~= I.trigger then
		player:EndEvent()
		return
	end
	local director = player.CurrentArea:GetContentDirector()
	local fight = director ~= nil and director:GetEncounter() or nil
	if fight == nil then
		player:EndEvent()
		return
	end

	if I.enemies == nil then
		call(player, quest, I.call)
		player:EndEvent()
		fight:Win("script")
		return
	end
	if not questFlag(quest, 0) then
		call(player, quest, I.call)
		setQuestFlag(quest, 0)
		fight:GotoPhase("reserve")
	end
	player:EndEvent()
end

local function clearFight(quest)
	local data = quest:GetData()
	data:ClearFlag(0)
	data:Save()
end

function onDutyComplete(player, quest, director, duty, success, reason)
	local V = VISIT
	if quest:GetSequence() ~= V.enter.seq then
		return
	end
	clearFight(quest)
	local o = V.outside

	if success then
		wait(2)
		if V.inside.enemies ~= nil and V.inside.won ~= nil then
			call(player, quest, V.inside.won)
		end
		quest:StartSequence(V.after)
		player:SendGameMessage(GetWorldMaster(), 50012, 0x20) -- You are no longer bound by duty.
		player:EndEvent()
		endQuestDuty(player, duty, o[1], {o[2], o[3], o[4], o[5]})
		return
	end

	-- Time up, KO or left: go in again from the entrance NPC.
	if reason == "left" then
		endQuestDuty(player, duty)
		return
	end
	wait(3)
	player:SendGameMessage(GetWorldMaster(), 50012, 0x20)
	endQuestDuty(player, duty, o[1], {o[2], o[3], o[4], o[5]})
end

function getJournalInformation(player, quest)
	return VISIT.journal(quest:GetSequence())
end

function getJournalMapMarkerList(player, quest)
	local m = VISIT.markers[quest:GetSequence()]
	if m ~= nil then
		return unpack(m)
	end
end
