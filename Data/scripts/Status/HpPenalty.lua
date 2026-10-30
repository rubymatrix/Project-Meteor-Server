require("Modifiers")

function onGain(owner, effect, actionContainer)
	local newMaxHp = owner:GetMaxHP() * 0.75

	owner:SetMaxHP(newMaxHp)
end

function onLose(owner, effect, actionContainer)
	owner:SetMaxHP(owner:GetMaxHP() / 0.75)
end