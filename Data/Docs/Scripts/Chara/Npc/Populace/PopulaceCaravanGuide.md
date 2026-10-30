# PopulaceCaravanGuide: client event functions

Script: [`Data/scripts/Chara/Npc/Populace/PopulaceCaravanGuide.lua`](../../../../../scripts/Chara/Npc/Populace/PopulaceCaravanGuide.lua)

The caravan guide escorts the chocobos during Caravan Security events.

## Functions

- `caravanGuardCancel()`: menu prompt to abandon the caravan.
- `caravanGuardReward(cargo, nil, areaName, playerGC, killCount, areaName2)`: reward dialog for completing the caravan.
  - `cargo` 0 (none) to 9 (all) picks the success dialog.
  - If `playerGC` doesn't match the GC of the areaName region, the NPC says you don't need their seals.
  - `killCount` adds a line at 40-49 enemies slain and a different one at 50+.
- `caravanGuardNotReward()`: you didn't contribute to the event at all.
- `caravanGuardFailReward(areaName, areaName2)`: failure dialog; the NPC offers a free gysahl green, then a free teleport back to the aetheryte.
- `caravanGuardThanks(name1, name2, name3)`: dialog for joining the caravan. The NPC names the three chocobos (name ids from `xtx_displayName`).
- `caravanGuardOffer(areaName, areaName2, playerGC)`: tells you who to talk to to join the caravan.
- `caravanGuardAmple(areaName, areaName2)`: the NPC taking a break?
- `caravanGuardSuccess()`: reached the destination?
- `caravanGuardFailure(areaName, areaName2)`: failure dialog for the named area.
- `caravanGuardIgnore()`: resets the NPC state for the player, or is for players not flagged for the event.
- `caravanGuardBonusReward(nil, isBonus?)`: a variation on one line, picked by the boolean.
- `caravanGuardNotBonusReward()`: inventory full flavour dialog.

## Area names

The client adds `areaName` and `areaName2` to get the area: 1 Wineport, 2 Quarrymill, 3 Silver Bazaar,
4 Aleport, 5 Hyrstmill, 6 Golden Bazaar. `areaName` must be 1-3 for `caravanGuardReward`'s GC lines to
work. `areaName2` is 0 for the lower level caravan, 3 for the higher level one.

## populaceCaravanGuide sheet

| ID | Dialog | When |
|---|---|---|
| 6 | It is time. Come, let us ride. | Caravan begins. |
| 12 | We've arrived at last! Come and speak to me when you're ready to claim your reward. | Caravan completed. |
| 23 | We're under attack! The chocobos! Protect the chocobos! | Caravan aggros monsters. |
| 27 | Gods, have we already come this far? At this pace, we stand to make good time. | Between about 50% and 90% of the way; can repeat in one run. |
| 28 | Well fought, friend. I thank the gods you're with us. Come, onward! | Cleared the monsters the caravan aggroed. |

Not yet documented: the actors involved (six of them).

Sample calls:

```lua
callClientFunction(player, "caravanGuardReward", cargo, nil, areaName, playerGC, killCount, areaName2)
player:SendGameMessageLocalizedDisplayName(npc, 6, MESSAGE_TYPE_SAY, npc.displayNameId)
```
