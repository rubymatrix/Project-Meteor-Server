require("Modifiers")

function onGain(owner, effect, actionContainer)
	owner:AddMod(Modifier.Refresh, effect:GetMagnitude())
end

function onLose(owner, effect, actionContainer)
	owner:SubtractMod(Modifier.Refresh, effect:GetMagnitude())
end
