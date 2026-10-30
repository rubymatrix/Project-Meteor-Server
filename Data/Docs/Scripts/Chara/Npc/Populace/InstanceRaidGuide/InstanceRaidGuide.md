# InstanceRaidGuide: raid entry

Script: [`Data/scripts/Chara/Npc/Populace/InstanceRaidGuide/InstanceRaidGuide.lua`](../../../../../../scripts/Chara/Npc/Populace/InstanceRaidGuide/InstanceRaidGuide.lua)

Client function: `askEnterInstanceRaid(raidId)` opens a widget asking to enter the given raid.

Raid entry the guards don't run yet. Hodder (Stewart, Gcl107) would open Rivenroad:

```lua
choice = callClientFunction(player, "delegateEvent", player, GetStaticActor("Gcl107"), "processEventStewart", 15)
if choice == 1 then
	callClientFunction(player, "askEnterInstanceRaid", 15)
end
```

Dauremant (Trisselle, Sum6w0) would open Rivenroad (Hard):

```lua
choice = callClientFunction(player, "delegateEvent", player, GetStaticActor("Sum6w0"), "processEventTrisselle", 16)
if choice == 1 then
	callClientFunction(player, "askEnterInstanceRaid", 16)
end
```

`defaultTalkWithStewart_002` may be the post-raid line; `defaultTalkWithTrisselle_002` has no known context.
