require("Global")
require("Guildleve")

--[[
Battle leve director shared by every PrivateGLBattle* script. The leve itself runs in
GuildleveDirector.cs: spawns from the leve's plan, kill credit, timer, success and rewards.
init returns the client class (by objective), 0x4e25, the leve id, the aetheryte marker size (6) and
the ex marker x, y, z. main must not wait(): director scripts run outside a coroutine.
--]]

function init(thisDirector)
	return thisDirector:GetClientClassPath(), 0x4e25, thisDirector.guildleveId, 6, 0, 0, 0
end

function main(thisDirector)
end
