require("Modifiers")

function onGain(owner, effect, actionContainer)
	--Multiples Attack Magic Potency by 1.2 and Healing Magic Potency by 0.8
	owner:MultiplyMod(Modifier.AttackMagicPotency, 1.2)
	owner:MultiplyMod(Modifier.HealingMagicPotency, 0.8)
end

function onLose(owner, effect, actionContainer)
	owner:DivideMod(Modifier.AttackMagicPotency, 1.2)
	owner:DivideMod(Modifier.HealingMagicPotency, 0.8)
end