require("Modifiers")

--[[

Hawk's Eye

Accuracy +18.75% of current Accuracy. Enhanced Hawk's Eye (tier 2) raises the gain by half,
to 28.125%.

--]]
function onGain(owner, effect, actionContainer)
	local accuracyMod = 0.1875

	if effect:GetTier() == 2 then
		accuracyMod = 0.28125
	end

	local amountGained = accuracyMod * owner:GetMod(Modifier.Accuracy)
	effect:SetMagnitude(amountGained)
	owner:AddMod(Modifier.Accuracy, effect:GetMagnitude())
end

function onLose(owner, effect, actionContainer)

	owner:SubtractMod(Modifier.Accuracy, effect:GetMagnitude())
end