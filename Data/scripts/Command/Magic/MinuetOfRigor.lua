require("Global")
require("Magic")

--[[
Bard song: accuracy and magic accuracy to the party, doubled under Battle Voice. Casting it
replaces any other song this bard has on the target.
--]]

function onMagicPrepare(caster, target, skill)
	return 0
end

function onMagicStart(caster, target, skill)
	--+35 ACC/MACC at Lv50; 43 with AF, 71 with Battle Voice, 86 with both.
	local acc = caster:GetLevel() - 15

	--8071405: Choral Ringbands: Enhances Minuet of Rigor
	if  caster:HasItemEquippedInSlot(8071405, 13) then
		acc = acc + 8
	end

	--223253: Battle Voice
	--Battle Voice doubles effect of songs
	if caster.statusEffects:HasStatusEffect(223253) then
		acc = acc * 2
		--Set status tier so we can check it later when BV falls off
		skill.statusTier = 2
	end

	skill.statusMagnitude = acc
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	--223224: Swiftsong
	--223254: Ballad Of Magi
	--223255: Paeon of War
	--If target has one of these effects that was from this caster, remove it
	local oldSong
	local swiftSong = target.statusEffects:GetStatusEffectById(223224)
	local ballad = target.statusEffects:GetStatusEffectById(223254)
	local paeon = target.statusEffects:GetStatusEffectById(223255)
	if swiftSong and swiftSong:GetSource() == caster then
		oldSong = swiftSong
	elseif ballad and ballad:GetSource() == caster then
		oldSong = ballad
	elseif paeon and paeon:GetSource() == caster then
		oldSong = paeon
	end

	if oldSong then
		target.statusEffects:RemoveStatusEffect(oldSong)
	end

	--DoAction handles rates, buffs, dealing damage
	action:DoAction(caster, target, skill, actionContainer)
end