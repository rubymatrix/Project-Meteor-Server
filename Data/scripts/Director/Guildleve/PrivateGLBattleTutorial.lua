require("Global")
require("Guildleve")

--[[
Battle leve tutorial director: a scripted run of three objective counts, then a win. init returns
the same values as PrivateGLBattleDetectNormal. Tutorial text ids and guildleve ids:
Data/Docs/Scripts/Director/Guildleve/PrivateGLBattleTutorial.md.
--]]

function init(thisDirector)
	return "/Director/Guildleve/PrivateGLBattleTutorial", 0x4e25, thisDirector.guildleveId, 6, 0, 0, 0
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

local function attentionMessage(player, textId, ...)
	player:SendGameMessage(GetWorldMaster(), textId, 0x20, args)
	player:SendDataPacket("attention", GetWorldMaster(), "", textId, args)
end
