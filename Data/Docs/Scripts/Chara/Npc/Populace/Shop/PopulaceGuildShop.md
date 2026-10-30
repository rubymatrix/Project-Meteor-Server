# PopulaceGuildShop: guild mark exchange

Script: [`Data/scripts/Chara/Npc/Populace/Shop/PopulaceGuildShop.lua`](../../../../../../scripts/Chara/Npc/Populace/Shop/PopulaceGuildShop.lua)

Patch 1.20 stopped guild marks dropping. In 1.21 this class was set up to exchange them for
materia, crystals and gil, and to refund traits bought with marks. Traits used to be bought and
slotted; later versions unlock them by level.

Client functions:

- `cashbackTalkCommand(arg1 .. arg10)`: refund dialog for skills bought before the job update.
  Arguments are `xtx_command` values for the command names.
- `cashbackTalk(nil, refundAmount, arg3 .. arg10)`: refund dialog for treaties back to guild marks.
  Arguments 3 to 10 are `xtx_itemName` values.
- `selectMode(nil, npcId, isShowExchange, guildCurrency, unk)`: menus for exchanging leftover marks,
  undoing class points and learning about the guild. `unk` seems tied to point resetting.
- `maskShopListIndex(shopPack?, isSomething)`: probably hides an item in the shop list. Must be
  called after `openShopBuy` or the client errors.
- `guildExplain(npcId, player)`: guild mark tutorial. `selectMode` calls it on its own.
