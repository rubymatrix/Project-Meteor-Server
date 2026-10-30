require("Modifiers")
require("BattleUtils")

--[[
Power Surge I (223212, from 27261 LNC34): attack up, defense down. Stage attack totals are
+115 / +230 / +346 and defense -158; Enhanced Power Surge (trait 27281) gives x1.1 attack. Lasts 60 s,
refreshed by each weaponskill or Jump. The tier counts refreshes from 1; past 10 it moves up a stage.
--]]

local ATTACK = 115
local DEFENSE = 158
local NEXT = 223213
local REFRESHES_PER_STAGE = 10

function onGain(owner, effect, actionContainer)
	local attackGained = ATTACK
	if owner:IsPlayer() and owner:HasTrait(27281) then
		attackGained = math.floor(attackGained * 1.1)
	end
	effect:SetMagnitude(attackGained)
	effect:SetExtra(DEFENSE)
	owner:AddMod(Modifier.Attack, effect:GetMagnitude())
	owner:SubtractMod(Modifier.Defense, effect:GetExtra())
end

function onCommandStart(effect, owner, command, actionContainer)
	--27266: Jump
	if command:GetCommandType() == CommandType.Weaponskill or command.id == 27266 then
		if NEXT ~= nil then
			effect:SetTier(effect:GetTier() + 1)
			if effect:GetTier() > REFRESHES_PER_STAGE then
				local action = owner.statusEffects:ReplaceEffect(effect, NEXT, 1, 1, 60)
				actionContainer:AddAction(action)
				return
			end
		end
		effect:RefreshTime()
	end
end

function onLose(owner, effect, actionContainer)
	owner:SubtractMod(Modifier.Attack, effect:GetMagnitude())
	owner:AddMod(Modifier.Defense, effect:GetExtra())
end
