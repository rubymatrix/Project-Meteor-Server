require("Global")
require("Guildleve")

--[[
Scripted orb guildleve: starts, counts four aims on a timer and ends. init's return values and
director ids: Data/Docs/Scripts/Director/Guildleve/PrivateGLBattleOrbNormal.md.
--]]

function init(thisDirector)
	return "/Director/Guildleve/PrivateGLBattleOrbNormal", 0x4e25, thisDirector.guildleveId, 6, 0, 0, 0
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
	thisDirector:UpdateAimNumNow(0, 4)

	wait(2)

	thisDirector:EndGuildleve(true)

	wait(30)
	player:SendGameMessage(GetWorldMaster(), 50033, 0x20)
	thisDirector:EndDirector()

end
