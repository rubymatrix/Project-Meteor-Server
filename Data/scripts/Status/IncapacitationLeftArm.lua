require("Battle/Parts")

--[[
Incapacitation, left_arm: a broken body part for 30 s. Status 223022 = 223019 + part 3. Sets and
clears the part's bit in the breakage byte of packet 0x0144. Rules are in Battle/Parts.lua.
--]]

function onGain(owner, effect, actionContainer)
	parts.onGain(owner, effect)
end

function onLose(owner, effect, actionContainer)
	parts.onLose(owner, effect)
end
