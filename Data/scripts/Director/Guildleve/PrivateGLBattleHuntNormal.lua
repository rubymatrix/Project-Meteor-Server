require("Global")
require("Guildleve")

-- init returns: director id, guildleve id, aetheryte location (6 or ~6), ex marker x, y, z.
-- Leve director ids: 22 Limsa battle, 14 Gridania battle, 26 Ul'dah battle, 16 Coerthas faction,
-- 72 harvest.

function init(thisDirector)
	return "/Director/Guildleve/PrivateGLBattleHuntNormal", 0x4e25, thisDirector.guildleveId, 6, 0, 0, 0
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

end
