--[[
Takes items back out of your bazaar.
--]]

function onEventStarted(player, actor, eventType, eventName, rewardItem, seekItem, bazaarType, narg, bazaarActor, rewardAmount, seekAmount, narg, narg, type9ItemIds)

	GetWorldManager():RemoveFromBazaar(player, player:GetItem(rewardItem))

	player:EndEvent()

end