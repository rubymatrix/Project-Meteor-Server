require("Global")
require("Magic")
require("Modifiers")

function onMagicPrepare(caster, target, spell)
	return 0
end

function onMagicStart(caster, target, spell)
	return 0
end

--http://forum.square-enix.com/ffxiv/threads/41900-White-Mage-A-Guide
function onSkillFinish(caster, target, skill, action, actionContainer)

	local hpPerPoint = 1.57

	--27364: Enhanced Stoneskin: Increases efficacy of Stoneskin
	if caster:IsPlayer() and caster:HasTrait(27364) then
		hpPerPoint = hpPerPoint * 1.25
	end

	skill.statusMagnitude = hpPerPoint * caster:GetMod(Modifier.EnhancementMagicPotency)

	--DoAction handles rates, buffs, dealing damage
	action:DoAction(caster, target, skill, actionContainer)
end