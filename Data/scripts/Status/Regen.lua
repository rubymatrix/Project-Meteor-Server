require("Modifiers")

--Regen is modified by Enhancing Magic Potency. Formula here: http://forum.square-enix.com/ffxiv/threads/41900-White-Mage-A-Guide
function onGain(owner, effect, actionContainer)
	owner:AddMod(Modifier.Regen, effect:GetMagnitude())
end

function onLose(owner, effect, actionContainer)
	owner:SubtractMod(Modifier.Regen, effect:GetMagnitude())
end
