--[[
Toll of the Warden (Man300 SEQ_025/030), director QuestDirectorMan30001: the excavation mesa.
Four Ixali and Amalj'aa fighters that never start a fight and give up at 1 HP. The quest decides
when both tribes are settled; phases "ixalSettled" / "amaljaaSettled" stand one down after a Parley.
--]]

local Mesa = Encounter.define("QuestDirectorMan30001")

local POOL_IXALI_SWORDFIGHTER = 8206404
local POOL_AMALJAA_DRUBBER = 8206503
local POOL_AMALJAA_BOWYER = 8206511
local FIGHTER_LEVEL = 30
local TIME_LIMIT_SECONDS = 1800

local MOD_MINIMUM_HP_LOCK = 114
local TEXT_BOUND_BY_DUTY = 50011
local TEXT_OBJECTIVE = 51022
local TEXT_WILL_TO_FIGHT = 51002
local TEXT_DISENGAGE = 32606
local TEXT_TIME_MINUTES = 25018
local DRUBBER_DISPLAY_ID = 3206503
local SWORDFIGHTER_DISPLAY_ID = 3206404
local BOWYER_DISPLAY_ID = 3206511

local FIGHTERS = {
	{ POOL_IXALI_SWORDFIGHTER, 995.138, 251.290, -238.078, 2.332, tribe = "ixal", display = SWORDFIGHTER_DISPLAY_ID },
	{ POOL_IXALI_SWORDFIGHTER, 1007.453, 251.290, -243.753, 2.332, tribe = "ixal", display = SWORDFIGHTER_DISPLAY_ID },
	{ POOL_AMALJAA_DRUBBER, 1001.052, 251.234, -246.198, 2.332, tribe = "amaljaa", display = DRUBBER_DISPLAY_ID },
	{ POOL_AMALJAA_BOWYER, 997.981, 251.274, -233.886, 2.905, tribe = "amaljaa", display = BOWYER_DISPLAY_ID },
}

local FIGHTER_PROFILE = { behaviors = { Roam = false, Detect = false, Link = false } }

function Mesa:setup()
	self.player = self:participants()[1]
	self.fighters = {}
	self:timeLimit(TIME_LIMIT_SECONDS)
	for i, f in ipairs(FIGHTERS) do
		local mob = self:spawn("fighters", { pool = f[1], level = FIGHTER_LEVEL, at = { f[2], f[3], f[4], f[5] },
			group = { "fighters", "fighter" .. i }, profile = FIGHTER_PROFILE })
		if mob then
			mob.cs:SetMod(MOD_MINIMUM_HP_LOCK, 1)
			table.insert(self.fighters, { mob = mob, def = f, index = i })
		end
	end
end

-- No aggro, no swings, no movement, no target.
function Mesa:makeInert(mob)
	mob:remove("Combat")
	mob:disengage()
	mob:push("Hold", { id = "inert", channels = { "Move", "Face", "Act", "Target" } })
	self.cs:SetTargetable(mob.cs, false)
end

function Mesa:settleTribe(tribe)
	for _, f in ipairs(self.fighters) do
		if not f.withdrawn and f.def.tribe == tribe and f.mob:isAlive() then
			f.withdrawn = true
			self:makeInert(f.mob)
		end
	end
end

function Mesa:phase_ixalSettled() self:settleTribe("ixal") end
function Mesa:phase_amaljaaSettled() self:settleTribe("amaljaa") end

function Mesa:withdraw(f)
	f.withdrawn = true
	local tribe = f.def.tribe
	local subdued = self:counter(tribe, 1)
	self:tell(nil, TEXT_WILL_TO_FIGHT, f.def.display, subdued)
	self:tell(nil, TEXT_DISENGAGE)
	self:counter("withdrawn" .. f.index, 1)
	self:makeInert(f.mob)
end

function Mesa:onStart()
	self:tell(nil, TEXT_BOUND_BY_DUTY)
	self:tell(nil, TEXT_OBJECTIVE, DRUBBER_DISPLAY_ID, 2, SWORDFIGHTER_DISPLAY_ID, 2)
	self:tell(nil, TEXT_TIME_MINUTES, TIME_LIMIT_SECONDS / 60)
	self:every(1, function()
		for _, f in ipairs(self.fighters) do
			local mob = f.mob
			if not f.withdrawn and mob:isAlive() then
				if not f.spoke and mob:isEngaged() then
					f.spoke = true
					self:counter("engaged" .. f.index, 1)
				end
				if mob:hp() <= 1 then self:withdraw(f) end
			end
		end
	end)
end

return Mesa
