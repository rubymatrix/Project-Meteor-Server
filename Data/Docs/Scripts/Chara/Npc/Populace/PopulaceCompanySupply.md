# PopulaceCompanySupply: Grand Company supply and provisioning

Script: [`Data/scripts/Chara/Npc/Populace/PopulaceCompanySupply.lua`](../../../../../scripts/Chara/Npc/Populace/PopulaceCompanySupply.lua)

This class handles the menus for players delivering specific items in exchange for Grand Company
seals. The supply/provisioning schedule runs on a weekly rotation, which resets Monday at 12AM JST,
with eight rotations in all. Each requested item has a server-wide cap; once it is filled, the next
item in that week's list opens.

NPCs of this class use the Noc001 script for dialog and menus.

## Client functions

```
eventTalkPreJoin()                              - Dialog when you're not affiliated
eventTalkExclusive()                            - Dialog when you're in a GC but not the actor's?
eventTalkJoined()                               - Salutes, then softlocks the client (its dialog strings were removed). Obsolete.

eventQuestItemMenuOpen(itemId, itemPrice, itemPriceHq, supplyType) - supplyType: 1 = Supply, 2 = Provisioning, 3 = Totorak, 4 = Dzemael, 5 = Primal, 6 = NM drops
eventQuestItemMenuSelect(quantity, quality, unk) - Shop-style menu for item detail and confirming delivery. The args seem to do nothing on the client.
eventQuestItemMenuClose()                       - Closes the menu

eventQuestSupplyItemActor(unk1)                 - The client calls this itself to set up the Expeditionary window
eventQuestSupplyItemID(unk1, unk2)              - Called by eventQuestSupplyItemActor() to set item ranges by category

getEventQuestSupplyMode()                       - Returns the supply mode set by eventQuestItemMenuOpen()
eventTalkStepBreak()                            - Resets the actor's engage state
```

`eventQuestItemMenuSelect` returns `choice, quantity, quality, itemSlot, Type7Param`. `itemSlot` always
comes back 0; the slot is in `Type7Param.slot`.

## Noc001 functions

```
pENPCAskSupplyWelcome(npcGC)  - Welcome dialog
pENPCAskSupply(npcGC)         - The delivery selection menu
eventQuestAskExWelcome(npcGC) - Dialog when you pick Expeditionary
eventQuestAskExArea(npcGC)    - The Expeditionary selection menu
pENPCAskNowTalk(npcGC)        - Dialog for Delivery Status from pENPCAskSupply()

nowSup(itemId1, current1, max1, itemId2, current2, max2, itemId3, current3, max3) - The current 3 items and amount delivered vs. max
nowSupAddItem(itemId, current, max)                                               - Lists the bonus item
pItem(itemId1, unk1, itemId2, unk2, itemId3, unk3, itemId4, unk4)                 - Lists the items wanted. The fourth is the bonus; 0 hides it.

showSupplyLimit(minutes, seconds, current, required)   - Time left to finish the delivery, current/required amount
eventShowPrizeMessage(npcGC)                           - Reward dialog for a hand-in?

pELimitErr()                                           - The GC no longer accepts the item
pETradeErr()                                           - Transaction error (inventory?)
pETradeErrLimit(minutes, seconds, current, required)   - Transaction error with time left and current/required amount
pESuppylMaxErrKeyWait(isShowLimit, minutes, seconds, current, required) - Delivery quota already filled; optional timer/amount
pESuppylSealMaxErr()                                   - Capped on GC seals; transaction incomplete

eventQuestCantEx(npcGC)                                - You must be Private Second Class for Expeditionary missions
```
