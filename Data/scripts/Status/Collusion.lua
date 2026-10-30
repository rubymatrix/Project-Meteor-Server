require("Modifiers")
require("BattleUtils")
require("Utils")

--[[

Collusion

The WAR puts it on a party member. That member's next attack (not an auto-attack) moves 50% of
its enmity to the WAR if they are within 8 yalms; if not, the status waits for the next attack.
It runs before BattleUtils.DamageTarget adds action.enmity to the hate list, so lowering
action.enmity here is what moves it. Needs status row 223097 with ActivateOnHit (flags 1048601).

--]]

local TRANSFER = 0.5
local MAX_DISTANCE = 8          -- yalms

function onHit(effect, attacker, defender, skill, action, actionContainer)
	if skill == nil or skill:GetCommandType() == CommandType.AutoAttack then return end

	local ok, hc = pcall(function() return defender.hateContainer end)
	if not ok or hc == nil then return end

	local war = effect:GetSource()
	if war == nil or war == attacker or not war:IsAlive() then return end
	local okD, dist = pcall(function() return getDistanceBetweenActors(attacker, war) end)
	if okD and dist ~= nil and dist > MAX_DISTANCE then return end

	local moved = math.floor(action.enmity * TRANSFER)
	if moved > 0 then
		action.enmity = action.enmity - moved
		hc:UpdateHate(war, moved)
	end
	--The status sits on the party member (the attacker), not the mob.
	attacker.statusEffects:RemoveStatusEffect(effect, actionContainer, 30331, false)
end
