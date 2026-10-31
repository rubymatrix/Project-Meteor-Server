--[[
Action rules: Combat asks the actor's profile what to use whenever the actor is free. Rule fields
and selectors: Data/Docs/AI-and-Content.md.
--]]

local ALLY_RANGE = 30

local compiled = {}

local function condition(rule)
	local w = rule.when
	if w == nil then return nil end
	if type(w) == "function" then return w end
	local f = compiled[w]
	if not f then
		local chunk, err = loadstring("local self, target, enc = ...; return " .. w, "=rule")
		if not chunk then
			log("error", 'rule condition "' .. w .. '": ' .. err)
			f = function() return false end
		else
			setfenv(chunk, setmetatable({}, { __index = R }))
			f = chunk
		end
		compiled[w] = f
	end
	return f
end

local function list(csList)
	local out = {}
	if csList == nil then return out end
	for i = 0, csList.Count - 1 do table.insert(out, wrap(csList[i])) end
	return out
end

local function nearby(self, range)
	return list(self.cs.perception:Candidates(range or ALLY_RANGE))
end

local function friends(self)
	local out = { self }
	for _, c in ipairs(nearby(self)) do
		if self:relation(c) == "friendly" then table.insert(out, c) end
	end
	return out
end

local function foes(self)
	local out = {}
	for _, c in ipairs(nearby(self)) do
		local r = self:relation(c)
		if r == "hostile" or (r == "neutral" and self.cs.hateContainer:HasHateForTarget(c.cs)) then table.insert(out, c) end
	end
	return out
end

local function rng(self)
	return self.cs.Brain.Rng
end

local function argOf(sel)
	return tonumber(sel:match("%((.-)%)")) or sel:match("%((.-)%)")
end

local Selectors = {}

function Selectors.resolve(self, sel)
	if type(sel) == "function" then return sel(self) end
	if type(sel) == "table" then return sel end
	sel = sel or "target"
	local name = sel:match("^(%w+)")
	local f = Selectors[name]
	if not f then return nil end
	return f(self, argOf(sel))
end

function Selectors.self(self) return self end
function Selectors.target(self) return self:target() end
function Selectors.owner(self) return self:owner() end
function Selectors.leader(self) return self.bb.leader or self:owner() end

function Selectors.lowestAlly(self, below)
	local best
	for _, c in ipairs(friends(self)) do
		if c:isAlive() and (below == nil or c:hpp() < below) and (best == nil or c:hpp() < best:hpp()) then best = c end
	end
	return best
end

function Selectors.lowestAllyBelow(self, pct) return Selectors.lowestAlly(self, pct or 50) end

function Selectors.allyWith(self, id)
	for _, c in ipairs(friends(self)) do if c:isAlive() and c:hasStatus(id) then return c end end
end

function Selectors.allyWithout(self, id)
	for _, c in ipairs(friends(self)) do if c:isAlive() and not c:hasStatus(id) then return c end end
end

function Selectors.enemyWith(self, id)
	for _, c in ipairs(foes(self)) do if c:hasStatus(id) then return c end end
end

function Selectors.enemyWithout(self, id)
	for _, c in ipairs(foes(self)) do if not c:hasStatus(id) then return c end end
end

function Selectors.random(self)
	local f = foes(self)
	if #f == 0 then return nil end
	return f[rng(self):Int(1, #f)]
end

function Selectors.randomPlayer(self)
	local f = {}
	for _, c in ipairs(foes(self)) do if c:isPlayer() then table.insert(f, c) end end
	if #f == 0 then return nil end
	return f[rng(self):Int(1, #f)]
end

function Selectors.nearest(self)
	local best, bd
	for _, c in ipairs(foes(self)) do
		local d = self:distance(c)
		if bd == nil or d < bd then best, bd = c, d end
	end
	return best
end

function Selectors.farthest(self)
	local best, bd
	for _, c in ipairs(foes(self)) do
		local d = self:distance(c)
		if bd == nil or d > bd then best, bd = c, d end
	end
	return best
end

function Selectors.mostHated(self) return self:target() end

function Selectors.tag(self, name)
	for _, c in ipairs(nearby(self)) do if c:is(name) and c:isAlive() then return c end end
end

local function inPhase(rule, enc)
	if rule.phase == nil then return true end
	local current = enc and enc.cs.Phase or ""
	if type(rule.phase) == "string" then return rule.phase == current end
	for _, p in ipairs(rule.phase) do if p == current then return true end end
	return false
end

-- Returns actionId, C# target or nil.
local function choices(self, rule)
	local u = rule.use
	if u == "moves" then
		if not self.__moves then
			local cs = self.cs
			local okG, genus = pcall(function() return cs.genusId end)
			local okP, path = pcall(function() return cs.classPath end)
			self.__moves = Moves.of(okG and genus or 0, okP and path or nil)
		end
		return self.__moves
	end
	return type(u) == "table" and u or { u }
end

function rt_actor_pick(id)
	local self = object(id)
	if not self or not self.spec or #self.spec.rules == 0 then return nil end
	local brain = self.cs.Brain
	local enc = self:encounter()
	self.__picks = self.__picks or {}
	if not self.cs:IsEngaged() then self.__picks = {} end
	local tiers, order = {}, {}
	for i, rule in ipairs(self.spec.rules) do
		local tier = rule.tier or i
		if not tiers[tier] then tiers[tier] = {} table.insert(order, tier) end
		table.insert(tiers[tier], rule)
	end
	table.sort(order)
	for _, tier in ipairs(order) do
		local passing, total = {}, 0
		for _, rule in ipairs(tiers[tier]) do
			local state = self.__picks[rule] or { count = 0, readyAt = 0 }
			self.__picks[rule] = state
			if NOW >= state.readyAt and (rule["max"] == nil or state.count < rule["max"]) and inPhase(rule, enc) then
				local target = Selectors.resolve(self, rule.on)
				if target and target.cs and (rule.chance == nil or brain.Rng:Range(0, 100) < rule.chance) then
					local cond = condition(rule)
					local ok = cond == nil or safecall(self, "rule", cond, self, target, enc)
					if ok then
						local usable = {}
						for _, action in ipairs(choices(self, rule)) do
							if brain:CanUse(action, target.cs) then
								table.insert(usable, { action, target })
							elseif rule.use == "moves" and brain:CanUse(action, self.cs) then
								-- Buff moves can only target the monster itself.
								table.insert(usable, { action, self })
							end
						end
						if #usable > 0 then
							local use = usable[math.min(#usable, math.floor(brain.Rng:Range(1, #usable + 1)))]
							table.insert(passing, { rule = rule, target = use[2], state = state, action = use[1] })
							total = total + (rule.weight or 1)
						end
					end
				end
			end
		end
		if #passing > 0 then
			local roll = brain.Rng:Range(0, total)
			local pick = passing[#passing]
			for _, p in ipairs(passing) do
				roll = roll - (p.rule.weight or 1)
				if roll <= 0 then pick = p break end
			end
			pick.state.count = pick.state.count + 1
			pick.state.readyAt = NOW + (pick.rule.cooldown or 0) * 1000
			return pick.action, pick.target.cs
		end
	end
	return nil
end
