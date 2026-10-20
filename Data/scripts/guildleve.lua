--[[

Guildleve constants and functions

--]]

--Helper functions

function glBorderIconIDToAnimID(iconId)
	return iconId - 20000;
end

function glPlateIconIDToAnimID(iconId)
	return iconId - 20020;
end

function getGLStartAnimationFromSheet(plate, border, isBoost)
	return getGLStartAnimation(glPlateIconIDToAnimID(plate), glBorderIconIDToAnimID(border), isBoost);
end

function getGLStartAnimation(plate, border, isBoost)
	borderBits = border;
	plateBits = bit.lshift(plate, 7);

	if (isBoost) then
		boostBits = 0x8000; --1 shifted 15 left
	else
		boostBits = 0x0;
	end
	
	return bit.bor(0x0B000000, boostBits, plateBits, borderBits);
end