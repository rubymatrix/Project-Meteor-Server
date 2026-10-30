require("Global")
require("Guildleve")

--[[
Test battle leve: starts, places the marker, counts the aim to 3 and ends as cleared.
init returns the director script, director id, guildleve id, aetheryte location (6 or ~6) and the
ex marker x, y, z. Leve ids: 22 Limsa battle, 14 Gridania battle, 26 Ul'dah battle, 16 Coerthas
faction, 72 harvest.
--]]

function init(thisDirector)
	return "/Director/Guildleve/PrivateGLBattleSweepNormal", 0x4e25, thisDirector.guildleveId, 6, 0, 0, 0
end

function main(thisDirector)

	wait(3)

	thisDirector:StartGuildleve()
	thisDirector:SyncAllInfo()
	thisDirector:UpdateMarkers(0, 59.0, 44.0, -163.0)

	wait(5)

	thisDirector:UpdateAimNumNow(0, 1)
	wait(3)
	thisDirector:UpdateAimNumNow(0, 2)
	wait(3)
	thisDirector:UpdateAimNumNow(0, 3)

	wait(3)
	thisDirector:EndGuildleve(true)

end