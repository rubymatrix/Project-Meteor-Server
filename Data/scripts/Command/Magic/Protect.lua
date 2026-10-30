require("Global")
require("Magic")
require("Modifiers")

function onMagicPrepare(caster, target, spell)
	return 0
end

function onMagicStart(caster, target, spell)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	--Actual amount of def/mdef will be calculated in OnGain
	skill.statusMagnitude = caster:GetMod(Modifier.EnhancementMagicPotency)

	--27365: Enhanced Protect: adds elemental resistances (Status/Protect.lua tier 2).
	--The status stays 223129 with or without the trait.
	skill.statusId = 223129
	if caster:IsPlayer() and caster:HasTrait(27365) then
		skill.statusTier = 2
	end

	--Protect and Shell overwrite each other; Shell comes from Ironwill Unguent.
	target.statusEffects:RemoveStatusEffect(223130, actionContainer)

	--DoAction handles rates, buffs, dealing damage
	action:DoAction(caster, target, skill, actionContainer)
end