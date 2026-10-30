# PopulaceCaravanManager: client event functions

Script: [`Data/scripts/Chara/Npc/Populace/PopulaceCaravanManager.lua`](../../../../../scripts/Chara/Npc/Populace/PopulaceCaravanManager.lua)

- `caravanGuardEntry(areaGC, hasRoomForGCSeals, areaName, difficulty, playerGC, playerCountRequired, levelRequired)`: sign-up dialog.
  - The client adds `areaGC` (1-3) and `areaName` (0 or 3) to get the location name.
  - With difficulty 40 or more on areaGC 1-3 and areaName 0, the NPC says it will be a tougher trip.
- `caravanGuardQuestion(areaName1, areaName2, escortMax, isSameGC?, playerGC?)`: ask about the caravan escort.
- `caravanGuardJoinOK(areaName1, areaName2, playerGC)`: joined the caravan.
- `caravanGuardJoinNG(nil, maxEscorts, playerGC)`: how many escorts filled the run.
- `caravanGuardAmple(nil, playerGC, playerGC)`: the escort is full.
- `caravanGuardOther(npcGC)`: you're not part of the given Grand Company.
- `caravanGuardSigh()`: the NPC shrugs.
- `caravanGuardHuh()`: the NPC does /huh.
- `caravanGuardCancel(nil, playerGC)`: cancel the caravan escort.

Some lines address you differently at GC rank Chief Sergeant (id 27) or higher, but only outside English.
