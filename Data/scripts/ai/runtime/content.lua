--[[
Content: encounters, content areas, world events, campaigns and zone scripts. C# owns the actors,
time and outcome (Map Server/Content/Encounter.cs); this side owns phases, tasks and triggers.
Naming and the full API: Data/Docs/AI-and-Content.md.
--]]

ContentBase = class(Object)

local function defineContent(scope, name)
    local cls = class(ContentBase)
    cls.__content = true
    cls.scope = scope
    cls.name = name
    cls.__variants = {}
    return cls
end

Encounter = { define = function(name) return defineContent('Encounter', name) end }
ContentArea = { define = function(name) return defineContent('ContentArea', name) end }
WorldEvent = { define = function(name) return defineContent('World', name) end }

function ContentBase.variant(cls, name, cfg)
    cls.__variants[name] = cfg or {}
    return cls
end

-- A copy of a content class whose default variant is name: lets each client director
-- (InstanceRaidLesserIfrit, InstanceRaidNormalIfrit, ...) be its own file over one module.
function ContentBase.as(cls, name)
    local sub = setmetatable({}, { __index = cls })
    for k, v in pairs(cls) do sub[k] = v end
    sub.__index = sub
    sub.__variants = setmetatable({ default = cls.__variants[name] }, { __index = cls.__variants })
    sub.directorVariant = name
    return sub
end

-- Factions ----------------------------------------------------------------------------------------

Faction = {}
function Faction.define(name) return HOST:DefineFaction(name) end
function Faction.relate(a, b, relation)
    if type(b) == 'table' then
        for _, x in ipairs(b) do HOST:Relate(a, x, relation) end
    else
        HOST:Relate(a, b, relation)
    end
end

-- Routes ------------------------------------------------------------------------------------------

Route = {}
local RouteMeta = { __index = Route, __host = function(r) return { points = r.raw } end }

-- routes/<name>.lua returns { points = { { x, y, z, name = , tag = , wait = }, ... } }
function Route.load(name)
    local t = use('routes/' .. name)
    if not t then
        log('error', 'route not found: ' .. name)
        t = { points = {} }
    end
    return Route.from(t.points or t)
end

function Route.from(points)
    return setmetatable({ raw = points }, RouteMeta)
end

function Route:count() return #self.raw end
function Route:last() return self.raw[#self.raw] end

-- The first point, or a point offset back along the first leg (to line actors up behind it).
function Route:start(offsetBack)
    local a, b = self.raw[1], self.raw[2]
    if not offsetBack or offsetBack == 0 or not b then return a end
    local dx, dz = b[1] - a[1], b[3] - a[3]
    local len = math.sqrt(dx * dx + dz * dz)
    if len < 0.01 then return a end
    return { a[1] + dx / len * offsetBack, a[2], a[3] + dz / len * offsetBack }
end

function Route:point(name)
    for _, p in ipairs(self.raw) do if p.name == name then return p end end
end

function Route:points(tag)
    local out = {}
    for _, p in ipairs(self.raw) do if tag == nil or p.tag == tag then table.insert(out, p) end end
    return out
end

-- Objectives --------------------------------------------------------------------------------------

Objective = {}
local function groupName(g) return type(g) == 'table' and g.name or g end
function Objective.kill(group) return { kind = 'kill', group = groupName(group) } end
function Objective.protect(group, min) return { kind = 'protect', group = groupName(group), min = min or 1 } end
function Objective.reach(group, point, min, radius) return { kind = 'reach', group = groupName(group), point = point, min = min or 1, radius = radius or 3 } end
function Objective.survive(seconds) return { kind = 'survive', seconds = seconds } end
function Objective.hold(region, seconds) return { kind = 'hold', region = region, seconds = seconds } end
function Objective.count(counter, n) return { kind = 'count', counter = counter, n = n } end
function Objective.custom(fn) return { kind = 'custom', fn = fn } end

-- Groups ------------------------------------------------------------------------------------------

Group = class()

function Group:list()
    local out = {}
    local l = self.enc.cs:Group(self.name)
    for i = 0, l.Count - 1 do table.insert(out, wrap(l[i])) end
    return out
end

function Group:alive() return self.enc.cs:GroupAlive(self.name) end
function Group:count() return #self:list() end
function Group:first() return self:list()[1] end
function Group:each(fn) for _, a in ipairs(self:list()) do fn(a) end end
function Group:add(kind, params) self:each(function(a) if a:isAlive() then a:add(kind, params) end end) end
function Group:push(kind, params, opts) self:each(function(a) if a:isAlive() then a:push(kind, params, opts) end end) end
function Group:set(id, params) self:each(function(a) a:set(id, params) end) end
function Group:remove(id) self:each(function(a) a:remove(id) end) end
function Group:nearest(p)
    local best, bd
    for _, a in ipairs(self:list()) do
        if a:isAlive() then
            local d = a:distance(p)
            if bd == nil or d < bd then best, bd = a, d end
        end
    end
    return best
end

-- Encounter objects --------------------------------------------------------------------------------

local function copy(t)
    local out = {}
    for k, v in pairs(t or {}) do out[k] = v end
    return out
end

function ContentBase:spawn(group, spec)
    spec = copy(spec)
    local profile, override = spec.profile, spec.override
    spec.profile, spec.override = nil, nil
    spec.group = spec.group or group
    if type(spec.at) == 'table' and spec.at.cs then spec.at = spec.at:pos() end
    local npc = self.cs:SpawnActor(toHost(spec, self))
    if npc == nil then
        log('error', self.__name .. ': spawn failed for pool ' .. tostring(spec.pool))
        return nil
    end
    npc:AttachBrain(profile, override)
    return wrap(npc)
end

-- specs: a list of spawn specs; opts fill in what they leave out. Returns the group.
function ContentBase:spawnGroup(specs, opts)
    opts = opts or {}
    local name = opts.group or specs.group or ('group' .. tostring(NOW))
    for _, s in ipairs(specs) do
        local spec = copy(opts)
        for k, v in pairs(s) do spec[k] = v end
        spec.group = nil
        local groups = { name }
        if s.group and s.group ~= name then table.insert(groups, s.group) end
        spec.group = groups
        self:spawn(name, spec)
    end
    return self:group(name)
end

function ContentBase:group(name)
    return setmetatable({ enc = self, name = name }, Group)
end

function ContentBase:inGroup(actor, name)
    local cs = actor.cs or actor
    local l = self.cs:Group(name)
    for i = 0, l.Count - 1 do if l[i] == cs then return true end end
    return false
end

function ContentBase:despawn(actor) self.cs:DespawnActor(actor.cs, true) end
function ContentBase:adopt(actor, group) self.cs:Adopt(actor.cs, group) end
function ContentBase:keep(actor, value) self.cs:Keep(actor.cs, value ~= false) end
function ContentBase:partyAllies(group) self.cs:SetPartyAllies(groupName(group)) end
function ContentBase:relate(a, b, relation) self.cs:SetRelation(a, b, relation) end

-- Phases

function ContentBase:goto(name)
    local old = self.__phase
    if old then
        cancelScope(self, old)
        for _, t in ipairs(self.__triggers) do if t.scope == old then t.dead = true end end
        local exit = self['phaseExit_' .. old]
        if exit then safecall(self, 'phaseExit_' .. old, exit, self) end
    end
    self.__phase = name
    self.__scope = name
    self.cs:SetPhase(name)
    local enter = self['phase_' .. name]
    if enter then self:run(function() enter(self) end) end
end

function ContentBase:phaseName() return self.__phase end

-- Triggers

function ContentBase:on(event, filter, fn, once)
    if type(filter) == 'function' then filter, fn = nil, filter end
    filter = filter and copy(filter) or nil
    if filter and filter.allDead then
        local g = groupName(filter.group)
        filter.allDead, filter.group = nil, nil
        filter.actor = function(actor) return actor ~= nil and self:inGroup(actor, g) and self.cs:GroupAlive(g) == 0 end
    elseif filter and filter.group then
        filter.group = groupName(filter.group)
    end
    local trig = { event = event, filter = filter, fn = fn, scope = self.__scope, once = once }
    table.insert(self.__triggers, trig)
    return trig
end

function ContentBase:once(event, filter, fn) return self:on(event, filter, fn, true) end

function ContentBase:onHp(actor, pct, fn)
    actor:watchHp(pct)
    return self:on('HpCrossed', { actor = actor, amount = pct, name = 'down' }, fn, true)
end

function ContentBase:onRegion(name, fn, once)
    return self:on('EnteredRegion', { name = name }, fn, once ~= false)
end

-- Outcome

local roles = { wins = 'Wins', required = 'Required', fails = 'Fails', score = 'Score' }

function ContentBase:objective(name, obj, opts)
    local role
    if type(opts) == 'string' then role = roles[opts] or opts
    elseif type(opts) == 'table' then
        for k, r in pairs(roles) do if opts[k] then role = r end end
    end
    obj = copy(obj)
    if obj.fn then
        local fn = obj.fn
        obj.fn = function() return fn(self) end
    end
    self.cs:AddObjective(name, obj.kind, toHost(obj, self), role)
end

function ContentBase:win(reason) self.cs:Win(reason or 'script') end
function ContentBase:fail(reason) self.cs:Fail(reason or 'script') end
function ContentBase:isRunning() return self.cs.IsRunning end

-- Arena

function ContentBase:arena(def) self.cs:SetArena(toHost(def, self)) end
function ContentBase:region(name, shape) self.cs:AddRegion(name, toHost(shape, self)) end

function ContentBase:door(name)
    local enc = self
    return {
        open = function() enc.cs:SetDoor(name, true) end,
        close = function() enc.cs:SetDoor(name, false) end,
        isOpen = function() return enc.cs:IsDoorOpen(name) end,
    }
end

-- def: circle/cone/line/donut/poly shape, delay, damage, percent, animation, command,
-- hits ("foes", "all", "players"), source, onResolve(hits), name, linger.
function ContentBase:hazard(def)
    def = copy(def)
    local onResolve = def.onResolve
    if onResolve then
        def.onResolve = function(...)
            local hits = {}
            for _, c in ipairs({ ... }) do table.insert(hits, wrap(c)) end
            onResolve(hits)
        end
    end
    local source = def.source
    if type(source) == 'table' then source = source.cs end
    def.source = nil
    return self.cs:AddHazard(toHost(def, self), source)
end

function ContentBase:clearHazard(id) self.cs:ClearHazard(id) end

-- Players

function ContentBase:participants()
    local out = {}
    local l = self.cs:ParticipantList()
    for i = 0, l.Count - 1 do table.insert(out, wrap(l[i])) end
    return out
end

function ContentBase:addParticipant(p) self.cs:AddParticipant(p.cs or p) end

function ContentBase:pick(n, filter)
    local list = {}
    for _, p in ipairs(self:participants()) do
        if p:isAlive() and (filter == nil or filter(p)) then table.insert(list, p) end
    end
    self:shuffle(list)
    local out = {}
    for i = 1, math.min(n or 1, #list) do out[i] = list[i] end
    return out
end

function ContentBase:broadcast(textId, ...) self.cs:Broadcast(textId, ...) end
function ContentBase:music(id) self.cs:Music(id) end

-- Sends a line from a text sheet owner (a quest or the world master) to each participant.
function ContentBase:tell(owner, textId, ...)
    for _, p in ipairs(self:participants()) do
        p.cs:SendGameMessage(owner or GetWorldMaster(), textId, 0x20, ...)
    end
end

function ContentBase:warp(actor, point)
    actor = actor.cs or actor
    local x, y, z = xyz(point)
    if actor:IsPlayer() and actor.CurrentArea ~= self.cs.Area then
        GetWorldManager():DoZoneChangeContent(actor, self.cs.Area, x, y, z, point.rot or point[4] or 0, 16)
    else
        wrap(actor):warp(point)
    end
end

-- Scores

function ContentBase:score(player, key, n) self.cs:AddScore(player.cs or player, key, n or 1) end
function ContentBase:scoreOf(player, key) return self.cs:Score(player.cs or player, key) end
function ContentBase:counter(name, n) return self.cs:AddCounter(name, n or 0) end
function ContentBase:contribution(player) return self.cs:Contribution(player.cs or player) end
function ContentBase:contributionRule(t) self.cs:SetContributionRule(toHost(t, self)) end

-- Randomness, from the encounter's seeded generator

function ContentBase:roll(a, b)
    if type(a) == 'table' then a, b = a[1], a[2] end
    if b == nil then return a end
    return self.cs.Rng:Range(a, b)
end
function ContentBase:int(a, b) return self.cs.Rng:Int(a, b) end
function ContentBase:chance(p) return self.cs.Rng:Chance(p) end
function ContentBase:shuffle(list)
    for i = #list, 2, -1 do
        local j = self.cs.Rng:Int(1, i)
        list[i], list[j] = list[j], list[i]
    end
    return list
end

-- Time

function ContentBase:timeLimit(s) self.cs:SetTimeLimit(s) end
function ContentBase:elapsed() return self.cs:Elapsed() end
function ContentBase:remaining() return self.cs:Remaining() end

-- Nesting and signals

function ContentBase:child(name, variant, opts)
    return Content.launch(name, variant, self.cs.Area, nil, opts, self)
end

function ContentBase:signal(name, data)
    HOST:Signal(self.cs, nil, name, data)
end

-- Launching -----------------------------------------------------------------------------------------

Content = {}

local folders

function Content.find(name)
    if not folders then
        folders = {}
        local dirs = HOST:ListDirs('content')
        for i = 0, dirs.Count - 1 do table.insert(folders, dirs[i]) end
    end
    local paths = { name, 'encounters/' .. name .. '/init', 'encounters/' .. name }
    for _, f in ipairs(folders) do table.insert(paths, f .. '/' .. name) end
    for _, path in ipairs(paths) do
        if exists(path) then
            local def = use(path)
            if type(def) == 'table' and def.__content then return def end
        end
    end
    return nil
end

local function hookNames(obj)
    local names = { '*' }
    return names
end

function Content.launch(name, variant, area, starter, opts, parent)
    local def = Content.find(name)
    if not def then
        log('error', 'no content named ' .. tostring(name))
        return nil
    end
    opts = opts or {}
    variant = variant or ''
    local director = opts.director
    local created = false
    if def.scope == 'ContentArea' and def.area and area == nil and starter ~= nil then
        local zone = GetWorldManager():GetZone(def.area.zone)
        local ca = zone and zone:CreateContentArea(starter, def.area.classPath or '/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent',
            def.area.name, def.area.script or def.area.name, def.area.director or 'Quest/QuestDirectorMan0g001')
        if ca == nil then
            log('error', name .. ': could not create its content area')
            return nil
        end
        area = ca
        director = director or ca:GetContentDirector()
        created = true
    end
    area = area or (starter and starter.CurrentArea)
    if area == nil then
        log('error', name .. ': no area')
        return nil
    end
    if variant == '' and def.directorVariant then variant = def.directorVariant end
    local cfg = def.__variants[variant] or def.__variants.default or {}
    local cs = HOST:NewEncounter(name, variant, area, def.scope, opts['seed'] or 0)
    local obj = setmetatable({ cs = cs, cfg = cfg, opts = opts, def = def, __triggers = {} }, def)
    obj.__name = name .. (variant ~= '' and (':' .. variant) or '')
    cs.ScriptId = register(obj)
    cs:SetHooks(hookNames(obj))
    if director then cs.Director = director end
    if parent then parent.cs:AddChild(cs) end
    if starter then cs:AddParticipant(starter) end
    if opts.participants then
        for _, p in ipairs(opts.participants) do cs:AddParticipant(p.cs or p) end
    end
    if obj.setup then
        local ok = safecall(obj, 'setup', obj.setup, obj, opts)
        if ok == nil and obj.__disabled then
            cs:Close()
            return nil
        end
    end
    cs:SetReady()
    if created and starter then
        starter:AddDirector(director)
        director:StartDirector(false)
        starter:SetLoginDirector(director)
        if def.entry then
            GetWorldManager():DoZoneChangeContent(starter, area, def.entry[1], def.entry[2], def.entry[3], def.entry[4] or 0, 16)
        end
    end
    if opts.start ~= false then cs:Start() end
    return cs
end

function rt_content_launch(name, variant, area, starter, opts)
    return Content.launch(name, variant, area, starter, opts)
end

function rt_content_start(id)
    local o = object(id)
    if not o then return end
    if o.onStart then o:run(function() o:onStart() end) end
    if o.def and o.def.firstPhase and not o.__phase then o:goto(o.def.firstPhase) end
end

function rt_content_end(id, result, reason)
    local o = object(id)
    if not o then return end
    for _, t in pairs(o.__tasks) do t.dead = true end
    for _, t in ipairs(o.__triggers or {}) do t.dead = true end
    o.__scope = nil
    if o.onEnd then o:run(function() o:onEnd(result, reason) end) end
end

function rt_content_goto(id, name)
    local o = object(id)
    if o then o:goto(name) end
end

function rt_content_event(id, e)
    local o = object(id)
    if not o then return nil end
    return dispatch(o, eventTable(e))
end

function rt_content_join(id, p)
    local o = object(id)
    if o and o.onJoin then o:run(function() o:onJoin(wrap(p)) end) end
end

function rt_content_leave(id, p)
    local o = object(id)
    if o and o.onLeave then o:run(function() o:onLeave(wrap(p)) end) end
end

function rt_content_describe(id)
    local o = object(id)
    if not o then return nil end
    local waiting = {}
    for _, t in pairs(o.__tasks) do
        if not t.dead then
            if t.wakeAt then table.insert(waiting, string.format('wait %.1fs', (t.wakeAt - NOW) / 1000))
            elseif t.event then table.insert(waiting, 'event ' .. t.event)
            elseif t.pred then table.insert(waiting, 'until')
            else table.insert(waiting, 'running') end
        end
    end
    local triggers = 0
    for _, t in ipairs(o.__triggers or {}) do if not t.dead then triggers = triggers + 1 end end
    return json.encode({ phase = o.__phase, tasks = waiting, triggers = triggers, saved = o.saved })
end

-- Campaigns ---------------------------------------------------------------------------------------
--[[
Long-lived content that survives restarts (content/campaigns/<name>.lua). self.saved is
written to the database by self:save(). cycle({ { "supply", hours }, { "combat", hours } })
moves through stages on wall time and calls self:on<Stage>Stage() when one starts.
--]]

CampaignBase = class(Object)
Campaign = {}
local campaigns = {}

function Campaign.define(name)
    local cls = class(CampaignBase)
    cls.name = name
    cls.__campaign = true
    return cls
end

function Campaign.get(name)
    local id = campaigns[name]
    return id and object(id) or nil
end

function CampaignBase:save()
    HOST:SaveState('campaign:' .. self.def.name, json.encode(self.saved))
end

function CampaignBase:stage() return self.saved.stage end

function CampaignBase:cycle(stages, checkSeconds)
    self.__stages = stages
    local function total()
        local t = 0
        for _, s in ipairs(stages) do t = t + s[2] * 3600 end
        return t
    end
    local function update()
        local now = os.time()
        self.saved.cycleStart = self.saved.cycleStart or now
        local into = (now - self.saved.cycleStart) % total()
        local name
        for _, s in ipairs(stages) do
            if into < s[2] * 3600 then name = s[1]; break end
            into = into - s[2] * 3600
        end
        if name ~= self.saved.stage then
            self.saved.stage = name
            self:save()
            local fn = self['on' .. name:sub(1, 1):upper() .. name:sub(2) .. 'Stage']
            if fn then self:run(function() fn(self) end) end
        end
    end
    update()
    self:every(checkSeconds or 30, update)
end

-- Skips to the start of a stage (dev and tests).
function CampaignBase:forceStage(name)
    local now = os.time()
    local offset = 0
    for _, s in ipairs(self.__stages or {}) do
        if s[1] == name then break end
        offset = offset + s[2] * 3600
    end
    self.saved.cycleStart = now - offset
    self.saved.stage = nil
    self:save()
end

function rt_campaigns_start()
    local list = HOST:ListScripts('content/campaigns')
    local ids = {}
    for i = 0, list.Count - 1 do
        local def = use(list[i])
        if type(def) == 'table' and def.__campaign then
            local o = setmetatable({ def = def, saved = json.decode(HOST:LoadState('campaign:' .. def.name)) or {} }, def)
            o.__name = 'campaign:' .. def.name
            local id = register(o)
            campaigns[def.name] = id
            ids[def.name] = id
            if o.start then o:run(function() o:start() end) end
        end
    end
    return ids
end

-- Zone scripts -------------------------------------------------------------------------------------
--[[
content/zones/<zoneName>.lua: gets every event in the zone nobody handled, and onLoad(area).
--]]

ZoneScriptBase = class(Object)
Zone = {}

function Zone.define(name)
    local cls = class(ZoneScriptBase)
    cls.name = name
    return cls
end

function rt_zone_load(area)
    local path = 'content/zones/' .. area.ZoneName
    if not exists(path) then return 0 end
    local def = use(path)
    if type(def) ~= 'table' then return 0 end
    local o = setmetatable({ area = area, def = def, __triggers = {} }, def)
    o.__name = 'zone:' .. area.ZoneName
    local id = register(o)
    if o.onLoad then o:run(function() o:onLoad(area) end) end
    return id
end
