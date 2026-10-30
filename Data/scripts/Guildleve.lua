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