--[[
The Grand Company story raids: the Howling Eye, the Castrum Novum transmission tower and Rivenroad.
Each is a stand-in fight (a boss and two adds, no mechanics) won when all three are down. The
Lesser Ifrit director shares the story half. Variant and story fields, the quest hook:
Data/Docs/Scripts/Content/InstanceRaid/StoryRaid.md.
--]]

local StoryRaid = ContentArea.define("StoryRaid")

local AREA_CLASS = "/Area/PrivateArea/Occupancy/RaidDungeonSimple"
local AREA_SCRIPT = "SimpleContentOccupancy"
local TIME_LIMIT_SECONDS = 1800
local EXIT_DELAY_SECONDS = 8
local SPAWN_TYPE_EXIT = 2
local COMPANY_QUEST_BLOCKS = { 111400, 111600, 111800 }
local FOE_PROFILE = {
	behaviors = { Roam = false, Detect = {} },
	senses = { proximity = { range = 30 } },
}

StoryRaid:variant("LesserGaruda", {
	zone = 239,
	entry = { 1269.0, 364.5, -340.0, 0.0 },
	centre = { 1269.0, 364.5, -325.0 },
	boss = { pool = 100277, level = 42, hp = 9000, at = { 0.0, 6.0 } },
	adds = { { pool = 100278, level = 40, at = { -6.0, 2.0 } }, { pool = 100280, level = 40, at = { 6.0, 2.0 } } },
	quests = 30,
	bonus = "company",
	exit = { zone = 143, at = { 1006.0, 299.0, -66.0, 2.4 } },
})

StoryRaid:variant("BeaconBattle", {
	zone = 264,
	entry = { 300.0, 32.6, 300.0, 0.0 },
	centre = { 300.0, 32.6, 315.0 },
	boss = { pool = 100309, level = 47, hp = 12000, at = { 0.0, 6.0 } },
	adds = { { pool = 100273, level = 45, at = { -6.0, 2.0 } }, { pool = 100274, level = 45, at = { 6.0, 2.0 } } },
	quests = 32,
	bonus = "allCompanies",
	exit = { zone = 190, at = { -352.0, -16.0, -33.0, 0.8 } },
})

StoryRaid:variant("LesserWhiteGeneral", {
	zone = 257,
	entry = { 18.0, 0.7, 0.0, -1.57 },
	centre = { 4.0, 0.0, 0.0 },
	boss = { pool = 100238, level = 50, hp = 15000, at = { -4.0, 0.0 } },
	adds = { { pool = 100239, level = 47, at = { -2.0, 6.0 } }, { pool = 100236, level = 47, at = { -2.0, -6.0 } } },
	quests = 33,
	bonus = "allCompanies",
	exit = { zone = 155, at = { 56.0, -7.0, -1209.0, 0.0 } },
})

-- The content area and entry point of a director's variant (call on the :as copy).
function StoryRaid:areaFor(director)
	local c = self.__variants.default
	return {
		zone = c.zone,
		classPath = AREA_CLASS,
		name = director:sub(1, 1):lower() .. director:sub(2),
		script = AREA_SCRIPT,
		director = "InstanceRaid/" .. director,
	}, c.entry
end

local function heldQuest(player, suffix)
	for _, block in ipairs(COMPANY_QUEST_BLOCKS) do
		local quest = player:GetQuest(block + suffix)
		if quest ~= nil then return quest end
	end
	return nil
end

local function earnedBonus(rule, player, players)
	local seen, same = {}, true
	for _, p in ipairs(players) do
		local gc = p.cs.gcCurrent
		seen[gc] = true
		if gc == 0 or gc ~= player.gcCurrent then same = false end
	end
	if rule == "company" then return same end
	if rule == "allCompanies" then return seen[1] == true and seen[2] == true and seen[3] == true end
	return false
end

-- opts.participants (the party, without the starter Content.launch already sent) follow the starter in.
function StoryRaid.begin(self)
	self.cs:SetCleanupSeconds(EXIT_DELAY_SECONDS + 5)
	local director = self.cs.Director
	for _, player in ipairs(self.opts.participants or {}) do
		player:AddDirector(director)
		player:SetLoginDirector(director)
		self:warp(wrap(player), self.entry)
	end
end

function StoryRaid.onEnd(self, result)
	local story = self.story
	local players = self:participants()
	local director = self.cs.Director
	if result == "win" then
		for _, p in ipairs(players) do
			local quest = heldQuest(p.cs, story.quests)
			if quest ~= nil then
				local bonus = earnedBonus(story.bonus, p.cs, players)
				local ok, err = pcall(function()
					GetLuaInstance():CallLuaFunction(p.cs, quest, "onRaidCleared", true, director, bonus)
				end)
				if not ok then log("error", self.__name .. ": onRaidCleared failed: " .. tostring(err)) end
			end
		end
	end
	wait(EXIT_DELAY_SECONDS)
	local area = self.cs.Area
	local x = story.exit.at
	for _, p in ipairs(players) do
		local player = p.cs
		if player.playerSession ~= nil and player.CurrentArea == area then
			if result == "win" and p:isDead() then player:Revive(100) end
			pcall(function() player:RemoveDirector(director) end)
			GetWorldManager():DoZoneChange(player, story.exit.zone, nil, 0, SPAWN_TYPE_EXIT, x[1], x[2], x[3], x[4] or 0)
		end
	end
	pcall(function() area:ContentFinished() end)
end

function StoryRaid:setup()
	local c = self.cfg
	self.story = c
	self:timeLimit(c.timeLimit or TIME_LIMIT_SECONDS)
	local centre = c.centre
	for _, f in ipairs({ c.boss, c.adds[1], c.adds[2] }) do
		local x, z = centre[1] + f.at[1], centre[3] + f.at[2]
		local rot = math.atan2(centre[1] - x, centre[3] - z)
		self:spawn("foes", { pool = f.pool, level = f.level, hp = f.hp, at = { x, centre[2], z, rot }, profile = FOE_PROFILE })
	end
	self:objective("foes", Objective.kill("foes"), { wins = true })
end

function StoryRaid:onStart()
	StoryRaid.begin(self)
end

return StoryRaid
