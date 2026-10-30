require("Global")

--[[

PlaceDrivenCommand Script

Notes: 


--]]

function onEventStarted(player, actor, eventType, eventName, pushCommand, unk1, unk2, unk3, ownerActorId, unk4, unk5, unk6, unk7)

	actor = player:GetActorInInstance(ownerActorId)
	print("TESSSSSSSSSSSSSST")
	local harvestCommand = GetStaticActorById(0xA0F055F7)
	if actor ~= nil then
		if actor:GetActorClassId() == 1200052 then
			player:KickEventSpecial(harvestCommand, 0, "commandJudgeMode", 0, 0, 0, 0, 0x4E26, 0, nil, 0xF, actor, nil, nil, nil, nil)
		else
			player:KickEvent(actor, "pushCommand", false)
		end
	else
		player:EndEvent()
	end

end