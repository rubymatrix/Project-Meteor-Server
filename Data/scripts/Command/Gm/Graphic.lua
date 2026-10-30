require("Global")

--[[
Functions: onTrigger
Desc:   Changes the appearance of an equipment slot on the target, or on you with no target.
Params: <slot> <wId> [<eId> <vId> <cId>]: with two arguments only the weapon id changes
--]]

properties = {
	permissions = 0,
	parameters = "sssss",
	description =
[[
Changes appearance for equipment with given parameters.
!graphic <slot> <wID> <eID> <vID> <vID>
]],
}

function onTrigger(player, argc, slot, wId, eId, vId, cId)
	local messageId = MESSAGE_TYPE_SYSTEM_ERROR
	local sender = "[graphic] "

	slot = tonumber(slot) or 0
	wId = tonumber(wId) or 0
	eId = tonumber(eId) or 0
	vId = tonumber(vId) or 0
	cId = tonumber(cId) or 0

	local actor = GetWorldManager():GetActorInWorld(player.currentTarget) or player

	if player and argc > 0 then
		if argc > 2 then
			actor:GraphicChange(slot, wId, eId, vId, cId)
			player:SendMessage(messageId, sender,  string.format("Changing appearance on slot %u", slot))
		else
			actor:GraphicChange(slot, wId)
			player:SendMessage(messageId, sender,  string.format("Changing appearance on slot %u", slot))
		end
		actor:SendAppearance()
	else
		player:SendMessage(messageId, sender, "No parameters sent! Usage: "..properties.description)
	end
end