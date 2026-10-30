--[[
Behaviors written in Lua (Ai/Behaviors/<Name>.lua): Behavior.define(name, { priority, wants }).
think(granted) runs every params.think seconds and may return the channels it wants next.
--]]

Behavior = {}
local defined = {}

function Behavior.define(name, opts)
	local cls = class(Object)
	opts = opts or {}
	cls.kind = name
	cls.priority = opts.priority or 300
	cls.wants = opts.wants or { "Move" }
	defined[name] = cls
	return cls
end

function Behavior.find(name)
	return defined[name] or use("Ai/Behaviors/" .. name)
end

local function grantedSet(mask)
	local set = {}
	for name, bit in pairs(CHANNELS) do
		if math.floor(mask / bit) % 2 == 1 then set[name] = true end
	end
	return set
end

function rt_behavior_think(id, granted)
	local b = object(id)
	if not b or not b.think then return nil end
	local task = spawn(b, function() return b:think(grantedSet(granted)) end)
	local r = task.result and task.result[1]
	if r == false then return false end
	if type(r) == "table" then return channelMask(r) end
	return nil
end

function rt_behavior_event(id, e)
	local b = object(id)
	if not b then return nil end
	if b["on" .. e.TypeName] then return dispatch(b, eventTable(e)) end
	return nil
end
