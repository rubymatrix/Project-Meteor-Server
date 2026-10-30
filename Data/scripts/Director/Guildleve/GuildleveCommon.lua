require("Global")
require("Guildleve")

--[[
Battle leve start: start message and plate, marker, music and time limit, then test aim counts.
init returns the director script, director id, guildleve id, aetheryte location (6 or ~6) and the
ex marker x, y, z. Leve ids: 22 Limsa battle, 14 Gridania battle, 26 Ul'dah battle, 16 Coerthas
faction, 72 harvest.
--]]

function init(thisDirector)
	return "/Director/Guildleve/PrivateGLBattleSweepNormal", 0x4e25, thisDirector.guildleveId, 6, 0, 0, 0
end

function main(thisDirector)

	guildleveData = GetGuildleveGamedata(thisDirector.guildleveId)
	members = thisDirector:GetPlayerMembers()

	if members ~= nil and #members ~= 0 then
		player = members[0]
		player:SendGameMessage(GetWorldMaster(), 50036, 0x20, thisDirector.guildleveId, player, 0) --"You have started the leve..."
		player:PlayAnimation(getGlStartAnimationFromSheet(guildleveData.plateId, guildleveData.borderId, false))
	end

	wait(3)

	thisDirector:StartGuildleve()
	thisDirector:SyncAllInfo()
	thisDirector:UpdateMarkers(0, 59.0, 44.0, -163.0)

	if members ~= nil and #members ~= 0 then
		player = members[0]

		player:ChangeMusic(22)
		attentionMessage(player, 50022, thisDirector.guildleveId, thisDirector.selectedDifficulty, 0)
		player:SendGameMessage(GetWorldMaster(), 50026, 0x20, guildleveData.timeLimit)
	end

	wait(5)

	thisDirector:UpdateAimNumNow(0, 1)
	wait(3)
	thisDirector:UpdateAimNumNow(0, 2)
	wait(3)
	thisDirector:UpdateAimNumNow(0, 3)

end