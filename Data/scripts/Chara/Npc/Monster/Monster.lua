require("Global")
require("Battle/Parts")

--[[
Shared class script for every monster class without its own (LuaEngine falls back to it). Binds the
actor as a monster, with the target parts its family has.
--]]

-- The engine calls init(player, npc) when a player is binding the actor, else init(npc).
function init(a, b)
	return parts.initParams(b or a)
end
