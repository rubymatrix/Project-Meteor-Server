require("Global")
require("Magic")
require("Battle/Ko")

--[[
Targets corpses only. It does not revive on landing: the KO'd player gets a prompt
(ConfirmRaiseCommand) and is revived when they accept.
--]]

local params = {
	hpPercent = ko.RAISE_HP_PERCENT,
}

function onMagicPrepare(caster, target, spell)
	return 0
end

function onMagicStart(caster, target, spell)
	return 0
end

function onSkillFinish(caster, target, skill, action, actionContainer)
	-- 27363: Enhanced Raise: no Weakness or Brink of Death on revive.
	local weakness = true
	local ok, hasTrait = pcall(function() return caster:HasTrait(27363) end)
	if ok and hasTrait then
		weakness = false
	end

	if target:IsDead() then
		-- pcall: monsters/NPC corpses have no OfferRaise
		pcall(function() target:OfferRaise(caster, params.hpPercent, weakness) end)
	end

	-- No HP change on landing. The corpse entry is text 30354 ("uses Raise on <target>"),
	-- not the row's 30101.
	action.amount = 0
	action.worldMasterTextId = 30354
	actionContainer:AddAction(action)
end
