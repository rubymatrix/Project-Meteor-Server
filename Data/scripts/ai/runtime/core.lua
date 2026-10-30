--[[
The AI and content runtime, loaded once by the map server (Scripting/ScriptRuntime.cs). It keeps
every script object by id (profiles, behaviors, content, campaigns, zone scripts), their tasks and
callbacks. The rt_* functions are what C# calls. See Data/Docs/AI-and-Content.md.
--]]

R = _G
HOST = nil
NOW = 0

CHANNELS = { Move = 1, Face = 2, Target = 4, Act = 8, Sense = 16, Speak = 32 }

local objects = {}
local nextId = 0
local callbacks = {}
local nextCb = 0
local MAX_FAULTS = 3
local FAULT_WINDOW = 60000

local lastError

function log(level, ...)
    local parts = {}
    for i = 1, select('#', ...) do parts[i] = tostring((select(i, ...))) end
    if level == 'error' then lastError = table.concat(parts, ' ') end
    if HOST then HOST:Log(level, table.concat(parts, ' ')) else print(...) end
end

-- Classes --------------------------------------------------------------------------------------

function class(base)
    local c = {}
    c.__index = c
    c.__base = base
    if base then setmetatable(c, { __index = base }) end
    c.new = function(...)
        local o = setmetatable({}, c)
        if o.init then o:init(...) end
        return o
    end
    c.extend = function() return class(c) end
    return c
end

-- Module loader ----------------------------------------------------------------------------------

local modules = {}

local function readFile(path)
    local f = io.open(path, 'rb')
    if not f then return nil end
    local text = f:read('*a')
    f:close()
    return text
end

local function patch(old, new)
    if type(old) ~= 'table' or type(new) ~= 'table' then return new end
    for k, v in pairs(new) do old[k] = v end
    return old
end

-- name: "ai/kinds/battlenpc" (no extension). Returns the module's value, or nil when missing.
function use(name)
    local path = HOST.Root .. '/' .. name:gsub('%.lua$', '') .. '.lua'
    local stamp = HOST:Stamp(path)
    local m = modules[name]
    if stamp == nil then
        if m then modules[name] = nil end
        return nil
    end
    if m and m.stamp == stamp then return m.value end
    local text = readFile(path)
    if not text then return nil end
    local f, err = loadstring(text, '@' .. path)
    if not f then
        log('error', err)
        return m and m.value or nil
    end
    local env = setmetatable({}, { __index = R })
    env.require = use
    env._MODULE = name
    setfenv(f, env)
    local ok, value = xpcall(f, debug.traceback)
    if not ok then
        log('error', value)
        return m and m.value or nil
    end
    if value == nil then value = env end
    if m then value = patch(m.value, value) end
    modules[name] = { stamp = stamp, value = value }
    return value
end

-- Loads a module fresh and returns its error, or nil (tests).
function rt_check(name)
    local path = HOST.Root .. '/' .. name .. '.lua'
    local text = readFile(path)
    if not text then return 'missing ' .. path end
    local f, err = loadstring(text, '@' .. path)
    if not f then return err end
    local env = setmetatable({}, { __index = R })
    env.require = use
    setfenv(f, env)
    local ok, e = xpcall(f, debug.traceback)
    return (not ok) and e or nil
end

function exists(name)
    return HOST:Stamp(HOST.Root .. '/' .. name .. '.lua') ~= nil
end

-- Objects ----------------------------------------------------------------------------------------

Object = class()

function Object:init() end

function register(obj)
    nextId = nextId + 1
    obj.__id = nextId
    obj.__tasks = {}
    obj.__cbs = {}
    obj.__faults = {}
    objects[nextId] = obj
    return nextId
end

function object(id) return objects[id] end

function Object:id() return self.__id end

function Object:destroy()
    if not self.__id then return end
    for _, t in pairs(self.__tasks) do t.dead = true end
    for id in pairs(self.__cbs) do callbacks[id] = nil end
    if self.__children then
        for _, child in ipairs(self.__children) do child:destroy() end
    end
    if self.onDestroy then pcall(self.onDestroy, self) end
    objects[self.__id] = nil
    self.__id = nil
end

-- Counts a fault; three within a minute switch the named hook off on this object.
local function fault(obj, name, err)
    log('error', (obj.__name or '?') .. '.' .. tostring(name) .. ': ' .. tostring(err))
    if not obj.__faults then return end
    local f = obj.__faults[name] or {}
    obj.__faults[name] = f
    table.insert(f, NOW)
    while #f > 0 and NOW - f[1] > FAULT_WINDOW do table.remove(f, 1) end
    if #f >= MAX_FAULTS then
        obj.__disabled = obj.__disabled or {}
        obj.__disabled[name] = true
        log('warn', (obj.__name or '?') .. '.' .. tostring(name) .. ' disabled after ' .. MAX_FAULTS .. ' errors')
    end
end

function safecall(obj, name, fn, ...)
    if obj and obj.__disabled and obj.__disabled[name] then return nil end
    local r = { xpcall(fn, debug.traceback, ...) }
    if not r[1] then
        fault(obj, name, r[2])
        return nil
    end
    return unpack(r, 2, table.maxn(r))
end

-- Callbacks C# can call: a Lua function handed to C# becomes { __cb = id }.
function callback(owner, fn)
    nextCb = nextCb + 1
    callbacks[nextCb] = { fn = fn, owner = owner }
    if owner and owner.__cbs then owner.__cbs[nextCb] = true end
    return { __cb = nextCb }
end

-- Copies a table for C#: functions become callbacks owned by owner, script objects become
-- the C# object they wrap.
function toHost(v, owner, depth)
    depth = depth or 0
    local t = type(v)
    if t == 'function' then return callback(owner, v) end
    if t ~= 'table' then return v end
    if v.cs ~= nil and getmetatable(v) ~= nil then return v.cs end
    if depth > 12 then return nil end
    if getmetatable(v) and getmetatable(v).__host then return getmetatable(v).__host(v) end
    local out = {}
    for k, x in pairs(v) do out[k] = toHost(x, owner, depth + 1) end
    return out
end

function rt_invoke(id, ...)
    local cb = callbacks[id]
    if not cb then return nil end
    return safecall(cb.owner, 'callback', cb.fn, ...)
end

-- Tasks ------------------------------------------------------------------------------------------

local running = {}      -- coroutine -> task
local allTasks = {}

local function finishTask(task, ok, ...)
    if not ok then
        task.dead = true
        fault(task.owner, 'task', debug.traceback(task.co, tostring((...))))
        return false
    end
    if coroutine.status(task.co) == 'dead' then
        task.dead = true
        task.result = { ... }
        return true
    end
    local req = ...
    task.wakeAt, task.pred, task.event, task.filter, task.timeoutAt = nil, nil, nil, nil, nil
    if type(req) == 'table' then
        if req.wait then task.wakeAt = NOW + req.wait * 1000 end
        if req.pred then task.pred = req.pred end
        if req.event then task.event = req.event; task.filter = req.filter end
        if req.timeout then task.timeoutAt = NOW + req.timeout * 1000 end
    end
    return true
end

local function resume(task, ...)
    running[task.co] = task
    local r = { coroutine.resume(task.co, ...) }
    running[task.co] = nil
    return finishTask(task, unpack(r, 1, table.maxn(r)))
end

-- Starts fn as a task of owner and runs it to its first wait. Returns the task; task.result
-- holds the return values if it ended at once.
function spawn(owner, fn, ...)
    local task = { co = coroutine.create(fn), owner = owner, scope = owner.__scope }
    owner.__tasks[task] = task
    table.insert(allTasks, task)
    resume(task, ...)
    return task
end

local Handle = class()
function Handle:cancel() self.task.dead = true end
function Handle:done() return self.task.dead == true end

function Object:run(fn, ...)
    if not self.__id then return nil end
    local task = spawn(self, fn, ...)
    local h = Handle.new()
    h.task = task
    return h
end

function Object:after(seconds, fn)
    return self:run(function() wait(seconds); fn(self) end)
end

function Object:every(seconds, fn)
    return self:run(function()
        while true do
            wait(type(seconds) == 'function' and seconds() or seconds)
            if fn(self) == false then return end
        end
    end)
end

local function current()
    local co = coroutine.running()
    local task = co and running[co]
    if not task then error('wait() outside a task: start it with self:run(fn)', 3) end
    return task
end

function wait(seconds)
    current()
    coroutine.yield({ wait = seconds or 0 })
end

function waitUntil(pred, timeout)
    current()
    if pred() then return true end
    return coroutine.yield({ pred = pred, timeout = timeout }) == true
end

function waitEvent(name, filter, timeout)
    current()
    return coroutine.yield({ event = name, filter = filter, timeout = timeout })
end

function waitAll(...)
    local handles = { ... }
    return waitUntil(function()
        for _, h in ipairs(handles) do if not h:done() then return false end end
        return true
    end)
end

function waitAny(...)
    local handles = { ... }
    return waitUntil(function()
        for _, h in ipairs(handles) do if h:done() then return true end end
        return false
    end)
end

-- Kills the tasks an owner started inside a scope (a phase).
function cancelScope(owner, scope)
    for _, t in pairs(owner.__tasks) do
        if t.scope == scope then t.dead = true end
    end
end

function rt_tick(now)
    NOW = now
    local list = allTasks
    allTasks = {}
    for _, task in ipairs(list) do
        if not task.dead and task.owner.__id then
            if task.wakeAt and NOW >= task.wakeAt then
                resume(task)
            elseif task.pred then
                local ok, v = pcall(task.pred)
                if not ok then
                    task.dead = true
                    fault(task.owner, 'waitUntil', v)
                elseif v then
                    resume(task, true)
                elseif task.timeoutAt and NOW >= task.timeoutAt then
                    resume(task, false)
                end
            elseif task.event and task.timeoutAt and NOW >= task.timeoutAt then
                resume(task, nil)
            end
        end
        if not task.dead and task.owner.__id then
            table.insert(allTasks, task)
        elseif task.owner.__tasks then
            task.owner.__tasks[task] = nil
        end
    end
end

-- Events -----------------------------------------------------------------------------------------

local function matches(filter, ev)
    if not filter then return true end
    for k, want in pairs(filter) do
        local have = ev[k]
        if type(have) == 'table' and have.cs ~= nil then have = have.cs end
        if type(want) == 'table' and want.cs ~= nil then want = want.cs end
        if type(want) == 'function' then
            if not want(have, ev) then return false end
        elseif k == 'group' then
            if not (ev.actor and ev.encounter and ev.encounter:inGroup(ev.actor, want)) then return false end
        elseif have ~= want then
            return false
        end
    end
    return true
end
R.eventMatches = matches

-- A Lua table for a C# ActorEvent.
function eventTable(e)
    local ev = {
        cs = e,
        type = e.TypeName,
        actor = e.Actor and wrap(e.Actor) or nil,
        other = e.Other and wrap(e.Other) or nil,
        amount = e.Amount,
        actionId = e.ActionId,
        name = e.Name,
        data = e.Data,
    }
    if e.Encounter and e.Encounter.ScriptId ~= 0 then ev.encounter = objects[e.Encounter.ScriptId] end
    if not ev.encounter and e.Actor and e.Actor.content and e.Actor.content.ScriptId ~= 0 then
        ev.encounter = objects[e.Actor.content.ScriptId]
    end
    return ev
end

-- Wakes tasks of obj waiting for this event, then runs obj's on<Type> method and its triggers.
-- Returns "handled" when a handler did.
function dispatch(obj, ev)
    for _, t in pairs(obj.__tasks) do
        if not t.dead and t.event == ev.type and matches(t.filter, ev) then
            resume(t, ev)
        end
    end
    local handled
    local fn = obj['on' .. ev.type]
    if type(fn) == 'function' then
        local task = spawn(obj, function() return fn(obj, ev) end)
        if task.result and task.result[1] == 'handled' then handled = 'handled' end
    end
    if obj.__triggers then
        for _, trig in ipairs(obj.__triggers) do
            if not trig.dead and trig.event == ev.type and matches(trig.filter, ev) then
                if trig.once then trig.dead = true end
                local task = spawn(obj, function() return trig.fn(obj, ev) end)
                task.scope = trig.scope
                if task.result and task.result[1] == 'handled' then handled = 'handled' end
            end
        end
    end
    return handled
end

-- Proxies for C# characters --------------------------------------------------------------------

local proxies = setmetatable({}, { __mode = 'v' })

-- The script object for a C# character: its profile object when it has one, else a plain
-- proxy with the same methods.
function wrap(cs)
    if cs == nil then return nil end
    if type(cs) == 'table' then return cs end
    local ok, brain = pcall(function() return cs.Brain end)
    if ok and brain ~= nil and brain.ScriptId ~= 0 then
        local o = objects[brain.ScriptId]
        if o then return o end
    end
    local id = cs.Id
    local p = proxies[id]
    if p and p.cs == cs then return p end
    p = setmetatable({ cs = cs }, ActorObject)
    proxies[id] = p
    return p
end

require('ai/runtime/json')
require('ai/actions')
require('ai/moves')
require('ai/runtime/actor')
require('ai/runtime/picker')
require('ai/runtime/behavior')
require('ai/runtime/content')

function rt_init(host)
    HOST = host
    NOW = host.NowMs
end

-- After the world is loaded: factions and anything else the data defines.
function rt_ready()
    use('ai/factions')
end

function rt_last_error() return lastError end

-- Calls an rt_* function, keeping its error for rt_last_error (tests).
function rt_try(name, ...)
    local r = { xpcall(R[name], debug.traceback, ...) }
    if not r[1] then
        lastError = r[2]
        return nil
    end
    return unpack(r, 2, table.maxn(r))
end

-- Calls a method on a script object (tests and the admin API).
function rt_call(id, method, ...)
    local o = objects[id]
    if not o or type(o[method]) ~= 'function' then return nil end
    return safecall(o, method, o[method], o, ...)
end

function rt_destroy(id)
    local o = objects[id]
    if o then o:destroy() end
end

function rt_describe_object(id)
    local o = objects[id]
    if not o then return nil end
    local tasks = 0
    for _, t in pairs(o.__tasks) do if not t.dead then tasks = tasks + 1 end end
    return { name = o.__name, tasks = tasks }
end
