# BazaarDealCommand: bazaar deals

Script: [`Data/scripts/Command/BazaarDealCommand.lua`](../../../scripts/Command/BazaarDealCommand.lua)

Every bazaar deal has a reward (what the player who fills the request gets) and a seek (what the
owner wants back: gil or an item).

Event arguments:

- `rewardItem`: the item the buyer gets. For gil, the item id instead. When an item is offered for
  a sought item, reward and seek are combined here.
- `seekItem`: the item the buyer gives. For gil, the item id instead.
- `bazaarMode`: the tag value set in the bazaar item's data.
- `arg1`: always nil.
- `bazaarActor`: the bazaar's owner.
- `rewardAmount`: how many of `rewardItem` the buyer gets.
- `seekAmount`: how many of `seekItem` the owner wants.
