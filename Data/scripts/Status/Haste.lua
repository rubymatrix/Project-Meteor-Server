require("Modifiers")

--[[
The magnitude multiplies the Delay modifier (auto-attack delay in ms), e.g. 0.8. A missing or
non-positive magnitude does nothing rather than zeroing delay.
--]]
function onGain(owner, effect, actionContainer)
	local m = effect:GetMagnitude()
	if m ~= nil and m > 0 then
		owner:MultiplyMod(Modifier.Delay, m)
	end
end

function onLose(owner, effect, actionContainer)
	local m = effect:GetMagnitude()
	if m ~= nil and m > 0 then
		owner:DivideMod(Modifier.Delay, m)
	end
end
