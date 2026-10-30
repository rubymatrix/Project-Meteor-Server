--[[
Actors and profiles: resolving an npc's profile from its layers and applying it to its brain, and
the methods profiles and content call on actors. Layers and merge rules: Data/Docs/AI-and-Content.md.
--]]

local vec

Profile = {}

local profileMeta = {
	__call = function(p, t)
		for k, v in pairs(t) do p[k] = v end
		return p
	end,
}

function Profile.define(t)
	t = t or {}
	t.__profile = true
	return setmetatable(t, profileMeta)
end

-- Profile.extend("kinds/battlenpc") { ... } or local P = Profile.extend("kinds/ally"); function P:onX() end
function Profile.extend(base, t)
	local p = Profile.define(t)
	p.__extends = base
	return p
end

local function isHook(k, v)
	return type(v) == "function" and (k:sub(1, 2) == "on" or k == "think")
end

-- Wrapped actors and other objects stay shared; a copy would lose what makes them host values.
local function copy(t)
	if type(t) ~= "table" or getmetatable(t) ~= nil then return t end
	local out = {}
	for k, v in pairs(t) do out[k] = copy(v) end
	return out
end

local function mergeTable(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" and type(dst[k]) == "table" and v.cs == nil and #v == 0 and next(v) ~= nil then
			mergeTable(dst[k], v)
		else
			dst[k] = copy(v)
		end
	end
end

local function mergeLayer(spec, layer)
	for k, v in pairs(layer) do
		if k == "__profile" or k == "__extends" then
			-- skip
		elseif k == "behaviors" then
			for kind, params in pairs(v) do
				if params == false then
					spec.behaviors[kind] = false
				elseif type(params) == "table" then
					if params.replace or type(spec.behaviors[kind]) ~= "table" then
						local p = copy(params)
						p.replace = nil
						spec.behaviors[kind] = p
					else
						mergeTable(spec.behaviors[kind], params)
					end
				end
			end
		elseif k == "rules" then
			if v.append then
				for _, r in ipairs(v.append) do table.insert(spec.rules, r) end
			elseif v.prepend then
				for i = #v.prepend, 1, -1 do table.insert(spec.rules, 1, v.prepend[i]) end
			else
				spec.rules = {}
				for _, r in ipairs(v) do table.insert(spec.rules, r) end
			end
		elseif k == "onHp" then
			for pct, fn in pairs(v) do
				spec.onHp[pct] = spec.onHp[pct] or {}
				table.insert(spec.onHp[pct], 1, fn)
			end
		elseif k == "tags" then
			for _, t in ipairs(v) do table.insert(spec.tags, t) end
		elseif type(k) == "string" and isHook(k, v) then
			spec.hooks[k] = spec.hooks[k] or {}
			table.insert(spec.hooks[k], 1, v)
		elseif type(v) == "function" then
			spec.methods[k] = v
		elseif type(v) == "table" and type(spec[k]) == "table" then
			mergeTable(spec[k], v)
		else
			spec[k] = copy(v)
		end
	end
end

local function newSpec()
	return { behaviors = {}, rules = {}, hooks = {}, onHp = {}, tags = {}, methods = {}, layers = {} }
end

-- A layer is a module name or a profile table; returns the table, following __extends.
local function addLayer(spec, layer, seen)
	seen = seen or {}
	if layer == nil or layer == false then return end
	local t, name = layer, nil
	if type(layer) == "string" then
		name = layer
		if seen[name] then return end
		seen[name] = true
		t = use(layer)
		if type(t) ~= "table" then return end
	end
	if t.__extends then addLayer(spec, t.__extends, seen) end
	mergeLayer(spec, t)
	table.insert(spec.layers, name or "(inline)")
end

function Profile.resolve(layers)
	local spec = newSpec()
	for _, l in ipairs(layers) do addLayer(spec, l) end
	return spec
end


ActorObject = class(Object)
local actorMethods = ActorObject

local bbMeta = {
	__index = function(p, k)
		local brain = p.cs.Brain
		if brain == nil then return nil end
		local v = brain:GetBb(k)
		if v ~= nil and type(v) == "userdata" then return wrap(v) end
		return v
	end,
	__newindex = function(p, k, v)
		local brain = p.cs.Brain
		if brain ~= nil then brain:SetBb(k, toHost(v, p.owner)) end
	end,
}

ActorObject.__index = function(t, k)
	local v = actorMethods[k]
	if v ~= nil then return v end
	if k == "bb" then return setmetatable({ cs = rawget(t, "cs"), owner = t }, bbMeta) end
	if k == "id" then return rawget(t, "cs").Id end
	local m = rawget(t, "__methods")
	return m and m[k]
end

local function familyName(cs)
	local idx = use("Ai/Families/Index") or {}
	local ok, genus = pcall(function() return cs.genusId end)
	return ok and genus and idx[genus] or nil
end

local function poolFlags(cs)
	local okN, neutral = pcall(function() return cs.neutral end)
	local okL, link = pcall(function() return cs.linkType end)
	local b = {}
	if okN and neutral == false then b.Detect = {} end
	if okL and link and link ~= 0 then b.Link = { radius = 10, by = "family" } end
	return next(b) and { behaviors = b } or nil
end

function ActorObject:layers()
	local cs = self.cs
	local list = { "Ai/Kinds/" .. self.kind }
	local flags = self.kind == "BattleNpc" and poolFlags(cs)
	if flags then table.insert(list, flags) end
	local fam = familyName(cs)
	if fam then table.insert(list, "Ai/Families/" .. fam) end
	local ok, pool = pcall(function() return cs.poolId end)
	if ok and pool and pool ~= 0 then table.insert(list, "Ai/Pools/" .. pool) end
	local ok2, spawnId = pcall(function() return cs:GetBattleNpcId() end)
	if ok2 and spawnId and spawnId ~= 0 and cs.CurrentArea then
		table.insert(list, "Ai/Zones/" .. cs.CurrentArea.ZoneName .. "/" .. spawnId)
	end
	if self.extra then table.insert(list, self.extra) end
	if self.override then table.insert(list, self.override) end
	return list
end

local function mask(names)
	local m = 0
	for _, n in ipairs(names or {}) do m = m + (CHANNELS[n] or 0) end
	return m
end
R.channelMask = mask

local function sortedKeys(t)
	local keys = {}
	for k in pairs(t) do table.insert(keys, k) end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	return keys
end

function ActorObject:apply()
	local cs = self.cs
	local brain = cs.Brain
	local spec = Profile.resolve(self:layers())
	self.spec = spec
	self.__methods = spec.methods
	self.__name = (cs:GetName() or "actor") .. "#" .. tostring(cs.Id)
	if spec.faction then cs.factionId = HOST:DefineFaction(spec.faction) end
	for _, t in ipairs(spec.tags) do cs.tags:Add(t) end
	if spec.senses then cs.perception:ConfigureFrom(toHost(spec.senses, self)) end
	if spec.hate then cs.hateContainer:SetModeFrom(spec.hate.mode or "normal", toHost(spec.hate, self)) end
	if spec.bb then for k, v in pairs(spec.bb) do brain:SetBb(k, toHost(v, self)) end end
	for _, kind in ipairs(sortedKeys(spec.behaviors)) do
		local params = spec.behaviors[kind]
		if params then self:add(kind, params) end
	end
	local hooks = {}
	for name in pairs(spec.hooks) do table.insert(hooks, name) end
	if #spec.rules > 0 then table.insert(hooks, "pick") end
	for pct in pairs(spec.onHp) do cs:WatchHp(pct) end
	if next(spec.onHp) then table.insert(hooks, "onHpCrossed") end
	-- Events the actor's own tasks may wait for.
	for _, n in ipairs({ "onDied", "onDamaged", "onEngaged", "onWaypointReached", "onSignal", "onTalked", "onItemGiven" }) do
		table.insert(hooks, n)
	end
	brain:SetHooks(hooks)
	brain.ThinkSeconds = spec.think or (spec.hooks.think and 1 or 0)
	self:callHook("onSpawned")
end

-- Runs a chained hook, most specific layer first; "stop" ends the chain.
function ActorObject:callHook(name, ...)
	local list = self.spec and self.spec.hooks[name]
	if not list then return nil end
	local result
	for _, fn in ipairs(list) do
		local args = { ... }
		local task = spawn(self, function() return fn(self, unpack(args)) end)
		local r = task.result and task.result[1]
		if r == "handled" then result = "handled" end
		if r == "stop" then break end
	end
	return result
end

function ActorObject:hasHook(name)
	return self.spec ~= nil and self.spec.hooks[name] ~= nil
end

-- Behaviors

function ActorObject:add(kind, params, id)
	params = params or {}
	local brain = self.cs.Brain
	if brain == nil then return nil end
	id = id or params.id or kind
	if HOST:IsStockBehavior(kind) then
		return brain:AddBehavior(kind, id, toHost(params, self))
	end
	local cls = Behavior.find(kind)
	if not cls then
		log("error", self.__name, "unknown behavior", kind)
		return nil
	end
	local b = cls.new()
	b.actor = self
	b.params = params
	b.__name = (self.__name or "") .. "/" .. kind
	local bid = register(b)
	self.__children = self.__children or {}
	table.insert(self.__children, b)
	brain:AddScriptBehavior(kind, id, bid, params.priority or cls.priority or 300, mask(cls.wants), toHost(params, self))
	if b.onAdd then safecall(b, "onAdd", b.onAdd, b) end
	return id
end

function ActorObject:remove(id) local b = self.cs.Brain if b then b:Remove(id, "removed") end end
function ActorObject:set(id, params) local b = self.cs.Brain if b then b:SetParams(id, toHost(params, self)) end end
function ActorObject:suspend(id) local b = self.cs.Brain if b then b:Suspend(id, true) end end
function ActorObject:resume(id) local b = self.cs.Brain if b then b:Suspend(id, false) end end
function ActorObject:has(id) local b = self.cs.Brain return b ~= nil and b:Has(id) end

-- opts: duration (or ['for']) seconds; stop (or ['until']) a function returning true to end it.
function ActorObject:push(kind, params, opts)
	opts = opts or {}
	local brain = self.cs.Brain
	if brain == nil then return nil end
	local stop = opts.stop or opts["until"]
	params = params or {}
	if not HOST:IsStockBehavior(kind) then
		local id = self:add(kind, params, params.id or (kind .. "#push"))
		if stop or opts.duration or opts["for"] then
			self:run(function()
				local secs = opts.duration or opts["for"]
				if stop then waitUntil(stop, secs) else wait(secs) end
				self:remove(id)
			end)
		end
		return id
	end
	return brain:PushBehavior(kind, toHost(params, self), opts.duration or opts["for"] or 0, stop and toHost({ fn = stop }, self) or nil)
end

-- Reads

function ActorObject:name() return self.cs:GetName() end
function ActorObject:hp() return self.cs:GetHP() end
function ActorObject:maxHp() return self.cs:GetMaxHP() end
function ActorObject:hpp() return self.cs:GetHPP() end
function ActorObject:mpp() return self.cs:GetMPP() end
function ActorObject:tp() return self.cs:GetTP() end
function ActorObject:level() return self.cs:GetLevel() end
function ActorObject:isAlive() return self.cs:IsAlive() end
function ActorObject:isDead() return self.cs:IsDead() end
function ActorObject:isEngaged() return self.cs:IsEngaged() end
function ActorObject:isPlayer() return self.cs:IsPlayer() end
function ActorObject:pos() return { x = self.cs.positionX, y = self.cs.positionY, z = self.cs.positionZ, rot = self.cs.rotation } end
function ActorObject:is(tag) return self.cs:HasTag(tag) end
function ActorObject:target() local t = self.cs.TargetChara return t and wrap(t) or nil end
function ActorObject:owner() local o = self.cs.ownerChara return o and wrap(o) or nil end
function ActorObject:encounter() local e = self.cs.content return e and e.ScriptId ~= 0 and object(e.ScriptId) or nil end
function ActorObject:hasStatus(id) return self.cs.statusEffects:HasStatusEffect(id) end
function ActorObject:faction() return HOST:FactionName(self.cs.factionId) end
function ActorObject:relation(other) return HOST:RelationBetween(self.cs, other.cs or other) end

function ActorObject:distance(other)
	local a = self.cs
	local x, y, z
	if type(other) == "table" and other.cs then other = other.cs end
	if type(other) == "table" then
		x, y, z = other.x or other[1], other.y or other[2], other.z or other[3]
	else
		x, y, z = other.positionX, other.positionY, other.positionZ
	end
	return math.sqrt((a.positionX - x) ^ 2 + (a.positionY - y) ^ 2 + (a.positionZ - z) ^ 2)
end

-- Acting

function ActorObject:use(action, target) local b = self.cs.Brain return b ~= nil and b:UseAction(action, (target or self:target() or self).cs, false) end
function ActorObject:useNow(action, target) local b = self.cs.Brain return b ~= nil and b:UseAction(action, (target or self:target() or self).cs, true) end
function ActorObject:engage(t) local b = self.cs.Brain self.cs.hateContainer:AddBaseHate(t.cs) if b then b:Engage(t.cs) end end
function ActorObject:disengage() local b = self.cs.Brain if b then b:Disengage() end end
function ActorObject:hate(t, amount) self.cs.hateContainer:UpdateHate(t.cs, amount or 1) end
function ActorObject:clearHate(t) self.cs.hateContainer:ClearHate(t and t.cs or nil) end
function ActorObject:fixate(t, seconds) self.cs.hateContainer:Fixate(t.cs, seconds or 0) end
function ActorObject:hateMode(mode, opts) self.cs.hateContainer:SetModeFrom(mode, toHost(opts or {}, self)) end
function ActorObject:command(order, target) local b = self.cs.Brain if b then b:GiveCommand(order, target and target.cs or nil) end end
function ActorObject:coax(player, n) local b = self.cs.Brain return b ~= nil and b:Coax(n or 1) end
function ActorObject:signal(name, data) self.cs.Brain:SetBb("lastSignal", name) end

function ActorObject:moveTo(p, pace)
	local cs = self.cs
	cs.aiContainer.mover:MoveTo(vec(p), pace == "walk" and 1 or 2, 0, 1.5, nil, false)
end
function ActorObject:moveAway(t, dist) self:push("Walk", { points = { awayPoint(self, t, dist or 10) }, pace = "run" }) end
function ActorObject:face(p)
	if type(p) == "number" then self.cs.rotation = p
	elseif type(p) == "table" and p.cs then self.cs:LookAt(p.cs)
	else self.cs:LookAt(vec(p)) end
end
-- x, y, z of { x, y, z }, { x = , y = , z = } or an actor.
function xyz(p)
	if type(p) == "table" and p.cs then return p.cs.positionX, p.cs.positionY, p.cs.positionZ end
	return p.x or p[1], p.y or p[2], p.z or p[3]
end

function ActorObject:warp(p)
	local v = vec(p)
	local x, y, z = xyz(p)
	if self.cs:IsPlayer() then self.cs:SetPos(x, y, z, p.rot or self.cs.rotation, true, nil)
	else self.cs.aiContainer.mover:Teleport(v, p.rot or self.cs.rotation) end
end
function ActorObject:stop() self.cs.aiContainer.mover:Stop() end
function ActorObject:animate(id) self.cs:PlayAnimation(id, false) end
function ActorObject:emote(id) self.cs:PlayAnimation(id, false) end

-- Shows a line from this actor's display name to the encounter's participants (or near players).
function ActorObject:say(textId, ...)
	local enc = self:encounter()
	local players = enc and enc.cs:ParticipantList() or HOST:PlayersNear(self.cs.CurrentArea, self.cs.positionX, self.cs.positionY, self.cs.positionZ, 40)
	for i = 0, players.Count - 1 do
		players[i]:SendGameMessage(GetWorldMaster(), textId, 0x20, ...)
	end
end

function ActorObject:setFaction(f) self.cs.factionId = HOST:DefineFaction(f) end
function ActorObject:tag(t) self.cs.tags:Add(t) end
function ActorObject:untag(t) self.cs.tags:Remove(t) end
function ActorObject:setHp(n) self.cs:SetHP(n) end
function ActorObject:setMaxHp(n) self.cs:SetMaxHP(n) self.cs:SetHP(n) end
function ActorObject:watchHp(pct) self.cs:WatchHp(pct) end

-- Points

function vec(p)
	if p == nil then return nil end
	if type(p) == "userdata" then return p end
	if p.cs then return p.cs:GetPosAsVector3() end
	return HOST:Vec(p.x or p[1], p.y or p[2], p.z or p[3])
end

function awayPoint(actor, threat, dist)
	local a, t = actor.cs, threat.cs or threat
	local dx, dz = a.positionX - t.positionX, a.positionZ - t.positionZ
	local len = math.sqrt(dx * dx + dz * dz)
	if len < 0.01 then dx, dz, len = 1, 0, 1 end
	return { a.positionX + dx / len * dist, a.positionY, a.positionZ + dz / len * dist }
end


function rt_actor_new(cs, kind)
	local o = setmetatable({ cs = cs, kind = kind }, ActorObject)
	return register(o)
end

function rt_actor_apply(id, extra, override)
	local o = object(id)
	if not o then return end
	if extra ~= nil then o.extra = extra end
	if override ~= nil then o.override = override end
	for _, t in pairs(o.__tasks) do t.dead = true end
	if o.__children then
		for _, c in ipairs(o.__children) do c:destroy() end
		o.__children = nil
	end
	o.__picks = {}
	safecall(o, "apply", o.apply, o)
end

function rt_actor_event(id, e)
	local o = object(id)
	if not o then return nil end
	local ev = eventTable(e)
	if ev.type == "Spawned" then return nil end
	local handled = dispatch(o, { type = ev.type, cs = e, actor = ev.actor, other = ev.other, amount = ev.amount, name = ev.name, data = ev.data, encounter = ev.encounter, actionId = ev.actionId, __noMethod = true })
	if ev.type == "HpCrossed" and ev.name == "down" and o.spec then
		local fns = o.spec.onHp[ev.amount]
		if fns then for _, fn in ipairs(fns) do spawn(o, function() fn(o, ev) end) end end
	end
	local r = o:callHook("on" .. ev.type, ev)
	return r or handled
end

function rt_actor_think(id)
	local o = object(id)
	if o then o:callHook("think") end
end

function rt_actor_describe(id)
	local o = object(id)
	if not o or not o.spec then return nil end
	return { layers = o.spec.layers, rules = #o.spec.rules }
end
