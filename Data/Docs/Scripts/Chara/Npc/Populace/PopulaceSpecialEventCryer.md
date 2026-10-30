# PopulaceSpecialEventCryer: client event functions

Script: [`Data/scripts/Chara/Npc/Populace/PopulaceSpecialEventCryer.lua`](../../../../../scripts/Chara/Npc/Populace/PopulaceSpecialEventCryer.lua)

Six NPCs (three, with the actors duplicated) from the Foundation Day 2011 and 2012 events. In 2011 they
gave recruiting information for their Grand Company. In 2012 they exchanged over-aspected crystals and
clusters for GC seals, as part of the Atomos event.

2011:

- `eventTalkStep0(joined)`: dialog about joining their cause against the Imperials. `joined` is 0 or 1. The function has hard-coded actor ids, so it won't work with the 2012 actors.
- `eventTalkNotGCmenber(npcGC)`: dialog when you're not in their Grand Company.

2012:

- `eventTalkCrystalExchange(player, npcGC, hasCrystal)`: explains they want over-aspected crystals. Opens the exchange prompt if `hasCrystal` is 1.
- `eventTalkCsOverflow(player, npcGC)`: error that you can't hold the seals offered.
- `eventTalkCrystalExchange2(player, npcGC)`: accepts the crystals for seals.
