require("Modifiers")

function onGain(owner, effect, actionContainer)
	owner:SubtractMod(Modifier.MagicEvasion, effect:GetMagnitude())
end

function onLose(owner, effect, actionContainer)
	owner:AddMod(Modifier.MagicEvasion, effect:GetMagnitude())
end
