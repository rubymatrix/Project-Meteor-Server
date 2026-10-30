require("Global")

--[[
Functions: onTrigger
Desc:   Offers a raise to a KO'd player, as if Raise had landed.
Params: none (yourself) | <firstname> <lastname> [<hp%>] | clear (withdraw your own offer)
--]]

properties = {
	permissions = 0,
	parameters = "sss",
	description =
[[
Offers a raise to a KO'd player, as if Raise had landed.
!raise |                        (yourself)
!raise <firstname> <lastname> |
!raise <firstname> <lastname> <hp%> |
!raise clear |                  (withdraw your own offer)
]],
}

function onTrigger(player, argc, name, lastName, hp)
	local sender = "[raise] "
	local target = player
	if name == "clear" then
		player:ClearRaiseOffer()
		player:SendMessage(MESSAGE_TYPE_SYSTEM, sender, "Raise offer cleared.")
		return
	end
	if name ~= nil then
		target = GetWorldManager():GetPCInWorld(lastName ~= nil and (name .. " " .. lastName) or name)
		if target == nil then
			player:SendMessage(MESSAGE_TYPE_SYSTEM_ERROR, sender, "No player named " .. name .. (lastName and (" " .. lastName) or "") .. ".")
			return
		end
	end
	local hpPercent = tonumber(hp) or 25
	if target:IsDead() then
		target:PlayRaiseCastEffect(player)
	end
	if target:OfferRaise(player, hpPercent, true) then
		player:SendMessage(MESSAGE_TYPE_SYSTEM, sender, "Raise offered to " .. target.DisplayName .. " (" .. hpPercent .. "% HP).")
	else
		player:SendMessage(MESSAGE_TYPE_SYSTEM_ERROR, sender, target.DisplayName .. " is not KO'd.")
	end
end
