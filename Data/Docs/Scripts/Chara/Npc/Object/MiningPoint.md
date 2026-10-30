# MiningPoint: mining node

Script: [`Data/scripts/Chara/Npc/Object/MiningPoint.lua`](../../../../../scripts/Chara/Npc/Object/MiningPoint.lua)

The node only ends the event for now. The HarvestJudge calls a mining event is expected to make,
all through `delegateEvent(player, GetStaticActor("HarvestJudge"), ...)`:

```
loadTextData(dummy)
targetCancel(dummy)
turnToTarget(dummy, 0)
openInputWidget(22002, 1)
textInputWidget(harvestJudge, 22002, npc, false)
askInputWidget(harvestJudge, 22002, 1)
```
