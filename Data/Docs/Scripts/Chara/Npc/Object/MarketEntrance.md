# MarketEntrance: market ward menu

Script: [`Data/scripts/Chara/Npc/Object/MarketEntrance.lua`](../../../../../scripts/Chara/Npc/Object/MarketEntrance.lua)

## Client functions

Arguments mostly come from the xtx_placeName sheet.

```
eventPushChoiceAreaOrQuest(
    exitPlaceName[Fronds, etc],     - Retail only showed it when inside a Market Ward/Office  Set to 0 to hide the menu.
    showMarketWards/Houses          - If > 0, client script adds nation-specific Mercentile Houses as well.
    gcHQPlaceName,                  - Set to the placeName id for the Grand Company office of that city
    questAreaName,                  - Set to the placeName id of applicable quest instance, ex. Sailors Ward.
    showItemSearchCounter,          - If true, shows the Item Search menu
    itemSearchId                    - If > 0 & showItemSearchCounter = true, displays the item name with a "Stop Searching"
)
eventPushStepPrvMarket(
    staringWard,                    - Sets the starting placeName id
    wardCount,                      - Valid number 1-20. Sets the amount of market ward entries. Client continues sequentially from startingWard id.
    excludeWard                     - Hides the ward in the list that matches the id.  Use on the ward you're currently in.
)
```

## City trigger boxes

```
Limsa    - !warp 230 -416.5 40 446              ActorClass Id = 1090238
    bgObj  Id - [0xB3B] 2875
    Layout Id - [0x79 ] 121  (0x29d90001)
    Condition - in
    reactName - dwti    - Not a typo compared to the other cities
Gridania - !warp 206 -192.57 23.48 -1407.58     ActorClass Id = 1090264
    bgObj  Id - [0xCFA] 3322
    Layout Id - [0x141]  321 (0x29b00001)
    Condition - in
    reactName - dtwi
Ul'dah   - !warp 175 -235 189 50.5              ActorClass Id = 1500394
    bgObj  Id - [0x102F] 4143
    Layout Id - [0x1A5] 421  (0x615a0001)
    Condition - in
    reactName - dtwi
```
