--[[
Caravan escort from Camp Tranquil, started by the Caravan Manager. Three pack chocobos walk the road
and halt while raiders are near; raiders only hit the chocobos, which bolt and drop packs. Delivered
when a chocobo reaches the end; failed when every pack is lost or time runs out.
--]]

local Caravan = WorldEvent.define("CaravanGuardTranquil")

local POOL_CHOCOBO, POOL_RAIDER = 9300001, 9300002
local BIRDS, PACKS_PER_BIRD = 3, 2
local TIME_LIMIT = 30 * 60
local HALT_RANGE = 25
local RAIDERS_PER_AMBUSH = 3
local TEXT_TIME_MINUTES = 25018
local SERPENT_SEAL, SEALS_PER_PACK = 1000202, 200
local INVENTORY_CURRENCY = 0x0063

function Caravan:setup(opts)
	self.route = Route.load("CaravanGuard/fst0Field05")
	self:timeLimit(TIME_LIMIT)
	self.level = opts.level or 25
	for i = 1, BIRDS do
		local bird = self:spawn("chocobo", { pool = POOL_CHOCOBO, kind = "Ally", level = self.level,
			at = self.route:start(-3 * i), hp = 3000, profile = "Content/Profiles/ChocoboCaravanGuard" })
		if bird then bird.bb.packs = PACKS_PER_BIRD end
	end
	self:objective("delivery", Objective.reach("chocobo", self.route:last(), 1, 6), { wins = true })
	self:objective("chocobos", Objective.protect("chocobo", 1), { fails = true })
	self:objective("cargo", Objective.custom(function() return self:cargo() == 0 and "failed" or false end), { fails = true })
	self:contributionRule({ warnings = 3, check = 120, grace = 180, min = 60 })
end

function Caravan:cargo()
	local n = 0
	for _, b in ipairs(self:group("chocobo"):list()) do
		if b:isAlive() then n = n + (b.bb.packs or 0) end
	end
	return n
end

function Caravan:raidersNear()
	for _, r in ipairs(self:group("raiders"):list()) do
		if r:isAlive() then
			local bird = self:group("chocobo"):nearest(r)
			if bird and r:distance(bird) <= HALT_RANGE then return true end
		end
	end
	return false
end

function Caravan:onStart()
	self:broadcast(TEXT_TIME_MINUTES, TIME_LIMIT / 60)
	self:group("chocobo"):add("Escort", {
		route = self.route, pace = "walk", resume = 4,
		haltWhen = function() return self:raidersNear() end,
		waitFor = { group = "participants", range = 35 },
	})
	for i, stop in ipairs(self.route:points("ambush")) do
		self:once("WaypointReached", { name = stop.name }, function()
			local specs = {}
			for k = 1, RAIDERS_PER_AMBUSH do
				table.insert(specs, { at = { stop[1] + (k - 2) * 4, stop[2], stop[3] - 14 } })
			end
			self:spawnGroup(specs, { pool = POOL_RAIDER, level = self.level, group = "raiders",
				profile = "Content/Profiles/CaravanRaider" })
		end)
	end
	self:on("Signal", { name = "contributionWarning" }, function(_, ev)
		ev.actor.cs:SendMessage(0x20, "", "Protect the caravan to earn your share.")
	end)
end

function Caravan:onEnd(result)
	local packs = result == "win" and self:cargo() or 0
	for _, p in ipairs(self:participants()) do
		if not self.cs:IsDropped(p.cs) and packs > 0 then
			p.cs:GetItemPackage(INVENTORY_CURRENCY):AddItem(SERPENT_SEAL, packs * SEALS_PER_PACK, 1)
		end
	end
end

return Caravan
