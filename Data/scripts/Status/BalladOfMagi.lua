require("Modifiers")

function onGain(owner, effect, actionContainer)
	--Only one song per bard can be active, need to figure out a good way to do this
	owner:AddMod(Modifier.Refresh, effect:GetMagnitude())
end

function onLose(owner, effect, actionContainer)
	owner:SubtractMod(Modifier.Refresh, effect:GetMagnitude())
end