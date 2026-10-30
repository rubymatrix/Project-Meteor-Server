# PopulaceCompanyShop: Grand Company shop

Script: [`Data/scripts/Chara/Npc/Populace/PopulaceCompanyShop.lua`](../../../../../scripts/Chara/Npc/Populace/PopulaceCompanyShop.lua)

## Client functions

```
eventTalkStepCantUse()      -- When player tries to buy from another GC's shop
eventTalkPreJoin()          -- Dialog for the shop
eventTalkPreJoinQuest()     -- Tutorial dialog for the shop?
eventTalkJoined(???)        -- Dialog for the shop, they salute.  Orphaned parameter?

eventTalkFestival()         -- Festival Day Event Dialog
eventTalkFestival2()        -- Festival Day Event Follow-up Dialog

eventTalkMainMenu(???, ???) -- Shop menu for picking GC items
eventShopMenuOpen()         -- Sets up shop menu.  Calls getSpecialEventWork, value 8 shows GC firework & 11 a Patriot's Choker
eventShopMenuAsk()          -- Opens up the shop menu.
eventShopMenuClose()

eventGuideChocoboWhistle(???)   -- Tutorial dialog after purchasing Chocobo issuance slip.  Orphaned parameter?
eventGuideTownTransport(index)  -- Tutorial dialog after purchasing an aetherpass.  Index is item ID.
eventAskChocoboCustomize(index, price)  -- Chocobo Barding purchase dialog.  Index is item ID.
eventChocoboCustomize()                 -- Follow-up dialog if you purchase Chocobo Barding.

getGrandCompanyNumber()         -- Returns GC value of the NPC
getShopItemStartIndex(index)    -- Gets starting index value based on GC shop
getShopItemEndIndex(index)      -- Gets ending index value based on GC shop
getShopSellingItemMax(???)      --
getShopSellingItemDetail(player, ???, ???)

eventTalkStepBreak()            -- Returns NPC to their starting direction
```
