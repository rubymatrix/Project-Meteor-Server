require("Battle/Parts")

--[[
Incapacitation, special_right (status 223025 = 223019 + part 6): a body part is damaged beyond
use, 30 s. Sets and clears the part's bit in the 0x0144 breakage byte. Rules: Battle/Parts.lua.
--]]

function onGain(owner, effect, actionContainer)
	parts.onGain(owner, effect)
end

function onLose(owner, effect, actionContainer)
	parts.onLose(owner, effect)
end
