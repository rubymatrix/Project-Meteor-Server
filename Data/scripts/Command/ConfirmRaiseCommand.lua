--[[
System command 24306, shown while a raise is on offer (Player:OfferRaise). Accepting revives the
player. The client's accept/decline values aren't confirmed: 0, 2 and false decline, anything
else accepts.
--]]

function onEventStarted(player, command, eventType, eventName, result)
	if not player:HasRaiseOffer() or result == 0 or result == 2 or result == false then
		player:ClearRaiseOffer()
	else
		player:AcceptRaise()
	end
	player:EndEvent()
end
