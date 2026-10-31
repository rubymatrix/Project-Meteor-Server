--[[

Guildleve constants and functions

--]]

local getGlStartAnimation

--Helper functions

local function glBorderIconIdToAnimId(iconId)
	return iconId - 20000
end

local function glPlateIconIdToAnimId(iconId)
	return iconId - 20020
end

function getGlStartAnimationFromSheet(plate, border, isBoost)
	return getGlStartAnimation(glPlateIconIdToAnimId(plate), glBorderIconIdToAnimId(border), isBoost)
end

function getGlStartAnimation(plate, border, isBoost)
	local boostBits
	local borderBits = border
	local plateBits = bit.lshift(plate, 7)

	if isBoost then
		boostBits = 0x8000 --1 shifted 15 left
	else
		boostBits = 0x0
	end

	return bit.bor(0x0B000000, boostBits, plateBits, borderBits)
end

GUILDLEVE_CLASSTYPE_BATTLECRAFT = 1

-- Whether this aetheryte can start this leve now: the client's own check (unused leve whose sheet
-- aetheryte is this one) plus the server's limits. Returns true, or false and the reason to show.
function canStartGuildleveHere(player, aetheryte, glId)
	local data = GetGuildleveGamedata(glId)
	if data == nil or not player:HasGuildleve(glId) then
		return false, "You do not hold that guildleve."
	end
	if not player:IsGuildleveRetained(glId) then
		return false, "That guildleve cannot be initiated in its current state."
	end
	if data.aetheryte ~= aetheryte:GetActorClassId() then
		return false, "That guildleve must be initiated at another aetheryte."
	end
	if player:GetGuildleveDirector() ~= nil then
		return false, "You are already undertaking a levequest."
	end
	if data.classType ~= GUILDLEVE_CLASSTYPE_BATTLECRAFT then
		return false, "Fieldcraft levequests cannot be initiated yet."
	end
	return true, nil
end

-- eventGLSelectDetail(glId, mark, rewardItem, rewardQty, subItem, subQty, evaluation, ?, completed).
-- Leves give no guild marks (mark 0); evaluation 1-3 names the card's faction, 0 hides it.
function showGuildleveStartDetail(player, glId)
	return callClientFunction(player, "eventGLSelectDetail", glId, 0, 1000001, player:GetGuildleveRewardGil(glId), 0, 0, getGuildleveEvaluation(player, glId), true, player:HasCompletedGuildleve(glId))
end

function getGuildleveEvaluation(player, glId)
	return player:GetGuildleveEvaluation(glId) or 0
end
